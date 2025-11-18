import cv2
import numpy as np
import time
from collections import deque
import onnxruntime as ort
from picamera2 import Picamera2
import os
import pickle
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
import pygame
import threading # 🚨 스레딩 모듈 추가
from flask import Flask, Response # 🚨 Flask 모듈 추가

# ==================== 설정 (Configuration) ====================
ONNX_MODEL_PATH = "final_detection416.onnx"
INPUT_WIDTH = 416
INPUT_HEIGHT = 416
CONF_THRESHOLD = 0.4
NMS_THRESHOLD = 0.4
labels = ["Person", "Cigarette", "Smoke", "Fire"]

GUIDE_FILE = "person.mp3"
WARNING_FILE = "smoke.mp3"
GUIDE_CYCLE = 15
WARNING_CYCLE = 31

detection_window = 10
required_duration = 3
upload_interval = 30
BUFFER_SIZE = 150
FLASK_PORT = 5000 # Flutter 앱이 접속할 포트

# --- Google Drive API 설정 ---
SCOPES = ['https://www.googleapis.com/auth/drive.file']

# ==================== 전역 변수 및 Flask/Thread 설정 ====================
# 추론 결과를 담고, 스트리밍에 사용될 프레임 (바운딩 박스 포함)
annotated_frame = None 
# 스레드 간의 안전한 프레임 접근을 위한 락
frame_lock = threading.Lock() 

# 감지 및 쿨타임 변수
person_timestamps = deque()
smoking_timestamps = deque()
last_guide_play_time = 0
last_warning_play_time = 0
last_upload_time = 0
frame_buffer = deque(maxlen=BUFFER_SIZE)

# Flask 앱 초기화
app = Flask(__name__) 

# ==================== Google Drive API 함수 (변경 없음) ====================
def get_drive_service():
    # ... (기존 get_drive_service 함수 내용 유지) ...
    creds = None
    if os.path.exists('token.pickle'):
        with open('token.pickle', 'rb') as token:
            creds = pickle.load(token)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
            creds = flow.run_local_server(port=0)
        with open('token.pickle', 'wb') as token:
            pickle.dump(creds, token)
    return build('drive', 'v3', credentials=creds)

def get_or_create_folder(folder_name, service):
    # ... (기존 get_or_create_folder 함수 내용 유지) ...
    query = f"name='{folder_name}' and mimeType='application/vnd.google-apps.folder' and trashed=false"
    response = service.files().list(q=query, spaces='drive', fields='files(id, name)').execute()
    files = response.get('files', [])
    
    if files:
        folder_id = files[0].get('id')
        print(f"✅ Folder '{folder_name}' already exists. ID: {folder_id}")
        return folder_id
    else:
        file_metadata = {'name': folder_name, 'mimeType': 'application/vnd.google-apps.folder'}
        folder = service.files().create(body=file_metadata, fields='id').execute()
        folder_id = folder.get('id')
        print(f"✅ Folder '{folder_name}' created. ID: {folder_id}")
        return folder_id

def upload_to_drive(file_path, file_name, service, folder_id):
    # ... (기존 upload_to_drive 함수 내용 유지) ...
    try:
        mimetype = 'video/mp4' if file_path.endswith('.mp4') else 'image/jpeg'
        media = MediaFileUpload(file_path, mimetype=mimetype)
        file_metadata = {'name': file_name, 'parents': [folder_id]}
        file = service.files().create(body=file_metadata, media_body=media, fields='id').execute()
        print(f"[DRIVE] ✅ File '{file_name}' uploaded successfully.")
        os.remove(file_path) # 업로드 후 로컬 파일 삭제
    except Exception as e:
        print(f"[DRIVE] ❌ Failed to upload {file_name}. Error: {e}")

# ==================== 비동기 Google Drive 업로드 함수 (새로 추가) ====================
def upload_event_async(frame, buffer, service, photo_folder_id, video_folder_id, current_fps):
    """파일 저장 및 Google Drive 업로드를 비동기로 처리하여 메인 루프를 블로킹하지 않음."""
    if service is None:
        print("[DRIVE] Warning: Drive service not initialized. Skipping upload.")
        return

    try:
        print(f"[{time.strftime('%H:%M:%S')}] Starting ASYNC upload...")
        timestamp_str = time.strftime("%Y%m%d_%H%M%S")
        photo_name = f"smoking_snapshot_{timestamp_str}.jpg"
        video_name = f"smoking_video_{timestamp_str}.mp4"

        # 1. 스냅샷 저장
        cv2.imwrite(photo_name, frame)
        
        # 2. 비디오 저장 (버퍼링된 프레임)
        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
        record_fps = current_fps if current_fps > 0 else 10.0 # 메인 루프의 현재 FPS 사용
        writer = cv2.VideoWriter(video_name, fourcc, record_fps, (INPUT_WIDTH, INPUT_HEIGHT))
        
        # deque의 복사본을 리스트로 변환하여 안전하게 사용
        for buffered_frame in list(buffer): 
            writer.write(buffered_frame)
        writer.release()
        
        # 3. Google Drive 업로드
        upload_to_drive(photo_name, photo_name, service, photo_folder_id)
        upload_to_drive(video_name, video_name, service, video_folder_id)
        
    except Exception as e:
        print(f"[DRIVE] ❌ Async upload failed: {e}")


