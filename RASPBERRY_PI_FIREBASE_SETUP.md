# 라즈베리파이 Google Drive 이미지 연동 가이드

## 📌 개요

이 가이드는 라즈베리파이에서 담배 감지 시 Google Drive에 이미지를 업로드하고, Flutter 앱의 적발 이력에 사진이 표시되도록 설정하는 방법을 설명합니다.

**✅ Firebase Storage 대신 Google Drive 사용 (무료!)**

---

## 🔧 필요한 패키지 설치

라즈베리파이의 `asd` 가상환경에서 다음 명령어를 실행하세요:

```bash
# 가상환경 활성화
source ~/asd/bin/activate

# 필요한 패키지 설치
pip install firebase-admin google-auth-httplib2 google-auth-oauthlib google-api-python-client
```

---

## 🔑 필요한 인증 파일

### 1. Firebase 서비스 계정 키 (firebase-service-account.json)

이미 설정되어 있어야 합니다. 확인:
```bash
ls ~/firebase-service-account.json
```

없다면:
1. Firebase Console 접속: https://console.firebase.google.com/
2. 프로젝트 설정 > 서비스 계정
3. "새 비공개 키 생성" 클릭
4. JSON 파일 다운로드 후 `firebase-service-account.json`으로 이름 변경
5. 라즈베리파이의 홈 디렉토리로 전송

### 2. Google Drive 인증 (credentials.json & token.pickle)

이미 설정되어 있어야 합니다. 확인:
```bash
ls ~/credentials.json
ls ~/token.pickle
```

없다면 Google Drive API 설정이 필요합니다 (기존 설정 유지).

---

## 📁 파일 배치

라즈베리파이의 작업 디렉토리에 다음 파일들이 있어야 합니다:

```
/home/pi/
├── last1.py                           (최신 감지 스크립트)
├── firebase-service-account.json      (Firebase 키)
├── credentials.json                   (Google Drive API 키)
├── token.pickle                       (Google Drive 인증 토큰)
├── final_detection416.onnx           (ONNX 모델)
├── person.mp3                        (안내 사운드)
├── smoke.mp3                         (경고 사운드)
```

---

## ▶️ 실행 방법

### 1. GitHub에서 최신 코드 다운로드

```bash
cd ~
git pull origin main
```

### 2. 가상환경 활성화 및 실행

```bash
# 가상환경 활성화
source ~/asd/bin/activate

# 스크립트 실행
python3 last1.py
```

### 3. 정상 실행 확인

다음과 같은 메시지가 표시되어야 합니다:

```
[INFO] Firebase 연결 완료
[INFO] Google Drive 연결 완료
✅ Drive Folder 'Smoking_Snapshots' already exists
✅ Drive Folder 'Smoking_Videos' already exists
[INFO] ONNX 모델 로드 완료
[INFO] 카메라 준비 완료
```

### 4. 담배 감지 시

담배가 감지되면 자동으로:
1. 📸 현재 프레임 캡처
2. ☁️ **Google Drive에 이미지 업로드** (무료!)
3. 📝 Firestore에 이벤트 생성 (이미지 URL 포함)
4. 📱 Flutter 앱의 "적발 이력" 탭에 실제 사진 자동 표시

---

## 📱 Flutter 앱에서 확인

### 1. 앱 실행
최신 APK 설치 및 실행

### 2. 적발 이력 탭 이동
하단 네비게이션에서 "적발 이력" 탭 선택

### 3. 이미지 확인
- ✅ 담배 감지 이벤트에 **실제 캡처된 사진**이 표시됩니다
- ✅ Google Drive에서 직접 이미지를 로드합니다
- ✅ 클릭하면 상세 화면에서 전체 크기 이미지 확인 가능
- ✅ 느낌표(❗) 아이콘 대신 실제 사진이 보입니다!

---

## 🔍 문제 해결

### Google Drive 초기화 실패

```
[ERROR] Google Drive 초기화 실패
```

**해결 방법:**
1. `credentials.json` 파일이 있는지 확인: `ls ~/credentials.json`
2. `token.pickle` 파일이 있는지 확인: `ls ~/token.pickle`
3. 필요한 패키지 설치: `pip install google-auth-httplib2 google-auth-oauthlib google-api-python-client`
4. Google Drive API가 활성화되어 있는지 확인

### 이미지 업로드 실패

```
[ERROR] Google Drive 이미지 업로드 실패
```

