"""
흡연 감지 시스템
YOLOv8을 사용하여 사람을 감지합니다.
"""

from ultralytics import YOLO
import cv2
import numpy as np
from datetime import datetime
import json
import os

class SmokingDetector:
    """흡연 감지 클래스"""

    def __init__(self, model_path='yolov8n.pt', confidence_threshold=0.5):
        """
        Args:
            model_path: YOLO 모델 경로
            confidence_threshold: 감지 신뢰도 임계값
        """
        print("Loading YOLO model...")
        self.model = YOLO(model_path)
        self.confidence_threshold = confidence_threshold
        self.detection_history = []

        # 감지 이벤트 저장 디렉토리
        self.events_dir = 'detection_events'
        if not os.path.exists(self.events_dir):
            os.makedirs(self.events_dir)

        print(f"Smoking Detector initialized (confidence >= {confidence_threshold})")

    def detect_person(self, frame):
        """
        프레임에서 사람 감지

        Args:
            frame: OpenCV 이미지 프레임

        Returns:
            list: 감지된 사람들의 정보 [(x1, y1, x2, y2, confidence), ...]
        """
        results = self.model(frame, verbose=False)

        persons = []
        for result in results:
            boxes = result.boxes
            for box in boxes:
                # class_id 0 = person in COCO dataset
                if int(box.cls[0]) == 0:
                    confidence = float(box.conf[0])
                    if confidence >= self.confidence_threshold:
                        # 바운딩 박스 좌표
                        x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
                        persons.append({
                            'bbox': [int(x1), int(y1), int(x2), int(y2)],
                            'confidence': confidence
                        })

        return persons

    def analyze_frame(self, frame, camera_id=1):
        """
        프레임 분석 및 흡연 감지

        Args:
            frame: OpenCV 이미지 프레임
            camera_id: 카메라 ID

        Returns:
            dict: 감지 결과
        """
        # 사람 감지
        persons = self.detect_person(frame)

        # 현재는 간단한 규칙: 사람이 감지되면 잠재적 흡연 상황으로 간주
        # 실제로는 더 복잡한 로직이 필요 (손, 입, 담배 등 감지)
        is_smoking_detected = len(persons) > 0

        result = {
            'timestamp': datetime.now().isoformat(),
            'camera_id': camera_id,
            'persons_detected': len(persons),
            'persons': persons,
            'smoking_detected': is_smoking_detected,
            'confidence': max([p['confidence'] for p in persons]) if persons else 0.0
        }

        # 감지 이력에 추가
        self.detection_history.append(result)

        # 최근 100개만 유지
        if len(self.detection_history) > 100:
            self.detection_history = self.detection_history[-100:]

        return result

    def draw_detections(self, frame, persons):
        """
        감지된 사람들을 프레임에 표시

        Args:
            frame: OpenCV 이미지 프레임
            persons: 감지된 사람 리스트

        Returns:
            frame: 바운딩 박스가 그려진 프레임
        """
        for person in persons:
            x1, y1, x2, y2 = person['bbox']
            confidence = person['confidence']

            # 바운딩 박스 그리기
            cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)

            # 텍스트 배경
            text = f'Person {confidence:.2f}'
            (text_width, text_height), _ = cv2.getTextSize(
                text, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2
            )
            cv2.rectangle(
                frame,
                (x1, y1 - text_height - 10),
                (x1 + text_width, y1),
                (0, 255, 0),
                -1
            )

            # 텍스트
            cv2.putText(
                frame,
                text,
                (x1, y1 - 5),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.6,
                (0, 0, 0),
                2
            )

        return frame

    def save_detection_event(self, frame, result):
        """
        감지 이벤트 저장

        Args:
            frame: OpenCV 이미지 프레임
            result: 감지 결과

        Returns:
            dict: 저장된 파일 정보
        """
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')

        # 이미지 저장
        image_filename = f'detection_{timestamp}.jpg'
        image_path = os.path.join(self.events_dir, image_filename)
        cv2.imwrite(image_path, frame)

        # JSON 메타데이터 저장
        json_filename = f'detection_{timestamp}.json'
        json_path = os.path.join(self.events_dir, json_filename)

        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(result, f, indent=2, ensure_ascii=False)

        return {
            'image_path': image_path,
            'json_path': json_path,
            'image_url': f'/api/detection_events/{image_filename}'
        }

    def get_recent_detections(self, limit=10):
        """
        최근 감지 이력 반환

        Args:
            limit: 반환할 개수

        Returns:
            list: 최근 감지 이력
        """
        return self.detection_history[-limit:]


if __name__ == '__main__':
    # 테스트 코드
    print("Testing Smoking Detector...")

    detector = SmokingDetector()

    # 웹캠 테스트
    cap = cv2.VideoCapture(0)

    if not cap.isOpened():
        print("Cannot open camera")
        exit()

    print("Press 'q' to quit, 's' to save detection")

    while True:
        ret, frame = cap.read()
        if not ret:
            print("Can't receive frame")
            break

        # 감지 수행
        result = detector.analyze_frame(frame)

        # 감지 결과 표시
        if result['persons_detected'] > 0:
            frame = detector.draw_detections(frame, result['persons'])

            # 화면에 정보 표시
            text = f"Persons: {result['persons_detected']}"
            cv2.putText(frame, text, (10, 30),
                       cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)

        # 화면 표시
        cv2.imshow('Smoking Detection Test', frame)

        # 키 입력 처리
        key = cv2.waitKey(1) & 0xFF
        if key == ord('q'):
            break
        elif key == ord('s') and result['persons_detected'] > 0:
            # 이벤트 저장
            saved = detector.save_detection_event(frame, result)
            print(f"Detection saved: {saved['image_path']}")

    cap.release()
    cv2.destroyAllWindows()
    print("Test completed")
