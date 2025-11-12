"""
Firebase 연결 테스트 스크립트
"""

from raspberry_pi_client import SmokingDetectionClient
import numpy as np
import cv2

def test_firebase_connection():
    """Firebase 연결 및 테스트 데이터 전송"""

    print("=" * 60)
    print("Firebase 연결 테스트 시작")
    print("=" * 60)

    try:
        # Firebase 클라이언트 초기화
        print("\n1. Firebase 클라이언트 초기화 중...")
        client = SmokingDetectionClient('firebase-service-account.json')
        print("✅ Firebase 클라이언트 초기화 성공!")

        # 장치 등록
        print("\n2. 장치 등록 중...")
        client.register_device(
            device_id='test-device-001',
            device_name='테스트 카메라',
            location='테스트 위치',
            stream_url='http://localhost:5000/api/camera/1/stream'
        )
        print("✅ 장치 등록 성공!")

        # 테스트 이미지 생성
        print("\n3. 테스트 이미지 생성 중...")
        dummy_image = np.zeros((480, 640, 3), dtype=np.uint8)
        # 텍스트 추가
        cv2.putText(
            dummy_image,
            'Firebase Test Detection',
            (50, 240),
            cv2.FONT_HERSHEY_SIMPLEX,
            1,
            (0, 255, 0),
            2
        )
        cv2.putText(
            dummy_image,
            'Smoking Detection System',
            (50, 300),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.8,
            (255, 255, 255),
            2
        )
        print("✅ 테스트 이미지 생성 완료!")

        # 테스트 감지 이벤트 전송
        print("\n4. 테스트 감지 이벤트 전송 중...")
        event_id = client.send_detection(
            camera_id=1,
            location='본관 1층 입구 (테스트)',
            detected_objects=['person', 'cigarette'],
            confidence=0.95,
            image=dummy_image
        )

        if event_id:
            print(f"✅ 테스트 이벤트 전송 성공!")
            print(f"   이벤트 ID: {event_id}")
            print("\n" + "=" * 60)
            print("🎉 Firebase 테스트 완료!")
            print("=" * 60)
            print("\n다음 단계:")
            print("1. Firebase 콘솔에서 Firestore Database 확인")
            print("   - events 컬렉션에 데이터가 있는지 확인")
            print("2. Firebase Storage에서 이미지 확인")
            print("   - detection_images 폴더에 이미지가 있는지 확인")
            print("3. Flutter 앱 실행하여 실시간 데이터 확인")
            print("=" * 60)
            return True
        else:
            print("❌ 테스트 이벤트 전송 실패")
            return False

    except Exception as e:
        print(f"\n❌ 오류 발생: {e}")
        print("\n문제 해결:")
        print("1. firebase-service-account.json 파일이 있는지 확인")
        print("2. Firebase 프로젝트 설정이 올바른지 확인")
        print("3. 인터넷 연결 확인")
        return False

if __name__ == '__main__':
    test_firebase_connection()
