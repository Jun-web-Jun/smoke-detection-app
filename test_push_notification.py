"""
푸시 알림 테스트 스크립트

Firebase Cloud Messaging을 통해 테스트 알림을 전송합니다.

사용 방법:
1. firebase-service-account.json 파일 준비
2. Flutter 앱 실행 (FCM 토큰 등록됨)
3. 이 스크립트 실행: python test_push_notification.py
"""

from fcm_notification_sender import FCMNotificationSender
import time

def test_basic_notification():
    """기본 알림 테스트"""
    print("=== 푸시 알림 테스트 시작 ===\n")

    # FCM 클라이언트 초기화
    sender = FCMNotificationSender('firebase-service-account.json')

    print("\n테스트 1: 주제(topic) 기반 알림 전송")
    print("-" * 50)
    result1 = sender.send_to_topic(
        topic='smoking_detection',
        title='🚬 테스트 알림',
        body='이것은 테스트 알림입니다. 앱에서 확인하세요!',
        data={
            'type': 'test',
            'message': 'Hello from Python!'
        }
    )
    if result1:
        print(f"✅ 알림 전송 성공: {result1}")
    else:
        print("❌ 알림 전송 실패")

    time.sleep(2)

    print("\n테스트 2: 흡연 감지 시뮬레이션")
    print("-" * 50)
    result2 = sender.send_smoking_detection_notification(
        camera_id=1,
        location='본관 1층 입구 (테스트)',
        event_id='test_event_' + str(int(time.time()))
    )
    if result2:
        print(f"✅ 흡연 감지 알림 전송 성공")
    else:
        print("❌ 흡연 감지 알림 전송 실패")

    time.sleep(2)

    print("\n테스트 3: 모든 기기로 알림 전송")
    print("-" * 50)
    success_count = sender.send_smoking_detection_to_all(
        camera_id=2,
        location='본관 2층 복도 (테스트)',
        event_id='test_event_' + str(int(time.time()))
    )
    print(f"✅ {success_count}개 기기에 알림 전송 완료")

    print("\n=== 테스트 완료 ===")
    print("📱 Flutter 앱에서 알림을 확인하세요!")

def test_multiple_notifications():
    """여러 개의 알림 연속 전송 테스트"""
    print("=== 다중 알림 테스트 시작 ===\n")

    sender = FCMNotificationSender('firebase-service-account.json')

    locations = [
        '본관 1층 입구',
        '본관 2층 복도',
        '본관 3층 화장실 앞',
        '별관 1층 로비',
        '별관 지하 주차장'
    ]

    for i, location in enumerate(locations, 1):
        print(f"\n[{i}/{len(locations)}] {location}에서 감지 시뮬레이션...")
        sender.send_smoking_detection_notification(
            camera_id=i,
            location=location,
            event_id=f'multi_test_{int(time.time())}_{i}'
        )
        time.sleep(3)  # 3초 간격으로 전송

    print("\n=== 다중 알림 테스트 완료 ===")

if __name__ == '__main__':
    print("푸시 알림 테스트 메뉴:")
    print("1. 기본 알림 테스트")
    print("2. 다중 알림 연속 전송 테스트")
    print()

    choice = input("선택 (1 또는 2, 기본값 1): ").strip()

    if choice == '2':
        test_multiple_notifications()
    else:
        test_basic_notification()
