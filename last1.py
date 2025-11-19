import cv2
import numpy as np
import onnxruntime as ort
from picamera2 import Picamera2 # Raspberry Pi 카메라 모듈
import time
import pygame
from collections import deque
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, firestore, storage, messaging
import os
import threading 
from flask import Flask, Response 

# ==================== Google Drive 관련 Import ====================
import pickle
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
# =================================================================

# ==================== 설정 ====================
# ONNX 모델 설정
ONNX_MODEL_PATH = "final_detection416.onnx"
INPUT_WIDTH = 416
INPUT_HEIGHT = 416
CONF_THRESHOLD = 0.4
NMS_THRESHOLD = 0.4

# 클래스 레이블
labels = ["Person", "Cigarette", "Smoke", "Fire"]

# 음성 파일 경로
GUIDE_FILE = "person.mp3"     # Person만 감지 (U+00A0 오류 수정 완료)
WARNING_FILE = "smoke.mp3"    # Person + Cigarette/Smoke

# 음성 재생 주기 설정
GUIDE_CYCLE = 15      # 안내 전체 주기 (초)
WARNING_CYCLE = 31    # 경고 전체 주기 (초)

# 감지 설정
DETECTION_WINDOW = 10     # 감지 판단 윈도우 (초)
REQUIRED_DURATION = 3     # 필요한 지속 시간 (초)
DETECTION_FPS_ASSUMED = 10.0 # 비디오 저장을 위한 가정된 FPS

# Firebase 설정
FIREBASE_CREDENTIAL_PATH = "firebase-service-account.json"
FLASK_PORT = 5000 # Flutter 앱이 접속할 포트

# Google Drive 설정
SCOPES = ['https://www.googleapis.com/auth/drive.file']
DRIVE_UPLOAD_INTERVAL = 30 # Google Drive 업로드 간격 (초)
BUFFER_DURATION = 15 # 비디오 버퍼 시간 (초)
BUFFER_SIZE = int(BUFFER_DURATION * DETECTION_FPS_ASSUMED) 


# ==================== 전역 변수 ====================
person_detections = deque(maxlen=DETECTION_WINDOW)
cigarette_detections = deque(maxlen=DETECTION_WINDOW)
smoke_detections = deque(maxlen=DETECTION_WINDOW)
fire_detections = deque(maxlen=DETECTION_WINDOW)

last_guide_time = 0
last_warning_time = 0
last_drive_upload_time = 0 

# --- 스트리밍 관련 전역 변수 ---
output_frame = None 
lock = threading.Lock()
app = Flask(__name__) 

# --- Drive/Firebase 관련 전역 변수 ---
db = None
bucket = None
drive_service = None 
photo_folder_id = None 
video_folder_id = None 
frame_buffer = deque(maxlen=BUFFER_SIZE) # 비디오 녹화를 위한 버퍼
fps = DETECTION_FPS_ASSUMED 
prev_time = time.time()
frame_count = 0


# ==================== Google Drive 유틸리티 함수 ====================
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
            # credentials.json 파일이 필요합니다
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
        print(f"✅ Drive Folder '{folder_name}' already exists. ID: {folder_id}")
        return folder_id
    else:
        file_metadata = {'name': folder_name, 'mimeType': 'application/vnd.google-apps.folder'}
        folder = service.files().create(body=file_metadata, fields='id').execute()
        folder_id = folder.get('id')
        print(f"✅ Drive Folder '{folder_name}' created. ID: {folder_id}")
        return folder_id

def upload_to_drive(file_path, file_name, service, folder_id):
    """지정한 폴더 ID 안에 파일을 업로드합니다."""
    try:
        mimetype = 'video/mp4' if file_path.endswith('.mp4') else 'image/jpeg'
        media = MediaFileUpload(file_path, mimetype=mimetype)
        file_metadata = {'name': file_name, 'parents': [folder_id]}
        service.files().create(body=file_metadata, media_body=media, fields='id').execute()
        print(f"✅ Drive File '{file_name}' uploaded successfully.")
        os.remove(file_path) # 업로드 후 로컬 파일 삭제
    except Exception as e:
        print(f"❌ Failed to upload {file_name} to Drive. Error: {e}")

