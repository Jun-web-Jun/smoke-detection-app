# 🎥 Raspberry Pi 카메라 설정 가이드

발표 준비를 위한 라즈베리파이 카메라 연동 가이드입니다.

---

## 📋 준비물

- Raspberry Pi (3B+, 4, Zero 등)
- Raspberry Pi Camera Module 또는 USB 웹캠
- microSD 카드 (Raspberry Pi OS 설치됨)
- 전원 어댑터
- 네트워크 연결 (WiFi 또는 이더넷)

---

## 🔧 1단계: Raspberry Pi 기본 설정

### 1.1 Raspberry Pi 접속

**방법 1: SSH 사용 (추천)**
```bash
ssh pi@<라즈베리파이-IP>
# 기본 비밀번호: raspberry
```

**방법 2: 모니터/키보드 직접 연결**

### 1.2 시스템 업데이트
```bash
sudo apt update
sudo apt upgrade -y
```

### 1.3 카메라 활성화 (Raspberry Pi Camera Module 사용 시)
```bash
sudo raspi-config
```
- `3 Interface Options` 선택
- `I1 Legacy Camera` 또는 `I1 Camera` 활성화
- 재부팅: `sudo reboot`

---

## 📦 2단계: 필요한 패키지 설치

### 2.1 Python 패키지 설치
```bash
# Flask (웹 서버)
pip3 install flask

# OpenCV (카메라 처리)
pip3 install opencv-python

# Picamera2 (Raspberry Pi Camera Module용)
sudo apt install -y python3-picamera2

# Firebase Admin (선택사항 - Firebase 연동 시)
pip3 install firebase-admin
```

### 2.2 의존성 패키지
```bash
sudo apt install -y python3-opencv
sudo apt install -y libatlas-base-dev
sudo apt install -y libhdf5-dev
```

---

## 🧪 3단계: 카메라 테스트

### 3.1 테스트 파일 전송

PC에서 라즈베리파이로 파일 전송:
```bash
scp raspberry_pi_camera_test.py pi@<라즈베리파이-IP>:~/
scp raspberry_pi_stream_server.py pi@<라즈베리파이-IP>:~/
```

### 3.2 카메라 테스트 실행
```bash
cd ~
python3 raspberry_pi_camera_test.py
```

**예상 결과:**
```
=== Testing picamera2 (Raspberry Pi Camera Module) ===
✓ Picamera2 initialized successfully!
✓ Test photo saved as 'test_photo.jpg'
✓ Picamera2 test completed successfully!

=== Testing OpenCV (USB Webcam) ===
✓ OpenCV camera initialized successfully!
  Resolution: 640x480
✓ Test image saved as 'test_webcam.jpg'
✓ OpenCV test completed successfully!
```

---

## 🚀 4단계: 카메라 스트리밍 서버 실행

### 4.1 서버 시작
```bash
python3 raspberry_pi_stream_server.py
```

**서버 시작 메시지:**
```
Raspberry Pi Camera Streaming Server
✓ Camera initialized successfully
✓ Server is ready!

Access the camera stream at:
  http://<raspberry-pi-ip>:5000
```

### 4.2 브라우저에서 확인

PC 브라우저에서 접속:
```
http://<라즈베리파이-IP>:5000
```

실시간 카메라 영상이 보이면 성공! 🎉

---

## 📱 5단계: Flutter 앱에서 스트림 확인

### 5.1 라즈베리파이 IP 주소 확인
```bash
hostname -I
```

### 5.2 Flutter 앱 실행

**웹에서 테스트:**
1. Chrome에서 Flutter 앱 실행
2. "라이브" 탭 클릭
3. 카메라 스트림이 표시되는지 확인

**Android 앱에서 테스트:**
1. 새로운 APK 설치
2. 테스트 계정으로 로그인 (1111/1111)
3. "라이브" 탭에서 카메라 확인

---

## 🔍 문제 해결

### 카메라가 인식되지 않을 때

**1. 카메라 연결 확인**
```bash
ls /dev/video*
# /dev/video0 이 있어야 함
```

**2. Raspberry Pi Camera Module**
```bash
vcgencmd get_camera
# supported=1 detected=1 이어야 함
```

**3. USB 웹캠**
```bash
v4l2-ctl --list-devices
```

### 스트리밍이 느릴 때

**해상도/FPS 조정** (`raspberry_pi_stream_server.py` 수정):
```python
FRAME_WIDTH = 320   # 640에서 320으로 줄이기
FRAME_HEIGHT = 240  # 480에서 240으로 줄이기
FPS = 15            # 30에서 15로 줄이기
```

### 포트 충돌

다른 포트 사용:
```python
app.run(host='0.0.0.0', port=8080)  # 5000 → 8080
```

---

## 🎯 다음 단계

카메라 스트리밍이 성공하면:

1. ✅ **카메라 테스트 완료**
2. ⏭️ **YOLO 통합** (흡연 감지)
3. ⏭️ **Firebase 연동** (실시간 알림)
4. ⏭️ **발표 준비**

---

## 📞 도움이 필요하면

문제가 발생하면:
1. 에러 메시지 확인
2. 로그 확인: `python3 raspberry_pi_stream_server.py`
3. 카메라 연결 상태 확인
4. 네트워크 연결 확인

---

## 📝 참고 사항

**성능 최적화:**
- Raspberry Pi 4 권장 (더 빠른 처리)
- 유선 네트워크 연결 권장 (WiFi보다 안정적)
- 불필요한 프로세스 종료

**보안:**
- 프로덕션 환경에서는 HTTPS 사용
- 인증 추가 (현재는 테스트용)

**배터리:**
- 발표 시 전원 어댑터 필수
- 보조배터리도 준비 (비상용)
