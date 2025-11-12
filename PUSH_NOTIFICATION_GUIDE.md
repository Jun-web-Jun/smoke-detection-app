# 푸시 알림 기능 가이드

## 개요

흡연 감지 시 실시간으로 푸시 알림을 전송하는 기능이 추가되었습니다.

## 주요 기능

### 1. Flutter 앱 (클라이언트)
- ✅ FCM 토큰 자동 등록
- ✅ 포그라운드/백그라운드 알림 수신
- ✅ 알림 클릭 시 이벤트 상세 화면으로 이동
- ✅ 주제(topic) 구독을 통한 그룹 알림
- ✅ 알림 권한 자동 요청

### 2. Python 백엔드 (서버)
- ✅ Firebase Cloud Messaging API 연동
- ✅ 흡연 감지 시 자동 알림 전송
- ✅ 주제 기반 또는 개별 기기로 전송
- ✅ 이미지 URL 포함 가능

## 사용 방법

### Flutter 앱 설정

1. **앱 설치 및 실행**
   ```bash
   flutter build apk --release
   # APK 파일: build/app/outputs/flutter-apk/app-release.apk
   ```

2. **자동 초기화**
   - 앱 실행 시 자동으로 알림 권한 요청
   - FCM 토큰이 Firestore의 `fcm_tokens` 컬렉션에 저장됨
   - `smoking_detection` 주제 자동 구독

3. **알림 수신 시나리오**
   - **포그라운드**: 앱 사용 중 알림 표시
   - **백그라운드**: 시스템 알림으로 표시
   - **앱 종료**: 시스템 알림으로 표시

### Python 백엔드 설정

1. **필요한 패키지 설치**
   ```bash
   pip install firebase-admin
   ```

2. **Firebase 서비스 계정 키 준비**
   - `firebase-service-account.json` 파일 필요
   - Firebase Console → 프로젝트 설정 → 서비스 계정 → 새 비공개 키 생성

3. **기본 사용법**
   ```python
   from fcm_notification_sender import FCMNotificationSender

   # 클라이언트 초기화
   sender = FCMNotificationSender('firebase-service-account.json')

   # 흡연 감지 알림 전송
   sender.send_smoking_detection_notification(
       camera_id=1,
       location='본관 1층 입구',
       event_id='evt_12345'
   )
   ```

4. **라즈베리파이 통합 사용**
   ```python
   from raspberry_pi_client import SmokingDetectionClient

   client = SmokingDetectionClient('firebase-service-account.json')

   # 감지 결과 전송 (자동으로 푸시 알림도 전송됨)
   client.send_detection(
       camera_id=1,
       location='본관 1층 입구',
       detected_objects=['person', 'smoking'],
       confidence=0.95,
       image=frame,  # OpenCV 이미지
       send_notification=True  # 푸시 알림 전송
   )
   ```

## 테스트 방법

### 1. 간단한 테스트

```bash
# 테스트 스크립트 실행
python test_push_notification.py
```

**테스트 시나리오:**
- 주제 기반 알림 전송
- 흡연 감지 시뮬레이션
- 모든 기기로 알림 전송

### 2. 수동 테스트 (Python 코드)

```python
from fcm_notification_sender import FCMNotificationSender

sender = FCMNotificationSender('firebase-service-account.json')

# 방법 1: 주제로 전송 (권장)
sender.send_to_topic(
    topic='smoking_detection',
    title='🚬 흡연 감지!',
    body='본관 1층에서 흡연이 감지되었습니다.',
    data={'eventId': 'test_001'}
)

# 방법 2: 모든 기기로 전송
sender.send_to_all_tokens(
    title='테스트 알림',
    body='이것은 테스트입니다.'
)

# 방법 3: 특정 토큰으로 전송
sender.send_to_token(
    token='YOUR_FCM_TOKEN_HERE',
    title='개별 알림',
    body='특정 기기에만 전송됩니다.'
)
```

### 3. Firebase Console에서 테스트

1. Firebase Console → Cloud Messaging 메뉴
2. "Send test message" 클릭
3. 주제: `smoking_detection` 입력
4. 메시지 작성 후 전송

## 알림 데이터 구조