def upload_to_google_drive_async(frame_bgr, frame_buffer_copy, record_fps):
    """Google Drive 업로드 및 로컬 파일 처리 로직 (스레드에서 실행)"""
    global drive_service, photo_folder_id, video_folder_id
    
    if drive_service is None or photo_folder_id is None or video_folder_id is None:
        print("[WARNING] Google Drive 서비스가 준비되지 않아 업로드를 건너뜁니다.")
        return

    try:
        print(f"[{time.strftime('%H:%M:%S')}] Google Drive 업로드 작업 시작...")
        timestamp_str = datetime.now().strftime("%Y%m%d_%H%M%S")
        photo_name = f"drive_snapshot_{timestamp_str}.jpg"
        video_name = f"drive_video_{timestamp_str}.mp4"

        # 1. 사진 저장
        cv2.imwrite(photo_name, frame_bgr)
        
        # 2. 비디오 저장 (버퍼 사용)
        h, w, _ = frame_bgr.shape
        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
        writer = cv2.VideoWriter(video_name, fourcc, record_fps, (w, h))
        for buffered_frame in frame_buffer_copy:
            writer.write(buffered_frame)
        writer.release()
        
        # 3. Drive 업로드
        upload_to_drive(photo_name, photo_name, drive_service, photo_folder_id)
        upload_to_drive(video_name, video_name, drive_service, video_folder_id)
    
    except Exception as e:
        print(f"[ERROR] Google Drive 비동기 업로드 중 오류 발생: {e}")
# =================================================================


# ==================== Pygame 초기화 ====================
print(f"[INFO] Pygame 초기화 중...")
try:
    # 사운드 재생을 위한 초기화
    pygame.mixer.init(frequency=22050, buffer=4096)
    guide_sound = pygame.mixer.Sound(GUIDE_FILE) if os.path.exists(GUIDE_FILE) else None
    warning_sound = pygame.mixer.Sound(WARNING_FILE) if os.path.exists(WARNING_FILE) else None
    print("[INFO] Pygame 믹서 준비 완료")
except Exception as e:
    print(f"[ERROR] Pygame 초기화 실패: {e}")


# ==================== Firebase 초기화 ====================
print(f"[INFO] Firebase 초기화 중...")
try:
    # firebase-service-account.json 파일이 필요합니다
    cred = credentials.Certificate(FIREBASE_CREDENTIAL_PATH)
    firebase_admin.initialize_app(cred, {
        'storageBucket': 'smoke-detection-system-d85b6.appspot.com' # 실제 버킷 주소로 변경
    })
    db = firestore.client()
    bucket = storage.bucket()
    print("[INFO] Firebase 연결 완료")
except Exception as e:
    print(f"[ERROR] Firebase 초기화 실패: {e}")
    print("[WARNING] Firebase 없이 계속 진행합니다")
    
# ==================== Google Drive 초기화 ====================
print(f"[INFO] Google Drive 서비스 초기화 중...")
try:
    drive_service = get_drive_service()
    photo_folder_id = get_or_create_folder("Smoking_Snapshots", drive_service)
    video_folder_id = get_or_create_folder("Smoking_Videos", drive_service)
    print("[INFO] Google Drive 연결 완료")
except Exception as e:
    print(f"[ERROR] Google Drive 초기화 실패: {e}")
    drive_service = None
    print("[WARNING] Google Drive 없이 계속 진행합니다")
# =================================================================


# ==================== ONNX 모델 로드 ====================
print(f"[INFO] ONNX 모델 로드 중: {ONNX_MODEL_PATH}")
try:
    # ONNX 런타임 세션 생성
    session = ort.InferenceSession(ONNX_MODEL_PATH, providers=['CPUExecutionProvider'])
    print("[INFO] ONNX 모델 로드 완료")
    INPUT_NAME = session.get_inputs()[0].name
except Exception as e:
    print(f"[ERROR] ONNX 모델 로드 실패: {e}")
    exit()

# ==================== 카메라 초기화 ====================
print("[INFO] Picamera2 초기화 중...")
picam2 = Picamera2()
config = picam2.create_preview_configuration(
    # 메인 스트림을 640x480 RGB로 설정
    main={"size": (640, 480), "format": "RGB888"}
)
picam2.configure(config)
picam2.start()
time.sleep(2)
print("[INFO] 카메라 준비 완료")


