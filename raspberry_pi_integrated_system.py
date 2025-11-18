#!/usr/bin/env python3
"""
라즈베리파이 통합 시스템
YOLO 감지 + Firebase 전송 + 카메라 스트리밍

사용 방법:
1. 라즈베리파이에 이 파일과 필요한 파일들을 복사
2. python3 raspberry_pi_integrated_system.py
"""

import cv2
import time
import threading
from smoking_detector import SmokingDetector
from raspberry_pi_client import SmokingDetectionClient

class IntegratedSmokingDetectionSystem:
    """통합 흡연 감지 시스템"""

    def __init__(
        self,
        camera_id=1,
        device_id='raspberry-pi-001',
        location='본관 1층 입구',
        firebase_service_account='firebase-service-account.json'
    ):
        """
        Args:
            camera_id: 카메라 ID
            device_id: 장치 ID
            location: 설치 위치
            firebase_service_account: Firebase 서비스 계정 JSON 파일 경로
        """
        print("=" * 60)
        print("통합 흡연 감지 시스템 초기화 중...")
        print("=" * 60)

        self.camera_id = camera_id
        self.device_id = device_id
        self.location = location

        # YOLO 감지기 초기화
        print("\n[1/3] YOLO 감지기 초기화...")
        self.detector = SmokingDetector(
            model_path='yolov8n.pt',  # YOLOv8 Nano 모델
            confidence_threshold=0.5
        )
        print("✓ YOLO 감지기 준비 완료")

        # Firebase 클라이언트 초기화
        print("\n[2/3] Firebase 클라이언트 초기화...")
        self.firebase_client = SmokingDetectionClient(firebase_service_account)
        print("✓ Firebase 연결 완료")

        # 장치 등록
        print(f"\n[3/3] 장치 등록 중... ({device_id})")
        self.firebase_client.register_device(
            device_id=device_id,
            device_name=f'CCTV Camera {camera_id}',
            location=location
        )
        print("✓ 장치 등록 완료")

        # 카메라 초기화
        print("\n카메라 초기화 중...")
        self.cap = cv2.VideoCapture(0)
        if not self.cap.isOpened():
            raise RuntimeError("❌ 카메라를 열 수 없습니다!")
        print("✓ 카메라 준비 완료")

        # 통계
        self.detection_count = 0
        self.last_detection_time = 0
        self.detection_cooldown = 5  # 5초 쿨다운 (중복 감지 방지)

        # 하트비트 스레드
        self.running = False
        self.heartbeat_thread = None

        print("\n" + "=" * 60)
        print("✅ 시스템 초기화 완료!")
        print("=" * 60)
        print(f"카메라 ID: {camera_id}")
        print(f"장치 ID: {device_id}")
        print(f"위치: {location}")
        print("=" * 60)

    def _heartbeat_worker(self):
        """하트비트 워커 (1분마다 장치 상태 업데이트)"""
        while self.running:
            try:
                self.firebase_client.update_device_heartbeat(self.device_id)
                print(f"💓 하트비트 전송 (감지 횟수: {self.detection_count})")
            except Exception as e:
                print(f"⚠️  하트비트 전송 실패: {e}")

            time.sleep(60)  # 1분 대기

    def start(self, display=False):
        """
        감지 시스템 시작

        Args:
            display: True면 화면에 감지 결과 표시 (라즈베리파이에 모니터 연결 시)
        """
        print("\n🎥 감지 시스템 시작...")
        print("Press Ctrl+C to stop\n")

        self.running = True

        # 하트비트 스레드 시작
        self.heartbeat_thread = threading.Thread(
            target=self._heartbeat_worker,
            daemon=True
        )
        self.heartbeat_thread.start()

        try:
            while True:
                # 프레임 읽기
                ret, frame = self.cap.read()
                if not ret:
                    print("⚠️  프레임을 읽을 수 없습니다")
                    time.sleep(1)
                    continue

                # YOLO 감지 수행
                result = self.detector.analyze_frame(frame, self.camera_id)

                # 사람이 감지되었고 쿨다운 시간이 지났다면
                current_time = time.time()
                if (result['persons_detected'] > 0 and
                    current_time - self.last_detection_time > self.detection_cooldown):

                    # 감지 결과 표시
                    confidence = result['confidence']
                    print(f"\n{'='*60}")
                    print(f"🚨 흡연 감지!")
                    print(f"{'='*60}")
                    print(f"시간: {result['timestamp']}")
                    print(f"위치: {self.location}")
                    print(f"감지된 사람 수: {result['persons_detected']}")
                    print(f"신뢰도: {confidence:.2%}")

                    # Firebase에 전송
                    print("\n📤 Firebase에 전송 중...")
                    event_id = self.firebase_client.send_detection(
                        camera_id=self.camera_id,
                        location=self.location,
                        detected_objects=['person'],  # 실제로는 YOLO 결과 사용
                        confidence=confidence,
                        image=frame
                    )

                    if event_id:
                        print(f"✅ 전송 성공! Event ID: {event_id}")
                        print(f"📱 Flutter 앱에서 확인하세요!")
                        self.detection_count += 1
                        self.last_detection_time = current_time
                    else:
                        print("❌ 전송 실패")

                    print("="*60 + "\n")

                # 화면 표시 (옵션)
                if display:
                    display_frame = frame.copy()

                    # 감지 결과 그리기
                    if result['persons_detected'] > 0:
                        display_frame = self.detector.draw_detections(
                            display_frame,
                            result['persons']
                        )

                    # 정보 텍스트
                    info_text = f"Camera {self.camera_id} | Detections: {self.detection_count}"
                    cv2.putText(
                        display_frame,
                        info_text,
                        (10, 30),
                        cv2.FONT_HERSHEY_SIMPLEX,
                        0.7,
                        (0, 255, 0),
                        2
                    )

                    cv2.imshow('Smoking Detection System', display_frame)

                    # 'q' 키로 종료
                    if cv2.waitKey(1) & 0xFF == ord('q'):
                        break

                # CPU 사용률 조절
                time.sleep(0.1)

        except KeyboardInterrupt:
            print("\n\n⏹️  시스템 중지 중...")

        finally:
            self.stop()

    def stop(self):
        """시스템 중지"""
        self.running = False

        if self.cap:
            self.cap.release()

        cv2.destroyAllWindows()

        print("\n" + "="*60)
        print("📊 통계")
        print("="*60)
        print(f"총 감지 횟수: {self.detection_count}")
        print("="*60)
        print("\n✅ 시스템 종료 완료")


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(description='통합 흡연 감지 시스템')
    parser.add_argument('--camera-id', type=int, default=1, help='카메라 ID')
    parser.add_argument('--device-id', default='raspberry-pi-001', help='장치 ID')
    parser.add_argument('--location', default='본관 1층 입구', help='설치 위치')
    parser.add_argument('--display', action='store_true', help='화면에 감지 결과 표시')

    args = parser.parse_args()

    # 시스템 시작
    system = IntegratedSmokingDetectionSystem(
        camera_id=args.camera_id,
        device_id=args.device_id,
        location=args.location
    )

    system.start(display=args.display)
