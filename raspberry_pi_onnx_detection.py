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

# --- 설정 (Configuration) ---
ONNX_MODEL_PATH = "final_detection416.onnx"
INPUT_WIDTH = 416
INPUT_HEIGHT = 416
CONF_THRESHOLD = 0.4
NMS_THRESHOLD = 0.4
labels = ["Person", "Cigarette", "Smoke", "Fire"]

# (★ 2개의 사운드 파일 및 "총 주기" 설정)
GUIDE_FILE = "person.mp3"     # 안내용 (사람만)
WARNING_FILE = "smoke.mp3"   # 경고용 (사람+담배)
GUIDE_CYCLE = 15             # (★) 안내 총 주기 (재생 10초 + 휴식 5초)
WARNING_CYCLE = 31           # (★) 경고 총 주기 (재생 16초 + 휴식 15초)

# --- Google Drive API 설정 ---
SCOPES = ['https://www.googleapis.com/auth/drive.file']

def get_drive_service():
    """Google Drive API 서비스 객체를 인증하고 반환합니다."""
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
    """지정한 이름의 폴더를 찾고, 없으면 생성한 뒤 폴더 ID를 반환합니다."""
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
    """지정한 폴더 ID 안에 파일을 업로드합니다."""
    try:
        mimetype = 'video/mp4' if file_path.endswith('.mp4') else 'image/jpeg'
        media = MediaFileUpload(file_path, mimetype=mimetype)
        file_metadata = {'name': file_name, 'parents': [folder_id]}
        file = service.files().create(body=file_metadata, media_body=media, fields='id').execute()
        print(f"✅ File '{file_name}' uploaded successfully into folder.")
        os.remove(file_path) # 업로드 후 로컬 파일 삭제
    except Exception as e:
        print(f"❌ Failed to upload {file_name}. Error: {e}")

# --- ONNX 모델 초기화 ---
try:
    session = ort.InferenceSession(ONNX_MODEL_PATH, providers=['CPUExecutionProvider'])
    print(f"✅ ONNX Model loaded successfully: {ONNX_MODEL_PATH}")
    model_inputs = session.get_inputs()
    input_name = model_inputs[0].name
    model_outputs = session.get_outputs()
    output_name = model_outputs[0].name
except Exception as e:
    print(f"❌ ONNX Model loading failed: {e}")
    exit()

# --- Picamera2 초기화 ---
picam2 = Picamera2()
picam2.configure(picam2.create_preview_configuration(
    main={"format": "RGB888", "size": (INPUT_WIDTH, INPUT_HEIGHT)}
))
picam2.start()
time.sleep(1)
print("✅ Camera ready")


# --- (★) Pygame Mixer 초기화 (노이즈 방지 설정 포함) ---
try:
    pygame.mixer.init(frequency=44100, buffer=4096)
    guide_sound = None
    warning_sound = None

    if os.path.exists(GUIDE_FILE):
        guide_sound = pygame.mixer.Sound(GUIDE_FILE)
        print(f"✅ Guide sound loaded: {GUIDE_FILE}")
    else:
        print(f"❌ Warning: Guide sound not found at {GUIDE_FILE}")
        
    if os.path.exists(WARNING_FILE):
        warning_sound = pygame.mixer.Sound(WARNING_FILE)
        print(f"✅ Warning sound loaded: {WARNING_FILE}")
    else:
        print(f"❌ Warning: Warning sound not found at {WARNING_FILE}")
        
except Exception as e:
    print(f"❌ Failed to initialize pygame mixer: {e}")
    guide_sound = None
    warning_sound = None


cv2.namedWindow("YOLOv8 ONNX Detection", cv2.WINDOW_NORMAL)

# --- 변수 초기화 ---
prev_time = time.time(); frame_count = 0; fps = 0
detection_window = 10; required_duration = 3
person_timestamps = deque(); smoking_timestamps = deque()
last_upload_time = 0; upload_interval = 30 
BUFFER_SIZE = 150
frame_buffer = deque(maxlen=BUFFER_SIZE)

# (★ "스마트 쿨타임"을 위한 2개의 시간 변수)
last_guide_play_time = 0
last_warning_play_time = 0


# --- 구글 드라이브 서비스 및 폴더 초기화 ---
try:
    drive_service = get_drive_service()
    print("✅ Google Drive service initialized.")
    photo_folder_id = get_or_create_folder("Photos", drive_service)
    video_folder_id = get_or_create_folder("Videos", drive_service)
except Exception as e:
    print(f"❌ Failed to initialize Google Drive: {e}")
    drive_service = None 


