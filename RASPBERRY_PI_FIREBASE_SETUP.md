# 라즈베리파이 Firebase 연동 가이드

## 📌 개요

이 가이드는 라즈베리파이에서 담배 감지 시 Firebase에 이미지를 업로드하고, Flutter 앱의 적발 이력에 사진이 표시되도록 설정하는 방법을 설명합니다.

---

## 🔧 필요한 패키지 설치

라즈베리파이에서 다음 명령어를 실행하세요:

```bash
pip install firebase-admin
```

---

## 🔑 Firebase 서비스 계정 키 다운로드

### 1. Firebase Console 접속
https://console.firebase.google.com/

### 2. 프로젝트 선택
`smoke-detection-7ee0b` 프로젝트 선택

### 3. 프로젝트 설정 이동
- 좌측 상단 톱니바퀴 아이콘 클릭
- "프로젝트 설정" 선택

### 4. 서비스 계정 탭
- 상단 탭에서 "서비스 계정" 클릭
- "새 비공개 키 생성" 버튼 클릭
- JSON 파일 다운로드

### 5. 파일 이름 변경
다운로드한 JSON 파일을 `serviceAccountKey.json`으로 이름 변경

### 6. 라즈베리파이로 전송
```bash
# 로컬 PC에서 라즈베리파이로 파일 전송
scp serviceAccountKey.json pi@192.168.0.230:/home/pi/
```

또는 USB, 이메일 등을 통해 파일을 라즈베리파이로 복사하세요.

---

## 📁 파일 배치

라즈베리파이의 작업 디렉토리에 다음 파일들이 있어야 합니다:

```
/home/pi/
├── raspberry_pi_firebase_detection.py  (새로 만든 파일)
├── serviceAccountKey.json              (Firebase 키)
├── final_detection416.onnx            (ONNX 모델)
├── person.mp3                         (안내 사운드)
├── smoke.mp3                          (경고 사운드)
```

---

## ▶️ 실행 방법

### 1. 라즈베리파이에서 새 스크립트 실행

```bash
python3 raspberry_pi_firebase_detection.py
```

### 2. 정상 실행 확인

다음과 같은 메시지가 표시되어야 합니다:

```
✅ Firebase Admin SDK initialized successfully
✅ ONNX Model loaded successfully: final_detection416.onnx
✅ Camera ready
✅ Guide sound loaded: person.mp3
✅ Warning sound loaded: smoke.mp3
```

### 3. 담배 감지 시

담배가 감지되면 자동으로:
1. 📸 현재 프레임 캡처
2. ☁️ Firebase Storage에 이미지 업로드
3. 📝 Firestore에 이벤트 생성
4. 📱 Flutter 앱의 "적발 이력" 탭에 자동 표시

---

## 📱 Flutter 앱에서 확인

### 1. 앱 실행
`smoke_detection_v3.0.0_COMPLETE.apk` 설치 및 실행

### 2. 적발 이력 탭 이동
하단 네비게이션에서 "적발 이력" 탭 선택

### 3. 이미지 확인
- 담배 감지 이벤트에 실제 캡처된 사진이 표시됩니다
- 느낌표(❗) 대신 실제 이미지가 보입니다
- 클릭하면 상세 화면으로 이동

---

## 🔍 문제 해결

### Firebase 초기화 실패

```
❌ Firebase initialization failed
```

**해결 방법:**
1. `serviceAccountKey.json` 파일이 스크립트와 같은 디렉토리에 있는지 확인
2. 파일 이름이 정확히 `serviceAccountKey.json`인지 확인
3. 파일 권한 확인: `chmod 644 serviceAccountKey.json`

### 이미지 업로드 실패

```
❌ Failed to upload image to Firebase
```

**해결 방법:**
1. 라즈베리파이가 인터넷에 연결되어 있는지 확인
2. Firebase Storage 규칙 확인 (Firebase Console > Storage > 규칙)
3. Storage 버킷 이름 확인: `smoke-detection-7ee0b.appspot.com`

### 앱에서 이미지가 안 보임

**해결 방법:**
1. 앱을 완전히 종료 후 재시작
2. 적발 이력 탭에서 아래로 당겨서 새로고침
3. Firebase Console에서 이벤트가 정상적으로 생성되었는지 확인
   - Firestore > `detection_events` 컬렉션 확인
   - Storage > `detections/` 폴더 확인

---

## 📊 Firebase Storage 규칙 설정

Firebase Console > Storage > 규칙에서 다음과 같이 설정되어 있어야 합니다:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;

      // 라즈베리파이 업로드 허용 (공개 읽기)
      match /detections/{fileName} {
        allow read: if true;
        allow write: if true;
      }
    }
  }
}
```

---

## 🎯 주요 기능

### 1. 자동 이미지 업로드
- 담배 감지 시 자동으로 프레임 캡처
- Firebase Storage에 업로드
- 고유한 파일명으로 저장: `smoking_snapshot_20231119_153045.jpg`

### 2. Firestore 이벤트 생성
```json
{
  "id": "uuid-v4",
  "timestamp": "2023-11-19T15:30:45.123Z",
  "label": "cigarette",
  "confidence": 0.87,
  "imageUrl": "https://storage.googleapis.com/...",
  "thumbnailUrl": "https://storage.googleapis.com/...",
  "location": "라즈베리파이 카메라 1",
  "metadata": {
    "source": "raspberry_pi",
    "model": "yolov8_onnx",
    "cameraId": "camera_1"
  }
}
```

### 3. 앱 자동 동기화
- Firestore 실시간 리스너를 통해 자동 업데이트
- 새 이벤트 발생 시 앱에 즉시 표시
- 캐시된 이미지로 빠른 로딩

---

## 🔄 기존 Google Drive 코드와 비교

| 항목 | Google Drive (기존) | Firebase (신규) |
|------|-------------------|----------------|
| **파일** | `raspberry_pi_onnx_detection.py` | `raspberry_pi_firebase_detection.py` |
| **인증** | OAuth2 + token.pickle | 서비스 계정 키 |
| **저장소** | Google Drive | Firebase Storage |
| **데이터베이스** | 없음 | Firestore |
| **앱 연동** | 수동 | 자동 (실시간) |
| **이미지 표시** | 불가능 | 가능 ✅ |

---

## 💡 팁

### 자동 시작 설정 (systemd)

라즈베리파이 부팅 시 자동으로 실행되도록 설정:

1. 서비스 파일 생성:
```bash
sudo nano /etc/systemd/system/firebase-detection.service
```

2. 다음 내용 입력:
```ini
[Unit]
Description=Firebase Smoke Detection
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi
ExecStart=/usr/bin/python3 /home/pi/raspberry_pi_firebase_detection.py
Restart=always

[Install]
WantedBy=multi-user.target
```

3. 서비스 활성화:
```bash
sudo systemctl enable firebase-detection.service
sudo systemctl start firebase-detection.service
```

4. 상태 확인:
```bash
sudo systemctl status firebase-detection.service
```

---

## 📞 지원

문제가 발생하면 다음을 확인하세요:
1. 라즈베리파이 콘솔 출력 메시지
2. Firebase Console > Storage > 파일 업로드 여부
3. Firebase Console > Firestore > 이벤트 생성 여부
4. Flutter 앱 로그

---

**작성일**: 2024-11-19
**버전**: 3.0.0