# ==================== 카메라 캡처 전용 루프 (스트리밍 원본 제공) ====================
def camera_capture_loop():
    """스트리밍 및 추론을 위한 원본 프레임을 캡처하고 전역 변수를 업데이트"""
    global output_frame, picam2, lock
    print("[INFO] 스트리밍 캡처 루프 시작...")

    try:
        while True:
            # 1. 프레임 캡처 
            frame = picam2.capture_array() 
            
            # 2. 스트리밍 전용 전역 변수 업데이트 (lock으로 보호)
            with lock:
                output_frame = frame.copy() 
            
            # CPU 부하 관리를 위한 짧은 딜레이
            time.sleep(0.01) 
            
    except Exception as e:
        print(f"[ERROR] 캡처 루프에서 오류 발생: {e}")

# ==================== MJPEG 스트리밍 함수 ====================
def generate():
    """MJPEG 스트림을 생성하는 제너레이터 함수."""
    global output_frame, lock
    while True:
        with lock:
            if output_frame is None:
                continue
            
            encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), 85] 
            (flag, encodedImage) = cv2.imencode(".jpg", output_frame, encode_param)

            if not flag:
                continue

        yield(b'--frame\r\n' b'Content-Type: image/jpeg\r\n\r\n' + 
              bytearray(encodedImage) + b'\r\n')

# --- Flask 라우트 설정 ---
@app.route("/video_feed")
def video_feed():
    """Flutter 앱이 접근할 스트림 엔드포인트."""
    return Response(generate(),
        mimetype = "multipart/x-mixed-replace; boundary=frame")


# ==================== 전처리 함수 ====================
def preprocess(frame):
    """YOLOv8 ONNX 입력 형식으로 전처리"""
    # BGR -> RGB (Picamera2는 이미 RGB를 출력하지만, OpenCV 함수를 위해 변환 과정 추가)
    # frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB) 
    img = cv2.resize(frame, (INPUT_WIDTH, INPUT_HEIGHT))
    img = img.astype(np.float32) / 255.0
    img = np.transpose(img, (2, 0, 1))  # HWC -> CHW (ONNX 입력 형식)
    img = np.expand_dims(img, axis=0)   # CHW -> NCHW
    return img

# ==================== 후처리 함수 ====================
def postprocess(outputs, conf_threshold=0.4, nms_threshold=0.4):
    """YOLOv8 출력 후처리"""
    # 출력 형태: (1, 84, 8400) -> (8400, 84)
    output = outputs[0][0]
    output = output.T 

    boxes = []
    scores = []
    class_ids = []

    for detection in output:
        # 박스 좌표와 클래스 점수 추출
        x, y, w, h = detection[0:4]
        class_scores = detection[4:]
        class_id = np.argmax(class_scores)
        confidence = class_scores[class_id]

        if confidence >= conf_threshold:
            # 좌표를 원본 해상도(640x480)로 스케일링
            x_center = x * 640 / INPUT_WIDTH
            y_center = y * 480 / INPUT_HEIGHT
            box_w = w * 640 / INPUT_WIDTH
            box_h = h * 480 / INPUT_HEIGHT
            
            x1 = int(x_center - box_w/2)
            y1 = int(y_center - box_h/2)
            
            boxes.append([x1, y1, int(box_w), int(box_h)])
            scores.append(float(confidence))
            class_ids.append(class_id)

    # NMS (Non-Maximum Suppression) 적용
    if len(boxes) > 0:
        indices = cv2.dnn.NMSBoxes(boxes, scores, conf_threshold, nms_threshold)
        if len(indices) > 0:
            indices = indices.flatten()
            return [boxes[i] for i in indices], [scores[i] for i in indices], [class_ids[i] for i in indices]

    return [], [], []

# ==================== 음성 재생 함수 ====================
def play_audio_safe(audio_file):
    """안전한 음성 재생 (중복 방지)"""
    if not pygame.mixer.get_busy():
        try:
            if audio_file == WARNING_FILE and warning_sound:
                warning_sound.play()
                print(f"[AUDIO] {WARNING_FILE} 재생 시작")
            elif audio_file == GUIDE_FILE and guide_sound:
                guide_sound.play()
                print(f"[AUDIO] {GUIDE_FILE} 재생 시작")
        except Exception as e:
            print(f"[ERROR] 음성 재생 실패: {e}")

