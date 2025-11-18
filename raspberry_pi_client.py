"""
라즈베리파이 YOLO 감지 → Firebase 전송 클라이언트

사용 방법:
1. firebase-service-account.json 파일을 프로젝트 폴더에 배치
2. pip install firebase-admin opencv-python numpy
3. YOLO 모델과 통합하여 사용

"""

import firebase_admin
from firebase_admin import credentials, firestore, storage, messaging
import cv2
import numpy as np
from datetime import datetime
import time
import io

class SmokingDetectionClient:
    def __init__(self, service_account_path='firebase-service-account.json'):
        """
        Firebase 클라이언트 초기화

        Args:
            service_account_path: Firebase 서비스 계정 JSON 파일 경로
        """
        # Firebase 초기화
        cred = credentials.Certificate(service_account_path)
        firebase_admin.initialize_app(cred, {
            'storageBucket': 'smoke-detection-system-d85b6.firebasestorage.app'
        })

        self.db = firestore.client()
        self.bucket = storage.bucket()

        print("Firebase 클라이언트 초기화 완료")

    def send_detection(self, camera_id, location, detected_objects, confidence, image=None, send_notification=True):
        """
        감지 결과를 Firebase에 전송 및 푸시 알림 전송

        Args:
            camera_id: 카메라 ID (int)
            location: 위치 (str)
            detected_objects: 감지된 객체 목록 (list)
            confidence: 신뢰도 (float)
            image: OpenCV 이미지 (numpy array, 선택사항)
            send_notification: 푸시 알림 전송 여부 (기본값: True)

        Returns:
            str: 생성된 이벤트 ID 또는 None
        """
        try:
            # Firestore에 이벤트 문서 생성
            doc_ref = self.db.collection('events').document()
            event_id = doc_ref.id

            # 이미지 업로드 (있으면)
            image_url = None
            if image is not None:
                image_url = self._upload_image(event_id, image)

            # 이벤트 데이터
            event_data = {
                'camera_id': camera_id,
                'location': location,
                'detected_objects': detected_objects,
                'confidence': confidence,
                'timestamp': firestore.SERVER_TIMESTAMP,
                'created_at': firestore.SERVER_TIMESTAMP,
                'status': 'pending',
            }

            if image_url:
                event_data['image_url'] = image_url

            # Firestore에 저장
            doc_ref.set(event_data)

            print(f"✅ 감지 이벤트 전송 성공: {event_id}")
            print(f"   위치: {location}")
            print(f"   감지 객체: {detected_objects}")
            print(f"   신뢰도: {confidence:.2f}")

            # 푸시 알림 전송
            if send_notification:
                self._send_fcm_notification(camera_id, location, event_id, image_url)

            return event_id

        except Exception as e:
            print(f"❌ 감지 이벤트 전송 실패: {e}")
            return None

    def _send_fcm_notification(self, camera_id, location, event_id, image_url=None):
        """
        FCM 푸시 알림 전송

        Args:
            camera_id: 카메라 ID
            location: 감지 위치
            event_id: 이벤트 ID
            image_url: 이미지 URL (선택사항)
        """
        try:
            title = "🚬 흡연 감지!"
            body = f"{location}에서 흡연이 감지되었습니다."

            data = {
                'type': 'smoking_detection',
                'cameraId': str(camera_id),
                'location': location,
                'eventId': event_id,
                'timestamp': datetime.now().isoformat(),
            }

            if image_url:
                data['imageUrl'] = image_url

            # 메시지 구성
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=data,
                topic='smoking_detection',
                android=messaging.AndroidConfig(
                    priority='high',
                    notification=messaging.AndroidNotification(
                        icon='notification_icon',
                        color='#FF0000',
                        sound='default',
                        channel_id='smoking_detection',
                    ),
                ),
            )

            # 메시지 전송
            response = messaging.send(message)
            print(f"✅ 푸시 알림 전송 성공: {response}")

        except Exception as e:
            print(f"❌ 푸시 알림 전송 실패: {e}")

    def _upload_image(self, event_id, image):
        """
        이미지를 Firebase Storage에 업로드

        Args:
            event_id: 이벤트 ID
            image: OpenCV 이미지 (numpy array)

        Returns:
            str: 다운로드 URL 또는 None
        """
        try:
            # 이미지를 JPEG로 인코딩
            _, buffer = cv2.imencode('.jpg', image)
            image_bytes = buffer.tobytes()

            # Storage에 업로드
            blob = self.bucket.blob(f'detection_images/{event_id}.jpg')
            blob.upload_from_string(
                image_bytes,
                content_type='image/jpeg'
            )

            # Public URL 생성 (선택사항)
            blob.make_public()

            return blob.public_url

        except Exception as e:
            print(f"❌ 이미지 업로드 실패: {e}")
            return None

    def register_device(self, device_id, device_name, location, stream_url=None):
        """
        장치 정보를 Firebase에 등록

        Args:
            device_id: 장치 ID
            device_name: 장치 이름
            location: 설치 위치
            stream_url: MJPEG 스트림 URL (선택사항)
        """
        try:
            device_data = {
                'device_id': device_id,
                'device_name': device_name,
                'location': location,
                'status': 'online',
                'last_seen': firestore.SERVER_TIMESTAMP,
                'created_at': firestore.SERVER_TIMESTAMP,
            }

            if stream_url:
                device_data['stream_url'] = stream_url

            self.db.collection('devices').document(device_id).set(device_data)

            print(f"✅ 장치 등록 성공: {device_name}")

        except Exception as e:
            print(f"❌ 장치 등록 실패: {e}")

    def update_device_heartbeat(self, device_id):
        """
        장치 상태를 업데이트 (살아있음 알림)

        Args:
            device_id: 장치 ID
        """
        try:
            self.db.collection('devices').document(device_id).update({
                'status': 'online',
                'last_seen': firestore.SERVER_TIMESTAMP,
            })
        except Exception as e:
            print(f"❌ 장치 상태 업데이트 실패: {e}")