# ==================== Flask 스트리밍 함수 (새로 추가) ====================
def generate():
    """MJPEG 스트림을 생성하는 제너레이터 함수."""
    global annotated_frame, frame_lock
    while True:
        with frame_lock:
            if annotated_frame is None:
                continue
            
            # JPEG으로 인코딩 (바운딩 박스가 그려진 프레임 사용)
            encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), 80] 
            (flag, encodedImage) = cv2.imencode(".jpg", annotated_frame, encode_param)

            if not flag:
                continue

        # MJPEG 경계와 데이터 전송
        yield(b'--frame\r\n' b'Content-Type: image/jpeg\r\n\r\n' + 
              bytearray(encodedImage) + b'\r\n')
        
        # CPU 부하 관리를 위한 짧은 딜레이
        time.sleep(0.03) # 약 30 FPS 제한

# --- Flask 라우트 설정 ---
@app.route("/video_feed")
def video_feed():
    """Flutter 앱이 접근할 스트림 엔드포인트."""
    return Response(generate(),
        mimetype = "multipart/x-mixed-replace; boundary=frame")


# ==================== 메인 루프 함수 (추론 및 로직 담당) ====================
def main_detection_loop(session, input_name, output_name, drive_service, photo_folder_id, video_folder_id):
    """카메라 캡처, ONNX 추론, 감지 로직, 디스플레이 및 비동기 업로드를 담당"""
    global annotated_frame, frame_lock
    global prev_time, frame_count, fps, last_guide_play_time, last_warning_play_time, last_upload_time

    print("\n[INFO] Detection Loop Started...")
    
    # OpenCV 윈도우 생성 (로컬 디버깅용)
    cv2.namedWindow("YOLOv8 ONNX Detection", cv2.WINDOW_NORMAL)
    cv2.resizeWindow("YOLOv8 ONNX Detection", 640, 480)

    try:
        while True:
            current_time = time.time()
            
            # 1. 카메라 캡처
            frame_bgr = picam2.capture_array()
            
            # 2. 버퍼 저장 (캡처 속도 유지)
            frame_buffer.append(frame_bgr.copy()) 

            # 3. 추론 전처리
            frame_rgb_for_model = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
            input_tensor = np.transpose(frame_rgb_for_model, (2, 0, 1))
            input_tensor = np.expand_dims(input_tensor, axis=0).astype(np.float32) / 255.0
            
            # 4. ONNX 추론
            outputs = session.run([output_name], {input_name: input_tensor})[0]
            
            # 5. 후처리 (NMS)
            predictions = np.squeeze(outputs).T
            boxes, confidences, class_ids = [], [], []
            class_counts = {label: 0 for label in labels}

            for pred in predictions:
                class_probs = pred[4:]
                class_id = np.argmax(class_probs)
                confidence = class_probs[class_id]
                
                if confidence > CONF_THRESHOLD:
                    cx, cy, w, h = pred[0], pred[1], pred[2], pred[3]
                    # 원본 크기(640x480)에 맞게 좌표 조정
                    x1 = int(cx * 640 / INPUT_WIDTH - w * 640 / INPUT_WIDTH / 2)
                    y1 = int(cy * 480 / INPUT_HEIGHT - h * 480 / INPUT_HEIGHT / 2)
                    w_scaled = int(w * 640 / INPUT_WIDTH)
                    h_scaled = int(h * 480 / INPUT_HEIGHT)
                    
                    boxes.append([x1, y1, w_scaled, h_scaled])
                    confidences.append(float(confidence))
                    class_ids.append(class_id)
                    
            indices = cv2.dnn.NMSBoxes(boxes, confidences, CONF_THRESHOLD, NMS_THRESHOLD)
            
            # 6. 결과 그리기 및 감지 상태 업데이트
            temp_frame = frame_bgr.copy() # 바운딩 박스를 그릴 임시 프레임
            
            if len(indices) > 0:
                for i in indices.flatten():
                    if class_ids[i] < len(labels):
                        class_name = labels[class_ids[i]]
                        class_counts[class_name] += 1
                        
                        box = boxes[i]; x1, y1, w, h = box[0], box[1], box[2], box[3]; conf = confidences[i]
                        
                        # 색상 지정
                        color = (0, 255, 0) 
                        if class_name == "Cigarette": color = (0, 0, 255)
                        elif class_name == "Smoke": color = (255, 165, 0)
                        elif class_name == "Fire": color = (0, 255, 255)
                        
                        label = f"{class_name} ({conf:.2f})"
                        cv2.rectangle(temp_frame, (x1, y1), (x1 + w, y1 + h), color, 2)
                        cv2.putText(temp_frame, label, (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

            # 7. 경고 로직 (Cigarette 또는 Smoke 포함)
            person_detected = class_counts["Person"] > 0
            # 🚨 Cigarette 또는 Smoke 중 하나만 감지되어도 흡연으로 판단
            smoking_material_detected = class_counts["Cigarette"] > 0 or class_counts["Smoke"] > 0 
            
            if person_detected: person_timestamps.append(current_time)
            if person_detected and smoking_material_detected: smoking_timestamps.append(current_time)
                
            # 타임스탬프 윈도우 관리
            while person_timestamps and current_time - person_timestamps[0] > detection_window: person_timestamps.popleft()
            while smoking_timestamps and current_time - smoking_timestamps[0] > detection_window: smoking_timestamps.popleft()
                
            person_duration = len(person_timestamps) / fps if fps > 0 else 0
            smoking_duration = len(smoking_timestamps) / fps if fps > 0 else 0
            
            show_smoking_warning = smoking_duration >= required_duration
            show_person_guide = person_duration >= required_duration and not show_smoking_warning

            # 8. 음성 안내 및 비동기 업로드
            y_offset = 20 # 텍스트 표시 시작 위치

            if not pygame.mixer.get_busy():
                
                # 1순위: 경고 (흡연)
                if show_smoking_warning and (current_time - last_warning_play_time > WARNING_CYCLE):
                    if warning_sound:
                        print(f"[{time.strftime('%H:%M:%S')}] 🔊 Playing WARNING sound (smoke.mp3)!")
                        warning_sound.play()
                        last_warning_play_time = current_time
                        last_guide_play_time = current_time # 경고 시 안내 쿨타임 리셋
                    
                    # 🚨 비동기 업로드 (메인 루프를 블로킹하지 않음)
                    if drive_service and (current_time - last_upload_time > upload_interval):
                        last_upload_time = current_time
                        upload_thread = threading.Thread(
                            target=upload_event_async,
                            args=(
                                temp_frame.copy(), # 박스 그려진 현재 프레임 복사본
                                frame_buffer.copy(), # 버퍼 복사본
                                drive_service, 
                                photo_folder_id, 
                                video_folder_id, 
                                fps
                            ),
                            daemon=True
                        )
                        upload_thread.start()
                    
                # 2순위: 안내 (사람)
                elif show_person_guide and (current_time - last_guide_play_time > GUIDE_CYCLE):
                    if guide_sound:
                        print(f"[{time.strftime('%H:%M:%S')}] 🔊 Playing GUIDE sound (person.mp3)!")
                        guide_sound.play()
                        last_guide_play_time = current_time

            
            # 9. 텍스트 표시 (로컬/스트림 모두)
            if show_smoking_warning:
                cv2.putText(temp_frame, "WARNING: Smoking Detected! (ASYNC UPLOAD)", (10, y_offset + 40), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 0, 255), 3)
            elif show_person_guide:
                cv2.putText(temp_frame, "No-Smoking Area", (10, y_offset + 10), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 0, 0), 2)
            
            cv2.putText(temp_frame, f"FPS: {fps:.2f}", (10, y_offset + 70), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)
            
            # 10. 스트리밍 프레임 업데이트 및 로컬 표시
            with frame_lock:
                annotated_frame = temp_frame.copy() # 스트리밍을 위해 바운딩 박스가 그려진 프레임 업데이트
            
            cv2.imshow("YOLOv8 ONNX Detection", temp_frame)
            
            # 11. FPS 계산
            frame_count += 1
            elapsed_time_for_fps = current_time - prev_time
            if elapsed_time_for_fps >= 1.0:
                fps = frame_count / elapsed_time_for_fps
                frame_count = 0
                prev_time = current_time
            
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break

    except KeyboardInterrupt:
        print("🛑 Program terminated")
    except Exception as e:
        print(f"\n[CRITICAL ERROR] Main loop error: {e}")
    finally:
        cv2.destroyAllWindows()
        picam2.stop()
        pygame.mixer.quit()
        print("✅ Cleanup complete. Program exit.")

