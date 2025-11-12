"""
흡연 감지 시스템 - 간단 버전 (앱 연동용)
Google Drive 기능 제외, Firebase 연동만 포함
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
from firebase_admin import credentials, firestore

# ==================== 설정 ====================
# ONNX 모델 설정
ONNX_MODEL_PATH = "final_detection640.onnx"
INPUT_WIDTH = 640
INPUT_HEIGHT = 640
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
DETECTION_WINDOW = 10    # 감지 판단 윈도우 (초)
REQUIRED_DURATION = 3    # 필요한 지속 시간 (초)

# Firebase 설정
FIREBASE_CREDENTIAL_PATH = "firebase-service-account.json"

# ==================== 전역 변수 ====================
person_detections = deque(maxlen=DETECTION_WINDOW)
cigarette_detections = deque(maxlen=DETECTION_WINDOW)
smoke_detections = deque(maxlen=DETECTION_WINDOW)
fire_detections = deque(maxlen=DETECTION_WINDOW)

last_guide_time = 0
last_warning_time = 0

# ==================== Pygame 초기화 ====================
pygame.mixer.init(frequency=44100, buffer=4096)

# ==================== Firebase 초기화 ====================
print(f"[INFO] Firebase 초기화 중...")
try:
    cred = credentials.Certificate(FIREBASE_CREDENTIAL_PATH)
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("[INFO] Firebase 연결 완료")
except Exception as e:
    print(f"[ERROR] Firebase 초기화 실패: {e}")
    print("[WARNING] Firebase 없이 계속 진행합니다")
    db = None

# ==================== ONNX 모델 로드 ====================
print(f"[INFO] ONNX 모델 로드 중: {ONNX_MODEL_PATH}")
session = ort.InferenceSession(ONNX_MODEL_PATH, providers=['CPUExecutionProvider'])
print("[INFO] ONNX 모델 로드 완료")

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

# ==================== 전처리 함수 ====================
def preprocess(frame):
    """YOLOv8 ONNX 입력 형식으로 전처리"""
    img = cv2.resize(frame, (INPUT_WIDTH, INPUT_HEIGHT))
    img = img.astype(np.float32) / 255.0
    img = np.transpose(img, (2, 0, 1))  # HWC -> CHW
    img = np.expand_dims(img, axis=0)   # 배치 차원 추가
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
            boxes.append([x - w/2, y - h/2, w, h])
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
            pygame.mixer.music.load(audio_file)
            pygame.mixer.music.play()
            print(f"[AUDIO] {audio_file} 재생 시작")
        except Exception as e:
            print(f"[ERROR] 음성 재생 실패: {e}")

# ==================== 감지 확인 함수 ====================
def check_detection_duration(detections, required_duration=REQUIRED_DURATION):
    """감지 지속 시간 확인"""
    if len(detections) == 0:
        return False
    current_time = time.time()
    recent_detections = [t for t in detections if current_time - t <= DETECTION_WINDOW]

    if len(recent_detections) >= required_duration:
        return True
    return False

# ==================== Firebase 저장 함수 ====================
def save_to_firebase(event_type, details):
    """Firebase에 감지 이벤트 저장"""
    if db is None:
        return

    try:
        event_data = {
            'type': event_type,  # 'smoking' 또는 'person'
            'timestamp': firestore.SERVER_TIMESTAMP,
            'details': details,
            'resolved': False
        }

        doc_ref = db.collection('detection_events').add(event_data)
        print(f"[FIREBASE] 이벤트 저장 완료: {event_type}")
    except Exception as e:
        print(f"[ERROR] Firebase 저장 실패: {e}")

# ==================== 메인 루프 ====================
print("[INFO] 감지 시작...")
print("=" * 50)

# OpenCV 윈도우 생성
cv2.namedWindow('Smoke Detection', cv2.WINDOW_NORMAL)
cv2.resizeWindow('Smoke Detection', 640, 480)

try:
    while True:
        # 프레임 캡처
        frame = picam2.capture_array()
        current_time = time.time()

        # 화면 표시용 프레임 복사
        display_frame = frame.copy()

        # 전처리
        input_data = preprocess(frame)

        # 추론
        outputs = session.run(None, {session.get_inputs()[0].name: input_data})

        # 후처리
        boxes, scores, class_ids = postprocess(outputs, CONF_THRESHOLD, NMS_THRESHOLD)

        # 감지 결과 기록
        person_detected = False
        cigarette_detected = False
        smoke_detected = False
        fire_detected = False

        # 감지된 객체에 바운딩 박스 그리기
        for box, score, class_id in zip(boxes, scores, class_ids):
            label = labels[class_id]
            x, y, w, h = box

            # 바운딩 박스 좌표 계산
            x1 = int(x)
            y1 = int(y)
            x2 = int(x + w)
            y2 = int(y + h)

            # 클래스별 색상 설정
            if label == "Person":
                color = (0, 255, 0)  # 초록색
                person_detected = True
                person_detections.append(current_time)
            elif label == "Cigarette":
                color = (0, 0, 255)  # 빨간색
                cigarette_detected = True
                cigarette_detections.append(current_time)
            elif label == "Smoke":
                color = (0, 165, 255)  # 주황색
                smoke_detected = True
                smoke_detections.append(current_time)
            elif label == "Fire":
                color = (0, 0, 255)  # 빨간색
                fire_detected = True
                fire_detections.append(current_time)
            else:
                color = (255, 255, 255)

            # 바운딩 박스 그리기
            cv2.rectangle(display_frame, (x1, y1), (x2, y2), color, 2)

            # 레이블과 신뢰도 표시
            label_text = f"{label}: {score:.2f}"
            cv2.putText(display_frame, label_text, (x1, y1 - 10),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

        # 감지 상태 출력
        status = []
        if person_detected:
            status.append("👤Person")
        if cigarette_detected:
            status.append("🚬Cigarette")
        if smoke_detected:
            status.append("💨Smoke")
        if fire_detected:
            status.append("🔥Fire")

        if status:
            print(f"[{datetime.now().strftime('%H:%M:%S')}] 감지: {' '.join(status)}")

        # 화면에 상태 표시
        status_y = 30
        for status_text in status:
            cv2.putText(display_frame, status_text, (10, status_y),
                       cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 255), 2)
            status_y += 40

        # 음성 안내/경고 판단
        person_sustained = check_detection_duration(person_detections)
        cigarette_sustained = check_detection_duration(cigarette_detections)
        smoke_sustained = check_detection_duration(smoke_detections)

        # 경고 상황 (Person + Cigarette/Smoke)
        if person_sustained and (cigarette_sustained or smoke_sustained):
            if current_time - last_warning_time >= WARNING_CYCLE:
                print("=" * 50)
                print("⚠️  [경고] 흡연 감지!")
                print("=" * 50)
                play_audio_safe(WARNING_FILE)
                last_warning_time = current_time

                # Firebase에 이벤트 저장
                detection_details = {
                    'person': person_detected,
                    'cigarette': cigarette_detected,
                    'smoke': smoke_detected,
                    'fire': fire_detected,
                    'message': '흡연 행위가 감지되었습니다'
                }
                save_to_firebase('smoking', detection_details)

        # 안내 상황 (Person만)
        elif person_sustained and not cigarette_sustained and not smoke_sustained:
            if current_time - last_guide_time >= GUIDE_CYCLE:
                print("-" * 50)
                print("ℹ️  [안내] 사람 감지")
                print("-" * 50)
                play_audio_safe(GUIDE_FILE)
                last_guide_time = current_time

        # 화면 표시
        cv2.imshow('Smoke Detection', display_frame)

        # 'q' 키를 누르면 종료
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

        # 잠시 대기
        time.sleep(0.1)

except KeyboardInterrupt:
    print("\n[INFO] 프로그램 종료 중...")

finally:
    picam2.stop()
    pygame.mixer.quit()
    cv2.destroyAllWindows()
    print("[INFO] 정리 완료. 프로그램 종료.")
