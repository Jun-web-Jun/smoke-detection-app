"""
흡연 감지 시스템 - 앱 연동 최종 버전 (스트리밍/추론 분리 최적화)
(Firebase, ONNX, Picamera2, Pygame, Flask 스트리밍 포함)
"""
import cv2
import numpy as np
import onnxruntime as ort
from picamera2 import Picamera2
import time
import pygame
from collections import deque
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, firestore, storage, messaging
import os
import threading 
from flask import Flask, Response 

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
GUIDE_FILE = "person.mp3"     # Person만 감지
WARNING_FILE = "smoke.mp3"    # Person + Cigarette/Smoke

# 음성 재생 주기 설정
GUIDE_CYCLE = 15      # 안내 전체 주기 (초)
WARNING_CYCLE = 31    # 경고 전체 주기 (초)

# 감지 설정
DETECTION_WINDOW = 10     # 감지 판단 윈도우 (초)
REQUIRED_DURATION = 3     # 필요한 지속 시간 (초)

# Firebase 설정
FIREBASE_CREDENTIAL_PATH = "firebase-service-account.json"
FLASK_PORT = 5000 # Flutter 앱이 접속할 포트

# ==================== 전역 변수 ====================
person_detections = deque(maxlen=DETECTION_WINDOW)
cigarette_detections = deque(maxlen=DETECTION_WINDOW)
smoke_detections = deque(maxlen=DETECTION_WINDOW)
fire_detections = deque(maxlen=DETECTION_WINDOW)

last_guide_time = 0
last_warning_time = 0

# --- 스트리밍 관련 전역 변수 ---
output_frame = None 
lock = threading.Lock()
app = Flask(__name__) 


# ==================== Pygame 초기화 ====================
print(f"[INFO] Pygame 초기화 중...")
try:
    pygame.mixer.init(frequency=22050, buffer=4096)
    guide_sound = pygame.mixer.Sound(GUIDE_FILE) if os.path.exists(GUIDE_FILE) else None
    warning_sound = pygame.mixer.Sound(WARNING_FILE) if os.path.exists(WARNING_FILE) else None
    print("[INFO] Pygame 믹서 준비 완료")
except Exception as e:
    print(f"[ERROR] Pygame 초기화 실패: {e}")


# ==================== Firebase 초기화 ====================
print(f"[INFO] Firebase 초기화 중...")
db = None
bucket = None
try:
    cred = credentials.Certificate(FIREBASE_CREDENTIAL_PATH)
    firebase_admin.initialize_app(cred, {
        'storageBucket': 'smoke-detection-system-d85b6.appspot.com'
    })
    db = firestore.client()
    bucket = storage.bucket()
    print("[INFO] Firebase 연결 완료")
except Exception as e:
    print(f"[ERROR] Firebase 초기화 실패: {e}")
    print("[WARNING] Firebase 없이 계속 진행합니다")

# ==================== ONNX 모델 로드 ====================
print(f"[INFO] ONNX 모델 로드 중: {ONNX_MODEL_PATH}")
try:
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
    main={"size": (640, 480), "format": "RGB888"}
)
picam2.configure(config)
picam2.start()
time.sleep(2)
print("[INFO] 카메라 준비 완료")


# ==================== 카메라 캡처 전용 루프 (새로 추가) ====================
def camera_capture_loop():
    """스트리밍용 원본 프레임을 최대한 빠르게 캡처하고 전역 변수를 업데이트"""
    global output_frame, picam2, lock
    print("[INFO] 스트리밍 캡처 루프 시작...")

    try:
        while True:
            # 1. 프레임 캡처 (가장 빠른 속도로)
            frame = picam2.capture_array() 
            
            # 2. 스트리밍 전용 전역 변수 업데이트
            with lock:
                # output_frame에 박스가 없는 깨끗한 원본 영상을 복사
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
            
            # JPEG으로 인코딩 (깨끗한 output_frame 사용)
            encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), 85] # 인코딩 품질 85 (선택적)
            (flag, encodedImage) = cv2.imencode(".jpg", output_frame, encode_param)

            if not flag:
                continue

        # MJPEG 경계와 데이터 전송
        yield(b'--frame\r\n' b'Content-Type: image/jpeg\r\n\r\n' + 
              bytearray(encodedImage) + b'\r\n')

# --- Flask 라우트 설정 ---
@app.route("/video_feed")
def video_feed():
    """Flutter 앱이 접근할 스트림 엔드포인트."""
    # MJPEG 스트림을 반환
    return Response(generate(),
        mimetype = "multipart/x-mixed-replace; boundary=frame")


