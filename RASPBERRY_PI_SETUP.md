# 🔥 라즈베리파이 흡연 감지 시스템 설정 가이드

**최종 업데이트된 시스템 실행 가이드**

이 가이드는 최신 코드(Firebase 이미지 업로드, 푸시 알림, 라이브 스트림 포함)를 라즈베리파이에서 실행하는 방법을 설명합니다.

---

## 📋 준비물

- Raspberry Pi (3B+, 4 권장)
- Raspberry Pi Camera Module
- microSD 카드 (Raspberry Pi OS 설치됨)
- 전원 어댑터
- 네트워크 연결 (WiFi 또는 이더넷)
- 필요한 파일들:
  - `final_detection640.onnx` (YOLO 모델)
  - `person.mp3` (사람 감지 안내 음성)
  - `smoke.mp3` (흡연 감지 경고 음성)
  - `firebase-service-account.json` (Firebase 인증 키)

---

## ⚡ 빠른 시작 (Quick Start)

```bash
# 1. 코드 업데이트
cd ~/smoke-detection-app
git pull origin main

# 2. 감지 프로그램 실행
python3 detection_simple.py

# 3. (새 터미널) 스트림 서버 실행
python3 camera_stream_server.py
```

---

## 🔧 1단계: 최신 코드 업데이트

### 1.1 Git Pull
```bash
cd ~/smoke-detection-app
git pull origin main
```

**업데이트된 주요 기능:**
- ✅ Firebase Storage 이미지 업로드
- ✅ FCM 푸시 알림 자동 전송
- ✅ MJPEG 라이브 스트리밍
- ✅ Firestore 실시간 동기화

---

## 📦 2단계: 필요한 패키지 설치

### 2.1 Python 패키지 설치
```bash
# 필수 패키지
pip3 install flask picamera2 opencv-python firebase-admin onnxruntime pygame numpy
```

### 2.2 시스템 패키지 (필요시)
```bash
sudo apt update
sudo apt install -y python3-opencv libatlas-base-dev
```

---

## 🔐 3단계: Firebase 서비스 계정 키 설정

### 3.1 Firebase Console에서 키 발급

1. Firebase Console 접속: https://console.firebase.google.com
2. 프로젝트 선택: `smoke-detection-system-d85b6`
3. ⚙️ 프로젝트 설정 → 서비스 계정 탭
4. **새 비공개 키 생성** 버튼 클릭
5. JSON 파일 다운로드

### 3.2 라즈베리파이로 파일 전송

**Windows에서:**
```bash
scp firebase-service-account.json pi@<라즈베리파이_IP>:~/smoke-detection-app/
```

**또는 직접 복사:**
- USB 드라이브 사용
- 파일을 `~/smoke-detection-app/` 폴더에 저장
- 파일명이 정확히 `firebase-service-account.json`인지 확인

### 3.3 권한 설정
```bash
cd ~/smoke-detection-app
chmod 600 firebase-service-account.json
```

---

## 🚀 4단계: 프로그램 실행

### 4.1 흡연 감지 메인 프로그램

```bash
cd ~/smoke-detection-app
python3 detection_simple.py
```

**실행 시 확인할 로그:**
```
[INFO] Firebase 초기화 중...
[INFO] Firebase 연결 완료
[INFO] ONNX 모델 로드 중: final_detection640.onnx
[INFO] ONNX 모델 로드 완료
[INFO] Picamera2 초기화 중...
[INFO] 카메라 준비 완료
[INFO] 감지 시작...
==================================================
```

**주요 기능:**
- 👤 Person, 🚬 Cigarette, 💨 Smoke, 🔥 Fire 실시간 감지
- 📸 감지 시 이미지 자동 캡처
- ☁️ Firebase Storage에 이미지 업로드
- 💾 Firestore에 이벤트 저장
- 📱 Flutter 앱으로 푸시 알림 전송 (흡연 감지 시)
- 🔊 음성 안내 (person.mp3, smoke.mp3)

### 4.2 카메라 스트림 서버 (별도 터미널)

**새 SSH 세션 열기:**
```bash
ssh pi@<라즈베리파이_IP>
cd ~/smoke-detection-app
python3 camera_stream_server.py
```

**실행 시 확인할 로그:**
```
[INFO] Picamera2 초기화 중...
[INFO] 카메라 준비 완료
[INFO] MJPEG 스트림 서버 시작...
[INFO] 스트림 URL: http://<라즈베리파이_IP>:5000/video_feed
 * Running on all addresses (0.0.0.0)
 * Running on http://127.0.0.1:5000
```

**주요 기능:**
- 📹 MJPEG 실시간 스트리밍 (15 FPS)
- 🌐 웹 브라우저 뷰어 (`http://<IP>:5000`)
- 📱 Flutter 앱 라이브 탭 연동
- ❤️ 헬스 체크 엔드포인트 (`/health`)

### 4.3 백그라운드 실행 (권장)

```bash
# 백그라운드로 실행
nohup python3 detection_simple.py > detection.log 2>&1 &
nohup python3 camera_stream_server.py > stream.log 2>&1 &

# 프로세스 확인
ps aux | grep python

# 로그 실시간 확인
tail -f detection.log
tail -f stream.log

# 프로세스 종료
pkill -f detection_simple.py
pkill -f camera_stream_server.py
```

---

## 📱 5단계: Flutter 앱에서 확인

### 5.1 라즈베리파이 IP 확인
```bash
hostname -I
# 예: 192.168.0.100
```

### 5.2 Flutter 앱 스트림 URL 설정