### 기본 알림 형식
```json
{
  "notification": {
    "title": "🚬 흡연 감지!",
    "body": "본관 1층 입구에서 흡연이 감지되었습니다."
  },
  "data": {
    "type": "smoking_detection",
    "cameraId": "1",
    "location": "본관 1층 입구",
    "eventId": "evt_12345",
    "timestamp": "2025-01-15T10:30:00",
    "imageUrl": "https://storage.googleapis.com/..."
  }
}
```

## Firestore 데이터 구조

### fcm_tokens 컬렉션
```
fcm_tokens/
  └── {token}/
      ├── token: string
      ├── platform: string
      ├── createdAt: timestamp
      └── updatedAt: timestamp
```

### events 컬렉션 (기존 + 알림 연동)
```
events/
  └── {eventId}/
      ├── camera_id: number
      ├── location: string
      ├── detected_objects: array
      ├── confidence: number
      ├── image_url: string
      ├── timestamp: timestamp
      ├── status: string
      └── notified: boolean  # 알림 전송 여부 (선택사항)
```

## 문제 해결

### 알림이 오지 않을 때

1. **앱 권한 확인**
   - 설정 → 앱 → 알림 권한 활성화 확인

2. **FCM 토큰 확인**
   ```dart
   NotificationService().printCurrentToken();
   ```

3. **Firestore에 토큰 저장 확인**
   - Firebase Console → Firestore → `fcm_tokens` 컬렉션 확인

4. **Python 에러 확인**
   ```python
   # 에러 메시지를 자세히 확인
   sender.send_to_topic(...)
   # 콘솔에 에러 메시지 출력됨
   ```

### 일반적인 문제

| 문제 | 해결 방법 |
|------|----------|
| "Permission denied" | firebase-service-account.json 파일 경로 확인 |
| "Topic not found" | 앱에서 해당 주제 구독 확인 |
| "Token not valid" | 앱 재설치 후 새 토큰 등록 |
| "Connection error" | 인터넷 연결 확인 |

## 고급 기능

### 알림 우선순위 설정

```python
# 높은 우선순위 (즉시 전달)
android=messaging.AndroidConfig(
    priority='high',
    notification=messaging.AndroidNotification(
        sound='default',
        priority='max'
    )
)
```

### 사용자 정의 알림 음

```python
android=messaging.AndroidConfig(
    notification=messaging.AndroidNotification(
        sound='custom_sound.mp3'  # res/raw/ 폴더에 추가
    )
)
```

### 알림 그룹화

```python
android=messaging.AndroidConfig(
    notification=messaging.AndroidNotification(
        tag='smoking_detection',  # 같은 tag는 하나로 그룹화
    )
)
```

## 성능 최적화

### 주제(Topic) vs 개별 토큰

| 방식 | 장점 | 단점 | 사용 시나리오 |
|------|------|------|---------------|
| **주제 구독** | - 한 번에 여러 기기 전송<br>- 서버 부하 적음 | - 개별 제어 불가 | 전체 알림 |
| **개별 토큰** | - 개별 기기 제어 가능<br>- 사용자 맞춤 알림 | - 토큰 관리 필요<br>- 서버 부하 증가 | VIP 알림, 개인 설정 |

**권장사항:** 기본적으로 주제 구독 사용, 필요 시 개별 토큰 추가

### 배치 전송

여러 토큰에 동시 전송 시:
```python
# 최대 500개 토큰까지 한 번에 전송 가능
messaging.send_multicast(MulticastMessage(...))
```

## 보안 고려사항

1. **서비스 계정 키 보호**
   - `firebase-service-account.json` 파일을 Git에 커밋하지 않기
   - `.gitignore`에 추가 확인

2. **토큰 관리**
   - 만료된 토큰 정기적으로 삭제
   - Firestore 보안 규칙 설정

3. **데이터 유효성 검사**
   - 알림 데이터 검증 후 전송
   - SQL Injection 등 방지

## 참고 자료

- [Firebase Cloud Messaging 공식 문서](https://firebase.google.com/docs/cloud-messaging)
- [Flutter firebase_messaging 패키지](https://pub.dev/packages/firebase_messaging)
- [Python firebase-admin SDK](https://firebase.google.com/docs/admin/setup)

## 다음 단계

- [ ] 알림 설정 UI 추가 (설정 화면에서 on/off)
- [ ] 알림 히스토리 저장 및 조회
- [ ] 사용자별 알림 필터링 (특정 카메라만)
- [ ] 알림 통계 대시보드