# ==================== 전처리 함수 ====================
def preprocess(frame):
    """YOLOv8 ONNX 입력 형식으로 전처리"""
    img = cv2.resize(frame, (INPUT_WIDTH, INPUT_HEIGHT))
    img = img.astype(np.float32) / 255.0
    img = np.transpose(img, (2, 0, 1))  # HWC -> CHW
    img = np.expand_dims(img, axis=0)  # 배치 차원 추가
    return img

# ==================== 후처리 함수 ====================
def postprocess(outputs, conf_threshold=0.4, nms_threshold=0.4):
    """YOLOv8 출력 후처리"""
    output = outputs[0][0]
    output = output.T  # (84, 8400) -> (8400, 84)

    boxes = []
    scores = []
    class_ids = []

    for detection in output:
        x, y, w, h = detection[0:4]
        class_scores = detection[4:]
        class_id = np.argmax(class_scores)
        confidence = class_scores[class_id]

        if confidence >= conf_threshold:
            # 좌표를 입력 크기에 맞게 조정 (640x480 화면 크기 기준)
            x_center = x * 640 / INPUT_WIDTH
            y_center = y * 480 / INPUT_HEIGHT
            box_w = w * 640 / INPUT_WIDTH
            box_h = h * 480 / INPUT_HEIGHT
            
            x1 = int(x_center - box_w/2)
            y1 = int(y_center - box_h/2)
            
            boxes.append([x1, y1, int(box_w), int(box_h)])
            scores.append(float(confidence))
            class_ids.append(class_id)

    # NMS
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
    
    # 윈도우 밖의 오래된 감지 기록 제거
    while detections and current_time - detections[0] > DETECTION_WINDOW:
        detections.popleft()

    if len(detections) > 0 and current_time - detections[0] >= required_duration:
        return True
    return False

# ==================== Firebase 이미지 업로드 함수 ====================
def upload_image_to_storage(frame, event_id):
    """OpenCV 프레임을 JPEG로 인코딩하여 Firebase Storage에 업로드"""
    if bucket is None:
        print("[WARNING] Firebase Storage가 초기화되지 않아 이미지를 업로드할 수 없습니다.")
        return None

    try:
        is_success, buffer = cv2.imencode(".jpg", frame)
        if not is_success:
            print("[ERROR] 이미지 인코딩 실패")
            return None

        image_bytes = buffer.tobytes()
        timestamp_str = datetime.now().strftime("%Y%m%d_%H%M%S")
        blob_path = f"detection_images/{timestamp_str}_{event_id}.jpg"
        
        blob = bucket.blob(blob_path)
        blob.upload_from_string(image_bytes, content_type='image/jpeg')

        blob.make_public()
        image_url = blob.public_url

        print(f"[FIREBASE] 이미지 업로드 완료: {image_url}")
        return image_url
        
    except Exception as e:
        print(f"[ERROR] Firebase Storage 이미지 업로드 실패: {e}")
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
                'location': 'N1동(본부관) 1층 입구',
                'timestamp': datetime.now().isoformat(),
                'image_url': image_url or '',
            },
            topic='smoking_detection'
        )

        response = messaging.send(message)
        print(f"[FCM] 푸시 알림 전송 완료: {response}")
        return response
    except Exception as e:
        print(f"[ERROR] 푸시 알림 전송 실패: {e}")
        return None

# ==================== Firebase 저장 함수 (비동기 처리) ====================
def save_to_firebase(event_type, details, frame=None):
    """Firebase에 감지 이벤트 저장"""
    if db is None:
        return

    try:
        doc_ref = db.collection('detection_events').document()
        event_id = doc_ref.id

        image_url = None
        if frame is not None:
            image_url = upload_image_to_storage(frame, event_id)

        event_data = {
            'type': event_type,
            'timestamp': firestore.SERVER_TIMESTAMP,
            'details': details,
            'resolved': False,
            'location': 'N1동(본부관) 1층 입구'
        }

        if image_url:
            event_data['image_url'] = image_url

        doc_ref.set(event_data)
        print(f"[FIREBASE] 이벤트 저장 완료: {event_type}")

        if event_type == 'smoking':
            send_push_notification(event_type, details, event_id, image_url)

    except Exception as e:
        print(f"[ERROR] Firebase 저장 실패: {e}")