**앱 설정에서 스트림 URL 입력:**
```
http://192.168.0.100:5000/video_feed
```

### 5.3 기능 테스트

**1. 라이브 스트림 확인**
- "라이브" 탭 → 실시간 영상 확인

**2. 이벤트 목록 확인**
- "이벤트" 탭 → 감지된 이벤트 목록
- 이미지 클릭 → 상세 정보 확인

**3. 푸시 알림 테스트**
- 담배를 카메라 앞에 놓기
- Flutter 앱에 푸시 알림 수신 확인
- "🚨 흡연 감지 알림" 메시지 확인

---

## 🔍 트러블슈팅

### 1. Firebase 초기화 실패

**증상:**
```
[ERROR] Firebase 초기화 실패: ...
```

**해결 방법:**
```bash
# firebase-service-account.json 위치 확인
cd ~/smoke-detection-app
ls -la firebase-service-account.json

# JSON 파일 형식 확인 (문법 오류 체크)
cat firebase-service-account.json | python3 -m json.tool

# 파일 권한 확인
chmod 600 firebase-service-account.json
```

### 2. ONNX 모델 파일 없음

**증상:**
```
[ERROR] final_detection640.onnx 파일을 찾을 수 없습니다
```

**해결 방법:**
```bash
# 모델 파일 확인
ls -la final_detection640.onnx

# 없으면 PC에서 전송
# Windows에서:
scp final_detection640.onnx pi@<라즈베리파이_IP>:~/smoke-detection-app/
```

### 3. 카메라 에러

**증상:**
```
[ERROR] Picamera2 초기화 실패
```

**해결 방법:**
```bash
# 카메라 활성화
sudo raspi-config
# Interface Options → Camera → Enable

# 카메라 연결 확인
libcamera-hello

# 재부팅
sudo reboot
```

### 4. 음성 파일 없음

**증상:**
```
[ERROR] person.mp3 파일을 찾을 수 없습니다
```

**해결 방법:**
```bash
# PC에서 음성 파일 전송
scp person.mp3 smoke.mp3 pi@<라즈베리파이_IP>:~/smoke-detection-app/
```

### 5. 네트워크 연결 문제

**스트림이 Flutter 앱에 안 보일 때:**
```bash
# 라즈베리파이 IP 확인
hostname -I

# 방화벽 포트 열기
sudo ufw allow 5000/tcp
sudo ufw reload

# 핑 테스트
ping <스마트폰_IP>
```

### 6. 푸시 알림이 안 올 때

**체크리스트:**
1. Flutter 앱이 `smoking_detection` 토픽 구독 확인
2. Firebase Console → Cloud Messaging 확인
3. detection_simple.py 로그에서 FCM 전송 확인:
   ```
   [FCM] 푸시 알림 전송 완료: projects/...
   ```

---

## ⚙️ 자동 시작 설정 (선택사항)

부팅 시 자동으로 프로그램 실행:

### 감지 프로그램 서비스 생성
```bash
sudo nano /etc/systemd/system/smoke-detection.service
```

**파일 내용:**
```ini
[Unit]
Description=Smoke Detection Service
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/smoke-detection-app
ExecStart=/usr/bin/python3 /home/pi/smoke-detection-app/detection_simple.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### 스트림 서버 서비스 생성
```bash
sudo nano /etc/systemd/system/camera-stream.service
```

**파일 내용:**
```ini
[Unit]
Description=Camera Stream Service
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/smoke-detection-app
ExecStart=/usr/bin/python3 /home/pi/smoke-detection-app/camera_stream_server.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### 서비스 활성화
```bash
# 서비스 활성화
sudo systemctl enable smoke-detection.service
sudo systemctl enable camera-stream.service

# 서비스 시작
sudo systemctl start smoke-detection.service
sudo systemctl start camera-stream.service

# 상태 확인
sudo systemctl status smoke-detection.service
sudo systemctl status camera-stream.service

# 로그 확인
sudo journalctl -u smoke-detection.service -f
sudo journalctl -u camera-stream.service -f
```

---

## 📊 성능 최적화

### GPU 메모리 증가
```bash
sudo nano /boot/config.txt
# 다음 라인 추가:
# gpu_mem=256

sudo reboot
```

### FPS 조정

**detection_simple.py:**
```python
# 라인 360 수정
time.sleep(0.1)  # 0.05로 변경하면 더 빠름 (CPU 부하 증가)
```

**camera_stream_server.py:**
```python
# 라인 38 수정
time.sleep(0.066)  # ~15 FPS (0.033으로 변경하면 30 FPS)
```

---

## 📝 참고사항

### 시스템 요구사항
- Raspberry Pi 4 권장 (2GB RAM 이상)
- Raspberry Pi OS Bullseye 이상
- Python 3.9+
- 안정적인 네트워크 연결

### 네트워크 설정
- 유선 연결 권장 (WiFi보다 안정적)
- 같은 네트워크에 Flutter 앱 기기 연결
- 공유기 IP 고정 권장

### 보안
- Firebase 서비스 계정 키는 절대 공개 저장소에 올리지 말 것
- 프로덕션 환경에서는 HTTPS 사용 권장
- API Key는 Google Cloud Console에서 제한 설정

---

## 📞 문의

문제 발생 시 다음 정보 포함하여 문의:
1. 에러 메시지 전체 (`detection.log` 또는 `stream.log`)
2. 라즈베리파이 모델 및 OS 버전
3. Python 버전: `python3 --version`
4. 네트워크 구성 (IP 주소, 공유기 정보)