# ==================== 감지 확인 함수 ====================
def check_detection_duration(detections, required_duration=REQUIRED_DURATION):
    """감지 지속 시간 확인"""
    if len(detections) == 0:
        return False
    current_time = time.time()
    
    # 오래된 감지 기록 제거 (DETECTION_WINDOW 초 이내만 유지)
    while detections and current_time - detections[0] > DETECTION_WINDOW:
        detections.popleft()

    # 감지 윈도우 내에서 최초 감지 시점부터 required_duration 초 이상 지속되었는지 확인
    if len(detections) > 0 and current_time - detections[0] >= required_duration:
        return True
    return False

# ==================== Google Drive 이미지 업로드 함수 ====================
def upload_image_to_storage(frame, event_id):
    """OpenCV 프레임을 JPEG로 인코딩하여 Google Drive에 업로드하고 공개 URL 반환"""
    global drive_service, photo_folder_id

    if drive_service is None or photo_folder_id is None:
        print("[WARNING] Google Drive 서비스가 준비되지 않아 이미지 업로드를 건너뜁니다.")
        return None

    try:
        # 1. 이미지를 임시 파일로 저장
        timestamp_str = datetime.now().strftime("%Y%m%d_%H%M%S")
        temp_filename = f"detection_{timestamp_str}_{event_id}.jpg"

        # RGB to BGR 변환 (OpenCV imwrite는 BGR 사용)
        is_success, buffer = cv2.imencode(".jpg", frame)
        if not is_success:
            print("[ERROR] 이미지 인코딩 실패")
            return None

        # 임시 파일로 저장
        with open(temp_filename, 'wb') as f:
            f.write(buffer.tobytes())

        # 2. Google Drive에 업로드
        mimetype = 'image/jpeg'
        media = MediaFileUpload(temp_filename, mimetype=mimetype)
        file_metadata = {
            'name': temp_filename,
            'parents': [photo_folder_id]
        }

        file = drive_service.files().create(
            body=file_metadata,
            media_body=media,
            fields='id'
        ).execute()

        file_id = file.get('id')

        # 3. 파일을 공개로 설정
        drive_service.permissions().create(
            fileId=file_id,
            body={'type': 'anyone', 'role': 'reader'}
        ).execute()

        # 4. 공개 URL 생성 (직접 이미지 보기 URL)
        image_url = f"https://drive.google.com/uc?export=view&id={file_id}"

        print(f"[GOOGLE DRIVE] 이미지 업로드 완료: {image_url}")

        # 5. 임시 파일 삭제
        os.remove(temp_filename)

        return image_url

    except Exception as e:
        print(f"[ERROR] Google Drive 이미지 업로드 실패: {e}")
        # 임시 파일이 남아있다면 삭제
        if os.path.exists(temp_filename):
            os.remove(temp_filename)
        return None

# ==================== 푸시 알림 전송 함수 ====================
def send_push_notification(event_type, details, event_id, image_url=None):
    """FCM을 통해 푸시 알림 전송"""
    try:
        if event_type == 'smoking':
            title = '🚨 흡연 감지 알림'
            body = f"N1동(본부관) 1층 입구에서 흡연 행위가 감지되었습니다"
        else:
            title = 'ℹ️ 사람 감지'
            body = "N1동(본부관) 1층 입구에 사람이 감지되었습니다"

        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data={
                'eventId': event_id,
                'type': event_type,
                'location': 'N1동(본부관) 1층 입구', # 위치 정보
                'timestamp': datetime.now().isoformat(),
                'image_url': image_url or '',
            },
            topic='smoking_detection' # 알림을 받을 토픽
        )

        response = messaging.send(message)
        print(f"[FCM] 푸시 알림 전송 완료: {response}")
        return response
    except Exception as e:
        print(f"[ERROR] 푸시 알림 전송 실패: {e}")
        return None