# ==================== YOLO 통합 예제 ====================

def yolo_detection_example():
    """
    YOLO와 통합하는 예제 코드
    실제 YOLO 모델 로드 및 감지 코드로 대체하세요
    """

    # Firebase 클라이언트 초기화
    client = SmokingDetectionClient('firebase-service-account.json')

    # 장치 등록
    client.register_device(
        device_id='raspberry-pi-001',
        device_name='본관 1층 CCTV',
        location='본관 1층 입구',
        stream_url='http://192.168.1.100:5000/api/camera/1/stream'  # Flask 서버 URL
    )

    # 카메라 캡처 시작
    cap = cv2.VideoCapture(0)  # 웹캠 0번

    print("감지 시작... (Ctrl+C로 종료)")

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                break

            # TODO: 여기에 YOLO 감지 코드 추가
            # 예시:
            # results = model.predict(frame)
            # detected_objects = results.get_objects()
            # confidence = results.get_confidence()

            # 더미 감지 (실제 YOLO 결과로 대체)
            detected_objects = []
            confidence = 0.0

            # 사람 감지 시뮬레이션 (실제로는 YOLO에서 가져옴)
            # if '사람' in detected_objects and '담배' in detected_objects:
            #     detected_objects = ['person', 'cigarette']
            #     confidence = 0.95

            # 감지된 경우 Firebase에 전송
            if confidence > 0.8:  # 신뢰도 임계값
                client.send_detection(
                    camera_id=1,
                    location='본관 1층 입구',
                    detected_objects=detected_objects,
                    confidence=confidence,
                    image=frame  # 감지된 프레임 전송
                )

                # 중복 전송 방지를 위해 잠시 대기
                time.sleep(5)

            # 장치 상태 업데이트 (1분마다)
            if int(time.time()) % 60 == 0:
                client.update_device_heartbeat('raspberry-pi-001')

            # ESC 키로 종료
            if cv2.waitKey(1) & 0xFF == 27:
                break

    except KeyboardInterrupt:
        print("\n감지 중지됨")

    finally:
        cap.release()
        cv2.destroyAllWindows()


# ==================== 테스트 코드 ====================

def test_send_detection():
    """
    감지 전송 테스트 (YOLO 없이)
    """
    client = SmokingDetectionClient('firebase-service-account.json')

    # 더미 이미지 생성
    dummy_image = np.zeros((480, 640, 3), dtype=np.uint8)
    cv2.putText(dummy_image, 'Test Detection', (50, 240),
                cv2.FONT_HERSHEY_SIMPLEX, 2, (255, 255, 255), 3)

    # 테스트 전송
    event_id = client.send_detection(
        camera_id=1,
        location='테스트 위치',
        detected_objects=['person', 'cigarette'],
        confidence=0.95,
        image=dummy_image
    )

    if event_id:
        print(f"✅ 테스트 성공! 이벤트 ID: {event_id}")
        print("Flutter 앱에서 확인하세요!")
    else:
        print("❌ 테스트 실패")


if __name__ == '__main__':
    # 테스트 실행
    # test_send_detection()

    # 또는 YOLO 통합 실행
    # yolo_detection_example()

    print("사용 방법:")
    print("1. test_send_detection() - 간단한 테스트")
    print("2. yolo_detection_example() - YOLO 통합 예제")