try:
    while True:
        current_time = time.time()
        
        # 1. 카메라 캡처
        frame_bgr = picam2.capture_array()
        
        # 2. 버퍼 저장
        frame_buffer.append(frame_bgr.copy()) 

        # 3. RGB 변환
        frame_rgb_for_model = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
        
        # 4. 텐서 생성
        input_tensor = np.transpose(frame_rgb_for_model, (2, 0, 1)) # HWC -> CHW
        input_tensor = np.expand_dims(input_tensor, axis=0).astype(np.float32) / 255.0
        
        # 5. ONNX 추론
        outputs = session.run([output_name], {input_name: input_tensor})[0]
        
        # 6. 후처리 (NMS)
        predictions = np.squeeze(outputs).T
        boxes, confidences, class_ids = [], [], []
        class_counts = {label: 0 for label in labels}

        for pred in predictions:
            class_probs = pred[4:]
            class_id = np.argmax(class_probs)
            confidence = class_probs[class_id]
            
            if confidence > CONF_THRESHOLD:
                cx, cy, w, h = pred[0], pred[1], pred[2], pred[3]
                x1 = int(cx - w / 2); y1 = int(cy - h / 2)
                boxes.append([x1, y1, int(w), int(h)])
                confidences.append(float(confidence))
                class_ids.append(class_id)
                
        indices = cv2.dnn.NMSBoxes(boxes, confidences, CONF_THRESHOLD, NMS_THRESHOLD)

        # 7. 결과 그리기
        if len(indices) > 0:
            for i in indices.flatten():
                if class_ids[i] < len(labels):
                    class_name = labels[class_ids[i]]
                    class_counts[class_name] += 1
                    
                    box = boxes[i]; x1, y1, w, h = box[0], box[1], box[2], box[3]; conf = confidences[i]
                    color = (0, 255, 0) # Person
                    
                    if class_name == "Cigarette": color = (0, 0, 255)
                    elif class_name == "Smoke": color = (255, 165, 0)
                    elif class_name == "Fire": color = (0, 255, 255)
                    
                    label = f"{class_name} ({conf:.2f})"
                    cv2.rectangle(frame_bgr, (x1, y1), (x1 + w, y1 + h), color, 2)
                    cv2.putText(frame_bgr, label, (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)
        
        # 8. FPS 계산
        frame_count += 1; elapsed_time = current_time - prev_time
        if elapsed_time >= 1.0:
            fps = frame_count / elapsed_time; frame_count = 0; prev_time = current_time
        
        # 9. 경고 로직
        person_detected = class_counts["Person"] > 0
        cigarette_detected = class_counts["Cigarette"] > 0
        
        if person_detected: person_timestamps.append(current_time)
        if person_detected and cigarette_detected: smoking_timestamps.append(current_time)
            
        while person_timestamps and current_time - person_timestamps[0] > detection_window: person_timestamps.popleft()
        while smoking_timestamps and current_time - smoking_timestamps[0] > detection_window: smoking_timestamps.popleft()
            
        person_duration = len(person_timestamps) / fps if fps > 0 else 0
        smoking_duration = len(smoking_timestamps) / fps if fps > 0 else 0
        
        show_smoking_warning = smoking_duration >= required_duration
        show_person_guide = person_duration >= required_duration and not show_smoking_warning

        # 10. 정보 표시
        y_offset = 20
        for name, count in class_counts.items():
            if count > 0:
                cv2.putText(frame_bgr, f"{name}: {count}", (10, y_offset), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 2)
                y_offset += 25
        
        
        # --- (★) 11. 최종 "스마트 쿨타임" 음성 안내 로직 (수정됨) ---
        
        # 1단계: 무대 확인 (끊김 방지)
        if not pygame.mixer.get_busy():
            
            # 2단계: 쿨타임 및 우선순위 확인 (스피커가 조용할 때만)
            
            # 1순위: 경고 (흡연)
            # 경고 "총 주기"(31초)가 지났는지 확인
            if show_smoking_warning and (current_time - last_warning_play_time > WARNING_CYCLE):
                if warning_sound:
                    print(f"[{time.strftime('%H:%M:%S')}] 🔊 Playing WARNING sound (smoke.mp3)!")
                    warning_sound.play()
                    last_warning_play_time = current_time
                    last_guide_play_time = current_time # (★) 경고 시 안내 쿨타임도 함께 리셋
            
            # 2순위: 안내 (사람)
            # (경고가 아니고) 안내 "총 주기"(15초)가 지났는지 확인
            elif show_person_guide and (current_time - last_guide_play_time > GUIDE_CYCLE):
                if guide_sound:
                    print(f"[{time.strftime('%H:%M:%S')}] 🔊 Playing GUIDE sound (person.mp3)!")
                    guide_sound.play()
                    last_guide_play_time = current_time

        
        # --- 12. 텍스트 표시 및 업로드 로직 (음성 재생과 별개로 항상 실행) ---
        
        if show_smoking_warning:
            # 1. (사람 + 담배): 경고 텍스트
            cv2.putText(frame_bgr, "WARNING: Smoking Detected!", (10, y_offset + 40), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 0, 255), 3)
            
            # 11. 업로드 로직 (경고 텍스트가 표시될 때 실행)
            if drive_service and (current_time - last_upload_time > upload_interval):
                last_upload_time = current_time
                print(f"[{time.strftime('%H:%M:%S')}] Smoking event triggered! Preparing to upload...")
                timestamp_str = time.strftime("%Y%m%d_%H%M%S")
                photo_name = f"smoking_snapshot_{timestamp_str}.jpg"
                video_name = f"smoking_video_{timestamp_str}.mp4"

                cv2.imwrite(photo_name, frame_bgr)
                
                fourcc = cv2.VideoWriter_fourcc(*'mp4v')
                record_fps = fps if fps > 0 else 10.0
                writer = cv2.VideoWriter(video_name, fourcc, record_fps, (INPUT_WIDTH, INPUT_HEIGHT))
                for buffered_frame in list(frame_buffer):
                    writer.write(buffered_frame)
                writer.release()
                
                upload_to_drive(photo_name, photo_name, drive_service, photo_folder_id)
                upload_to_drive(video_name, video_name, drive_service, video_folder_id)
        
        elif show_person_guide:
            # 2. (사람만): 안내 텍스트
            cv2.putText(frame_bgr, "No-Smoking Area", (10, y_offset + 10), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 0, 0), 2)
        
        
        cv2.putText(frame_bgr, f"FPS: {fps:.2f}", (10, y_offset + 70), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)
        
        # 13. 최종 화면 표시
        cv2.imshow("YOLOv8 ONNX Detection", frame_bgr)
        
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

except KeyboardInterrupt:
    print("🛑 Program terminated")
finally:
    cv2.destroyAllWindows()
    picam2.stop()
    pygame.mixer.quit()
    print("✅ Camera, windows, and sound mixer closed")