**해결 방법:**
1. 라즈베리파이가 인터넷에 연결되어 있는지 확인
2. Google Drive 폴더가 생성되었는지 확인 (로그에서 'Smoking_Snapshots' 폴더 ID 확인)
3. token.pickle이 유효한지 확인 (만료되면 재인증 필요)

### 앱에서 이미지가 안 보임

**해결 방법:**
1. 앱을 완전히 종료 후 재시작
2. 적발 이력 탭에서 아래로 당겨서 새로고침
3. Firebase Console에서 이벤트 확인:
   - Firestore > `detection_events` 컬렉션
   - `imageUrl` 필드가 `https://drive.google.com/uc?export=view&id=...` 형식인지 확인
4. Google Drive에서 이미지 확인:
   - 'Smoking_Snapshots' 폴더에 이미지가 업로드되었는지 확인
   - 이미지가 '공개' 권한으로 설정되었는지 확인

### 권한 오류

**해결 방법:**
1. Google Drive에서 파일이 '누구나' 권한으로 설정되어 있는지 확인
2. 스크립트가 파일을 공개로 설정하도록 되어 있음 (자동 처리)

---

## 🎯 주요 기능

### 1. Google Drive 자동 이미지 업로드
- 담배 감지 시 자동으로 프레임 캡처
- **Google Drive에 업로드** (무료!)
- 'Smoking_Snapshots' 폴더에 저장
- 고유한 파일명: `detection_20231119_153045_uuid.jpg`
- 자동 공개 권한 설정

### 2. Firestore 이벤트 생성
```json
{
  "id": "uuid-v4",
  "timestamp": "2023-11-19T15:30:45.123Z",
  "label": "cigarette",
  "confidence": 0.87,
  "imageUrl": "https://drive.google.com/uc?export=view&id=...",
  "thumbnailUrl": "https://drive.google.com/uc?export=view&id=...",
  "location": "N1동(본부관) 1층 입구",
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
- CachedNetworkImage로 빠른 로딩
- Google Drive URL에서 직접 이미지 로드

---

## 🔄 시스템 아키텍처

| 항목 | 설명 |
|------|------|
| **파일** | `last1.py` (최신 통합 버전) |
| **이미지 저장** | Google Drive (무료!) |
| **데이터베이스** | Firebase Firestore |
| **실시간 스트리밍** | Flask MJPEG (포트 5000) |
| **푸시 알림** | Firebase Cloud Messaging |
| **앱 연동** | 실시간 자동 동기화 |
| **이미지 표시** | ✅ Google Drive 공개 URL |

---

## 💡 팁

### 자동 시작 설정 (systemd)

라즈베리파이 부팅 시 자동으로 실행되도록 설정:

1. 서비스 파일 생성:
```bash
sudo nano /etc/systemd/system/smoke-detection.service
```

2. 다음 내용 입력:
```ini
[Unit]
Description=Smoke Detection with Google Drive
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi
ExecStart=/home/pi/asd/bin/python3 /home/pi/last1.py
Restart=always
Environment="DISPLAY=:0"

[Install]
WantedBy=multi-user.target
```

3. 서비스 활성화:
```bash
sudo systemctl enable smoke-detection.service
sudo systemctl start smoke-detection.service
```

4. 상태 확인:
```bash
sudo systemctl status smoke-detection.service
```

5. 로그 확인:
```bash
sudo journalctl -u smoke-detection.service -f
```

---

## 📞 지원

문제가 발생하면 다음을 확인하세요:
1. 라즈베리파이 콘솔 출력 메시지
2. Google Drive > 'Smoking_Snapshots' 폴더 > 이미지 업로드 여부
3. Firebase Console > Firestore > `detection_events` 컬렉션 > 이벤트 생성 여부
4. Firestore 이벤트의 `imageUrl` 필드 확인
5. Flutter 앱 로그

---

## ✅ 완료 체크리스트

라즈베리파이에서 실행하기 전에:
- [ ] `asd` 가상환경이 활성화되어 있음
- [ ] `last1.py` 파일이 최신 버전 (GitHub에서 pull)
- [ ] `firebase-service-account.json` 파일 존재
- [ ] `credentials.json` 파일 존재
- [ ] `token.pickle` 파일 존재
- [ ] 필요한 패키지 모두 설치됨
- [ ] 인터넷 연결 확인
- [ ] Google Drive 'Smoking_Snapshots' 폴더 생성됨

---

**작성일**: 2025-11-19
**버전**: 4.0.0 (Google Drive 통합)