# ==================== Firebase 저장 함수 (비동기 처리) ====================
def save_to_firebase(event_type, details, frame=None, confidence=0.85):
    """Firebase에 감지 이벤트 저장 (Flutter 앱 호환)"""
    if db is None:
        return

    try:
        from datetime import datetime
        import uuid

        # Flutter 앱과 호환되는 이벤트 ID 생성
        event_id = str(uuid.uuid4())

        # Firebase Storage에 이미지 업로드
        image_url = None
        if frame is not None:
            image_url = upload_image_to_storage(frame, event_id)

        # Flutter DetectionEvent 모델과 호환되는 데이터 구조
        event_data = {
            'id': event_id,  # ✅ Flutter 필수 필드
            'timestamp': datetime.now().isoformat(),  # ✅ ISO 8601 형식
            'label': 'cigarette' if event_type == 'smoking' else 'person',  # ✅ Flutter 필수 필드
            'confidence': float(confidence),  # ✅ Flutter 필수 필드
            'imageUrl': image_url if image_url else '',  # ✅ camelCase로 변경
            'thumbnailUrl': image_url if image_url else '',  # ✅ Flutter 필수 필드
            'location': 'N1동(본부관) 1층 입구',  # ✅ Flutter 선택 필드
            'metadata': {  # ✅ Flutter 필수 필드
                'source': 'raspberry_pi',
                'model': 'yolov8_onnx',
                'cameraId': 'camera_1',
                'details': details
            }
        }

        # Firestore에 문서 ID를 event_id로 지정하여 저장
        db.collection('detection_events').document(event_id).set(event_data)
        print(f"[FIREBASE] ✅ 이벤트 저장 완료 (Flutter 호환): {event_type} (ID: {event_id})")

        # 흡연 감지 시에만 푸시 알림 전송
        if event_type == 'smoking':
            send_push_notification(event_type, details, event_id, image_url)

    except Exception as e:
        print(f"[ERROR] Firebase 저장 실패: {e}")