# ==================== 메인 실행 블록 ====================
if __name__ == '__main__':
    # --- 초기화 ---
    # ONNX 모델 로드 (생략, 상단에 이미 로드됨)
    # Pygame 초기화 (생략, 상단에 이미 초기화됨)
    # Google Drive 서비스 초기화
    try:
        drive_service = get_drive_service()
        photo_folder_id = get_or_create_folder("Photos", drive_service)
        video_folder_id = get_or_create_folder("Videos", drive_service)
    except Exception as e:
        print(f"❌ Failed to initialize Google Drive service. Continuing without backup: {e}")
        drive_service = None
        photo_folder_id = None
        video_folder_id = None

    try:
        # 1. Flask 서버 스레드 실행
        print(f"🚀 Starting Flask server on 0.0.0.0:{FLASK_PORT}...")
        server_thread = threading.Thread(
            target=lambda: app.run(host='0.0.0.0', port=FLASK_PORT, debug=False, threaded=True, use_reloader=False)
        )
        server_thread.daemon = True
        server_thread.start()
        
        time.sleep(1) # 서버가 완전히 시작될 시간을 줌
        
        # 2. 메인 감지 및 추론 루프 시작
        main_detection_loop(session, input_name, output_name, drive_service, photo_folder_id, video_folder_id)

    except Exception as e:
        print(f"[FATAL ERROR] Server or Initialization failed: {e}")