"""
FCM (Firebase Cloud Messaging) 알림 전송 모듈

흡연 감지 시 앱에 푸시 알림을 전송합니다.

사용 방법:
1. firebase-service-account.json 파일 필요
2. pip install firebase-admin
3. send_smoking_detection_notification() 함수 호출
"""

import firebase_admin
from firebase_admin import credentials, firestore, messaging
from datetime import datetime


class FCMNotificationSender:
    def __init__(self, service_account_path='firebase-service-account.json'):
        """
        FCM 알림 전송 클라이언트 초기화

        Args:
            service_account_path: Firebase 서비스 계정 JSON 파일 경로
        """
        # Firebase가 이미 초기화되어 있는지 확인
        if not firebase_admin._apps:
            cred = credentials.Certificate(service_account_path)
            firebase_admin.initialize_app(cred)

        self.db = firestore.client()
        print("FCM notification client initialized")

    def send_to_topic(self, topic, title, body, data=None):
        """
        특정 주제(topic)로 알림 전송

        Args:
            topic: 주제 이름 (예: 'smoking_detection')
            title: 알림 제목
            body: 알림 내용
            data: 추가 데이터 딕셔너리 (선택사항)

        Returns:
            str: 메시지 ID 또는 None
        """
        try:
            # 메시지 구성
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=data or {},
                topic=topic,
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
            print(f"Notification sent successfully to topic: {topic}, message ID: {response}")
            return response

        except Exception as e:
            print(f"Failed to send notification: {e}")
            return None

    def send_to_token(self, token, title, body, data=None):
        """
        특정 기기 토큰으로 알림 전송

        Args:
            token: FCM 기기 토큰
            title: 알림 제목
            body: 알림 내용
            data: 추가 데이터 딕셔너리 (선택사항)

        Returns:
            str: 메시지 ID 또는 None
        """
        try:
            # 메시지 구성
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=data or {},
                token=token,
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
            print(f"Notification sent successfully to token: {token[:20]}..., message ID: {response}")
            return response

        except Exception as e:
            print(f"Failed to send notification: {e}")
            return None

    def send_to_all_tokens(self, title, body, data=None):
        """
        Firestore에 저장된 모든 토큰으로 알림 전송

        Args:
            title: 알림 제목
            body: 알림 내용
            data: 추가 데이터 딕셔너리 (선택사항)

        Returns:
            int: 성공적으로 전송된 메시지 수
        """
        try:
            # Firestore에서 모든 FCM 토큰 가져오기
            tokens_ref = self.db.collection('fcm_tokens')
            tokens_docs = tokens_ref.stream()

            tokens = []
            for doc in tokens_docs:
                token_data = doc.to_dict()
                if 'token' in token_data:
                    tokens.append(token_data['token'])

            if not tokens:
                print("Warning: No FCM tokens registered.")
                return 0

            print(f"Sending notifications to {len(tokens)} tokens...")

            # 멀티캐스트 메시지 전송
            message = messaging.MulticastMessage(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=data or {},
                tokens=tokens,
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
            response = messaging.send_multicast(message)
            print(f"Multicast notification sent: {response.success_count} succeeded, {response.failure_count} failed")

            return response.success_count

        except Exception as e:
            print(f"Failed to send notifications: {e}")
            return 0

    def send_smoking_detection_notification(self, camera_id, location, event_id=None, image_url=None):
        """
        흡연 감지 알림 전송 (주제 기반)

        Args:
            camera_id: 카메라 ID
            location: 감지 위치
            event_id: 이벤트 ID (선택사항)
            image_url: 이미지 URL (선택사항)

        Returns:
            str: 메시지 ID 또는 None
        """
        title = "🚬 흡연 감지!"
        body = f"{location}에서 흡연이 감지되었습니다."

        data = {
            'type': 'smoking_detection',
            'cameraId': str(camera_id),
            'location': location,
            'timestamp': datetime.now().isoformat(),
        }

        if event_id:
            data['eventId'] = event_id

        if image_url:
            data['imageUrl'] = image_url

        # 주제로 전송
        return self.send_to_topic('smoking_detection', title, body, data)

    def send_smoking_detection_to_all(self, camera_id, location, event_id=None, image_url=None):
        """
        흡연 감지 알림을 모든 기기에 전송

        Args:
            camera_id: 카메라 ID
            location: 감지 위치
            event_id: 이벤트 ID (선택사항)
            image_url: 이미지 URL (선택사항)

        Returns:
            int: 성공적으로 전송된 메시지 수
        """
        title = "🚬 흡연 감지!"
        body = f"{location}에서 흡연이 감지되었습니다."

        data = {
            'type': 'smoking_detection',
            'cameraId': str(camera_id),
            'location': location,
            'timestamp': datetime.now().isoformat(),
        }

        if event_id:
            data['eventId'] = event_id

        if image_url:
            data['imageUrl'] = image_url

        # 모든 토큰으로 전송
        return self.send_to_all_tokens(title, body, data)


# 테스트 코드
if __name__ == '__main__':
    print("=== FCM 알림 전송 테스트 ===\n")

    # FCM 클라이언트 초기화
    sender = FCMNotificationSender('firebase-service-account.json')

    # 테스트 알림 전송 (주제 기반)
    print("\n1. 주제(topic) 기반 알림 전송 테스트...")
    sender.send_smoking_detection_notification(
        camera_id=1,
        location='본관 1층 입구',
        event_id='test_event_001'
    )

    # 테스트 알림 전송 (모든 기기)
    print("\n2. 모든 기기로 알림 전송 테스트...")
    success_count = sender.send_smoking_detection_to_all(
        camera_id=2,
        location='본관 2층 복도',
        event_id='test_event_002'
    )
    print(f"\n✅ {success_count}개 기기에 알림 전송 완료")

    print("\n=== 테스트 완료 ===")
