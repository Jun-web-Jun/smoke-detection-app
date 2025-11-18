# 🚀 라즈베리파이 빠른 시작 가이드

기존 코드를 사용한 라즈베리파이 흡연 감지 시스템 설정

---

## 📦 필요한 파일 전송

PC에서 라즈베리파이로 파일 전송:

```bash
# 라즈베리파이 IP 주소 확인 (라즈베리파이에서 실행)
hostname -I

# PC에서 파일 전송
scp smoking_detector.py pi@<라즈베리파이-IP>:~/
scp raspberry_pi_client.py pi@<라즈베리파이-IP>:~/
scp raspberry_pi_integrated_system.py pi@<라즈베리파이-IP>:~/
scp firebase-service-account.json pi@<라즈베리파이-IP>:~/
```

---

## 🔧 라즈베리파이 설정

### 1. 라즈베리파이 접속
```bash
ssh pi@<라즈베리파이-IP>
```

### 2. 필요한 패키지 설치
```bash
# 시스템 업데이트
sudo apt update
sudo apt upgrade -y

# Python 패키지 설치
pip3 install ultralytics opencv-python firebase-admin

# 의존성 설치
sudo apt install -y python3-opencv libatlas-base-dev

# YOLOv8 모델 다운로드
python3 -c "from ultralytics import YOLO; YOLO('yolov8n.pt')"
```

---

## 🎬 시스템 실행

### 기본 실행 (추천)
```bash
python3 raspberry_pi_integrated_system.py
```

### 옵션 포함 실행
```bash
# 화면에 감지 결과 표시 (모니터 연결 시)
python3 raspberry_pi_integrated_system.py --display

# 카메라 ID 지정
python3 raspberry_pi_integrated_system.py --camera-id 2

# 위치 지정
python3 raspberry_pi_integrated_system.py --location "주차장"

# 전체 옵션
python3 raspberry_pi_integrated_system.py \
  --camera-id 1 \
  --device-id raspberry-pi-001 \
  --location "본관 1층 입구" \
  --display
```

---

## ✅ 작동 확인

### 1. 터미널 출력 확인
```
============================================================
통합 흡연 감지 시스템 초기화 중...
============================================================

[1/3] YOLO 감지기 초기화...
✓ YOLO 감지기 준비 완료

[2/3] Firebase 클라이언트 초기화...
✓ Firebase 연결 완료

[3/3] 장치 등록 중... (raspberry-pi-001)
✓ 장치 등록 완료

============================================================
✅ 시스템 초기화 완료!
============================================================
카메라 ID: 1
장치 ID: raspberry-pi-001
위치: 본관 1층 입구
============================================================

🎥 감지 시스템 시작...
Press Ctrl+C to stop
```

### 2. 사람 감지 시
```
============================================================
🚨 흡연 감지!
============================================================
시간: 2025-11-06T18:30:45.123456
위치: 본관 1층 입구
감지된 사람 수: 1
신뢰도: 85.3%

📤 Firebase에 전송 중...
✅ 감지 이벤트 전송 성공: abc123def456
   위치: 본관 1층 입구
   감지 객체: ['person']
   신뢰도: 0.85
✅ 전송 성공! Event ID: abc123def456
📱 Flutter 앱에서 확인하세요!
============================================================
```

### 3. Flutter 앱에서 확인
- Android 앱 또는 웹 앱의 "이벤트" 탭에서 실시간으로 확인!

---

## 🎯 테스트 방법

### 1. 카메라 앞에서 손 흔들기
- 사람이 감지되면 자동으로 Firebase에 전송됩니다

### 2. Flutter 앱 확인
- "이벤트" 탭에서 새로운 감지 이벤트 확인
- 이미지도 함께 업로드됩니다!

---

## 🔄 백그라운드 실행 (선택사항)

### systemd 서비스로 자동 시작

1. 서비스 파일 생성:
```bash
sudo nano /etc/systemd/system/smoking-detection.service
```

2. 내용 입력:
```ini
[Unit]
Description=Smoking Detection System
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi
ExecStart=/usr/bin/python3 /home/pi/raspberry_pi_integrated_system.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

3. 서비스 활성화:
```bash
sudo systemctl daemon-reload
sudo systemctl enable smoking-detection
sudo systemctl start smoking-detection
```

4. 상태 확인:
```bash
sudo systemctl status smoking-detection
```

5. 로그 확인:
```bash
sudo journalctl -u smoking-detection -f
```

---

## 🛠️ 문제 해결

### 카메라가 열리지 않을 때
```bash
# 카메라 장치 확인
ls /dev/video*

# 카메라 권한 확인
sudo usermod -a -G video pi

# 재부팅
sudo reboot
```

### YOLO 모델 다운로드 실패
```bash
# 수동 다운로드
wget https://github.com/ultralytics/assets/releases/download/v0.0.0/yolov8n.pt
```

### Firebase 연결 실패
- `firebase-service-account.json` 파일이 있는지 확인
- 파일 경로가 올바른지 확인
- 인터넷 연결 확인

---

## 📊 성능 최적화

### Raspberry Pi 4 권장 설정
```python
# raspberry_pi_integrated_system.py 수정
self.detection_cooldown = 3  # 5초 → 3초 (더 빠른 감지)
```

### Raspberry Pi 3/Zero
```python
# 더 작은 모델 사용
self.detector = SmokingDetector(
    model_path='yolov8n.pt',  # Nano 모델 (가장 빠름)
    confidence_threshold=0.6   # 신뢰도 약간 높이기
)
```

---

## 🎉 발표 준비 체크리스트

- [ ] 라즈베리파이에 시스템 설치 완료
- [ ] 카메라 테스트 성공
- [ ] Firebase 연동 확인
- [ ] Flutter 앱에서 실시간 감지 확인
- [ ] 백업 전원 준비 (보조배터리)
- [ ] 데모 시나리오 작성
- [ ] 발표 자료 준비

---

## 💡 발표 팁

**데모 시나리오:**
1. 라즈베리파이 시스템 실행 (터미널 화면 프로젝터에 표시)
2. Flutter 앱 실행 (Android 또는 웹)
3. 카메라 앞에서 손 흔들기
4. 실시간으로 감지되는 것 보여주기
5. 앱에서 이벤트 확인

**주의사항:**
- WiFi 네트워크 안정성 확인
- 발표장 네트워크에 미리 연결 테스트
- 모바일 핫스팟 백업 준비

---

## 📞 도움말

문제 발생 시:
1. 에러 메시지 확인
2. 로그 확인: `sudo journalctl -u smoking-detection -f`
3. 재시작: `sudo systemctl restart smoking-detection`
4. 수동 테스트: `python3 raspberry_pi_integrated_system.py`

---

**축하합니다! 🎉**
라즈베리파이 흡연 감지 시스템이 준비되었습니다!