# ==================== 메인 감지 루프 (추론 담당) ====================
def main_detection_loop():
    global last_warning_time, last_guide_time, last_drive_upload_time
    global output_frame, frame_buffer, fps, prev_time, frame_count
    
    print("[INFO] 감지 시작...")
    print("=" * 50)

    # OpenCV 윈도우 생성 (로컬 디버깅용)
    cv2.namedWindow('Smoke Detection', cv2.WINDOW_NORMAL)
    cv2.resizeWindow('Smoke Detection', 640, 480)

    try:
        while True:
            raw_frame = None
            # 캡처 스레드로부터 최신 프레임을 복사해옴
            with lock:
                if output_frame is None:
                    time.sleep(0.1) 
                    continue
                raw_frame = output_frame.copy() 
                
            current_time = time.time()
            display_frame = raw_frame.copy() # 바운딩 박스를 그릴 프레임

            # 1. FPS 및 버퍼 업데이트 (Google Drive 비디오 녹화용)
            frame_buffer.append(raw_frame.copy()) 
            
            frame_count += 1
            elapsed_time = current_time - prev_time
            if elapsed_time >= 1.0:
                fps = frame_count / elapsed_time
                frame_count = 0
                prev_time = current_time

            # 2. 전처리 & 추론
            input_data = preprocess(raw_frame)
            outputs = session.run(None, {INPUT_NAME: input_data})

            # 3. 후처리 및 바운딩 박스 그리기
            person_detected = False
            cigarette_detected = False
            smoke_detected = False
            fire_detected = False
            
            boxes, scores, class_ids = postprocess(outputs, CONF_THRESHOLD, NMS_THRESHOLD)
            
            for box, score, class_id in zip(boxes, scores, class_ids):
                label = labels[class_id]
                x1, y1, w, h = box
                x2, y2 = x1 + w, y1 + h

                # 감지된 객체에 따라 색상 설정 및 상태 업데이트
                if label == "Person":
                    color = (0, 255, 0) # Green
                    person_detected = True
                    person_detections.append(current_time)
                elif label == "Cigarette":
                    color = (0, 0, 255) # Red
                    cigarette_detected = True
                    cigarette_detections.append(current_time)
                elif label == "Smoke":
                    color = (0, 165, 255) # Orange
                    smoke_detected = True
                    smoke_detections.append(current_time)
                elif label == "Fire":
                    color = (0, 0, 255) # Red
                    fire_detected = True
                    fire_detections.append(current_time)
                else:
                    color = (255, 255, 255) # White

                cv2.rectangle(display_frame, (x1, y1), (x2, y2), color, 2)
                label_text = f"{label}: {score:.2f}"
                cv2.putText(display_frame, label_text, (x1, y1 - 10),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

            # 4. 감지 상태 확인 및 경고/안내 로직
            person_sustained = check_detection_duration(person_detections)
            cigarette_sustained = check_detection_duration(cigarette_detections)
            smoke_sustained = check_detection_duration(smoke_detections)

            # 흡연 감지 (사람 + 담배 또는 연기)
            if person_sustained and (cigarette_sustained or smoke_sustained):

                # 4-1. 음성 경고 (주기 체크)
                if current_time - last_warning_time >= WARNING_CYCLE:
                    print("=" * 50)
                    print("⚠️  [경고] 흡연 감지! 이벤트 저장 및 알림 전송.")
                    print("=" * 50)
                    play_audio_safe(WARNING_FILE)
                    last_warning_time = current_time

                    # 4-2. 🚨 Firebase 저장 및 알림 (비동기 스레드) 🚨
                    # 최대 신뢰도 계산 (담배 또는 연기 중 가장 높은 값)
                    max_confidence = 0.0
                    if len(scores) > 0:
                        max_confidence = max(scores)

                    detection_details = {'message': '흡연 행위가 감지되었습니다'}
                    save_thread = threading.Thread(
                        target=save_to_firebase,
                        args=('smoking', detection_details, display_frame.copy(), max_confidence),
                        daemon=True
                    )
                    save_thread.start()

                    # 4-3. 🚨 Google Drive 업로드 (비동기 스레드 & 쿨타임 체크) 🚨
                    if drive_service and (current_time - last_drive_upload_time >= DRIVE_UPLOAD_INTERVAL):
                        print("🌐 Google Drive 업로드 쿨타임 충족. 업로드 스레드 시작.")
                        last_drive_upload_time = current_time
                        
                        drive_upload_thread = threading.Thread(
                            target=upload_to_google_drive_async,
                            args=(display_frame.copy(), list(frame_buffer), fps if fps > 0 else DETECTION_FPS_ASSUMED),
                            daemon=True
                        )
                        drive_upload_thread.start()
            
            # 사람만 감지된 경우 (흡연 아님)
            elif person_sustained and not cigarette_sustained and not smoke_sustained:
                if current_time - last_guide_time >= GUIDE_CYCLE:
                    print("ℹ️  [안내] 사람 감지 (흡연 아님)")
                    play_audio_safe(GUIDE_FILE)
                    last_guide_time = current_time

            # 5. 화면 표시
            cv2.putText(display_frame, f"Inf FPS: {fps:.2f}", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)
            cv2.imshow('Smoke Detection', display_frame)

            # 6. 'q' 키를 누르면 종료
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break

    except KeyboardInterrupt:
        print("\n[INFO] 프로그램 종료 중...")
    except Exception as e:
        print(f"\n[CRITICAL ERROR] 메인 루프에서 오류 발생: {e}")
    finally:
        cv2.destroyAllWindows()
        try:
            picam2.stop()
        except Exception:
            pass 
        pygame.mixer.quit()
        print("[INFO] 정리 완료. 프로그램 종료.")


# ==================== 메인 실행 블록 ====================
if __name__ == '__main__':
    try:
        # 1. Flask 서버 스레드 실행
        print(f"🚀 Starting Flask server on 0.0.0.0:{FLASK_PORT}...")
        # Flask 서버는 별도의 스레드에서 백그라운드로 실행되어야 메인 루프가 작동 가능
        server_thread = threading.Thread(target=lambda: app.run(host='0.0.0.0', port=FLASK_PORT, debug=False, threaded=True, use_reloader=False))
        server_thread.daemon = True # 메인 스레드 종료 시 함께 종료
        server_thread.start()
        
        # 2. 카메라 캡처 스레드 실행
        capture_thread = threading.Thread(target=camera_capture_loop, daemon=True)
        capture_thread.start()

        time.sleep(3) # 캡처 스레드가 프레임을 채울 시간을 줌
        
        # 3. 메인 감지 루프 시작
        main_detection_loop()

    except Exception as e:
        print(f"[FATAL ERROR] 서버 시작 실패 또는 프로그램 초기화 실패: {e}")