# ==================== 메인 감지 루프 (추론 담당) ====================
def main_detection_loop():
    global last_warning_time, last_guide_time, output_frame
    
    print("[INFO] 감지 시작...")
    print("=" * 50)

    # OpenCV 윈도우 생성 (로컬 디버깅용)
    cv2.namedWindow('Smoke Detection', cv2.WINDOW_NORMAL)
    cv2.resizeWindow('Smoke Detection', 640, 480)

    try:
        while True:
            # 1. 캡처 루프가 채워준 output_frame에서 최신 영상 가져오기
            raw_frame = None
            with lock:
                if output_frame is None:
                    time.sleep(0.1) # 프레임이 채워지길 기다림
                    continue
                # 🚨 추론 및 디스플레이를 위해 원본 프레임의 복사본을 가져옴 🚨
                raw_frame = output_frame.copy() 
                
            current_time = time.time()
            display_frame = raw_frame.copy() # 바운딩 박스를 그릴 프레임

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

                if label == "Person":
                    color = (0, 255, 0)
                    person_detected = True
                    person_detections.append(current_time)
                elif label == "Cigarette":
                    color = (0, 0, 255)
                    cigarette_detected = True
                    cigarette_detections.append(current_time)
                # ... (나머지 감지 로직 및 바운딩 박스 그리기) ...
                elif label == "Smoke":
                    color = (0, 165, 255)
                    smoke_detected = True
                    smoke_detections.append(current_time)
                elif label == "Fire":
                    color = (0, 0, 255)
                    fire_detected = True
                    fire_detections.append(current_time)
                else:
                    color = (255, 255, 255)

                cv2.rectangle(display_frame, (x1, y1), (x2, y2), color, 2)
                label_text = f"{label}: {score:.2f}"
                cv2.putText(display_frame, label_text, (x1, y1 - 10),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

            # 4. 감지 상태 확인 및 경고/안내
            person_sustained = check_detection_duration(person_detections)
            cigarette_sustained = check_detection_duration(cigarette_detections)
            smoke_sustained = check_detection_duration(smoke_detections)
            
            if person_sustained and (cigarette_sustained or smoke_sustained):
                if current_time - last_warning_time >= WARNING_CYCLE:
                    print("=" * 50)
                    print("⚠️  [경고] 흡연 감지! 이벤트 저장 및 알림 전송.")
                    print("=" * 50)
                    play_audio_safe(WARNING_FILE)
                    last_warning_time = current_time

                    detection_details = {'message': '흡연 행위가 감지되었습니다'}
                    # 🚨 Firebase 저장을 비동기 스레드로 처리 🚨
                    save_thread = threading.Thread(
                        target=save_to_firebase, 
                        args=('smoking', detection_details, display_frame.copy()), # 박스 그려진 프레임 저장
                        daemon=True
                    )
                    save_thread.start()
            
            elif person_sustained and not cigarette_sustained and not smoke_sustained:
                if current_time - last_guide_time >= GUIDE_CYCLE:
                    print("ℹ️  [안내] 사람 감지 (흡연 아님)")
                    play_audio_safe(GUIDE_FILE)
                    last_guide_time = current_time

            # 5. 화면 표시 (바운딩 박스가 그려진 display_frame 사용)
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
        # 주의: picam2.stop()은 메인 루프에서만 실행
        # capture_thread가 아직 실행 중일 수 있으므로 picam2.stop()은 안전하게 한 번만 호출
        # (camera_capture_loop 스레드는 daemon=True로 설정되어 메인 스레드 종료 시 같이 종료됨)
        try:
            picam2.stop()
        except Exception:
            pass # 이미 중지되었을 경우 무시
        pygame.mixer.quit()
        print("[INFO] 정리 완료. 프로그램 종료.")


# ==================== 메인 실행 블록 ====================
if __name__ == '__main__':
    try:
        # 1. Flask 서버 스레드 실행
        print(f"🚀 Starting Flask server on 0.0.0.0:{FLASK_PORT}...")
        server_thread = threading.Thread(target=lambda: app.run(host='0.0.0.0', port=FLASK_PORT, debug=False, threaded=True, use_reloader=False))
        server_thread.daemon = True
        server_thread.start()
        
        # 2. 🚨 카메라 캡처 스레드 실행 (스트리밍 원본 제공) 🚨
        capture_thread = threading.Thread(target=camera_capture_loop, daemon=True)
        capture_thread.start()

        time.sleep(3) # 캡처 스레드가 프레임을 채울 시간을 줌
        
        # 3. 메인 감지 루프 시작
        main_detection_loop()

    except Exception as e:
        print(f"[FATAL ERROR] 서버 시작 실패 또는 프로그램 초기화 실패: {e}")