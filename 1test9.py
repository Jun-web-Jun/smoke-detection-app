#!/usr/bin/env python3
"""
라즈베리파이 카메라 MJPEG 스트리밍 및 캡처 서버 (picamera2 - Debian 12 호환)
[캡처 기능 통합 및 디버깅 출력 추가]
"""
from flask import Flask, Response, jsonify, send_file, request
from flask_cors import CORS
from picamera2 import Picamera2
import cv2
import time
import threading # 프레임 동기화를 위해 추가
import os        # 파일 시스템 관리를 위해 추가
from datetime import datetime # 타임스탬프 생성을 위해 추가

app = Flask(__name__)
CORS(app)  # CORS 보안 허용

# =========================================================
# 캡처 및 프레임 관리 설정
# =========================================================

# 캡처 기능을 위한 프레임 저장소 (프레임 데이터를 저장)
last_frame = None
frame_lock = threading.Lock() # 프레임 접근 시 충돌 방지를 위한 락

# 스크린샷 저장 디렉토리
SCREENSHOTS_DIR = 'screenshots'
if not os.path.exists(SCREENSHOTS_DIR):
    os.makedirs(SCREENSHOTS_DIR)

# =========================================================
# Picamera2 초기화
# =========================================================
print("[INFO] Picamera2 초기화 중...")
try:
    picam2 = Picamera2()
    # 캡처 및 스트리밍에 필요한 최소 설정
    config = picam2.create_preview_configuration(
        main={"size": (640, 480), "format": "RGB888"}
    )
    picam2.configure(config)
    picam2.start()
    time.sleep(2)
    print("[INFO] 카메라 준비 완료 (picamera2 방식)")
except Exception as e:
    print(f"[ERROR] Picamera2 초기화 실패: {e}")
    print("[ERROR] 라즈베리파이 카메라 모듈 연결 및 설정(raspi-config)을 확인하세요.")
    # 서버는 계속 실행되지만 스트림은 작동하지 않을 수 있습니다.

def generate_frames():
    """카메라 프레임을 JPEG로 인코딩하여 스트리밍"""
    global last_frame # 전역 변수 last_frame 사용 선언

    while True:
        try:
            # 프레임 캡처 (picamera2 방식)
            frame = picam2.capture_array()
            
            # 🌟 캡처 기능 통합: 현재 프레임을 저장소에 업데이트
            with frame_lock:
                last_frame = frame
                
            # JPEG로 인코딩
            if frame is None or frame.size == 0:
                time.sleep(0.1)
                continue
                
            _, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
            frame_bytes = buffer.tobytes()

            # MJPEG 형식으로 전송
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')

        except NameError:
            # picam2 객체가 초기화되지 않았을 경우 (카메라 오류)
            # print("Picamera2 객체가 없어 프레임을 생성할 수 없습니다.") # 너무 많은 출력 방지
            time.sleep(1)
            continue
        except Exception as e:
            # print(f"Streaming Error: {e}") # 디버깅용
            time.sleep(1)
            continue

        # FPS 조절
        time.sleep(0.066)

# =========================================================
# API 엔드포인트
# =========================================================

@app.route('/video_feed')
def video_feed():
    """비디오 스트림 엔드포인트 (웹 뷰어용)"""
    return Response(generate_frames(),
                    mimetype='multipart/x-mixed-replace; boundary=frame')

@app.route('/api/camera/1/stream')
def video_stream():
    """비디오 스트림 엔드포인트 (앱 호환성용)"""
    return video_feed()

@app.route('/api/camera/<int:camera_id>/capture', methods=['POST'])
def capture_screenshot(camera_id):
    """스크린샷 캡처 및 저장 엔드포인트"""
    
    # 🌟 디버깅 출력: 캡처 요청이 서버에 도달했는지 확인
    print(f"*** [DEBUG] CAPTURE REQUEST RECEIVED for Camera {camera_id} ***") 
    
    if camera_id != 1:
        return jsonify({'error': 'Only camera 1 is supported by this server'}), 400

    frame_to_save = None
    with frame_lock:
        if last_frame is not None:
            # 저장 전에 프레임 복사
            frame_to_save = last_frame.copy() 

    if frame_to_save is None:
        print("*** [DEBUG] ERROR: No frame available to save. ***")
        return jsonify({'error': 'No frame available. Camera not started or failed.'}), 500

    # 파일명 생성 (타임스탬프 포함)
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f'camera_{camera_id}_{timestamp}.jpg'
    filepath = os.path.join(SCREENSHOTS_DIR, filename)

    # 이미지 저장
    success = cv2.imwrite(filepath, frame_to_save)

    if success:
        print(f"*** [DEBUG] SUCCESS: Screenshot saved as {filename} ***")
        return jsonify({
            'success': True,
            'filename': filename,
            'filepath': filepath,
            'url': f'/api/screenshots/{filename}',
            'timestamp': datetime.now().isoformat()
        })
    else:
        # 캡처 실패 시 (대부분 권한 문제)
        print("*** [DEBUG] ERROR: cv2.imwrite failed (Permission/I/O issue). ***")
        return jsonify({'error': 'Failed to save screenshot (Check folder permissions)'}), 500

@app.route('/api/screenshots/<filename>')
def get_screenshot(filename):
    """스크린샷 이미지 파일 제공"""
    filepath = os.path.join(SCREENSHOTS_DIR, filename)
    if os.path.exists(filepath):
        return send_file(filepath, mimetype='image/jpeg')
    else:
        return jsonify({'error': 'Screenshot not found'}), 404

@app.route('/')
def index():
    """간단한 웹 뷰어 (앱 호환성 테스트용)"""
    return """
    <html>
    <head><title>🔥 Picamera2 스트림 서버</title></head>
    <body>
        <h1>🔥 Picamera2 스트림 및 캡처 서버 (real_server.py)</h1>
        <p>서버가 정상 작동 중입니다. 스트림 URL: /video_feed 또는 /api/camera/1/stream</p>
        <img src="/video_feed" alt="Camera Stream" width="640">
        <p>캡처 테스트용 POST 엔드포인트: /api/camera/1/capture</p>
    </body>
    </html>
    """

if __name__ == '__main__':
    try:
        print("=" * 60)
        print("MJPEG 스트림 서버 시작 (Picamera2 / 캡처 기능 활성화)")
        print("=" * 60)
        print("[INFO] 캡처 폴더: ./screenshots/")
        print("[INFO] 서버 주소: http://0.0.0.0:5000")
        app.run(host='0.0.0.0', port=5000, threaded=True)
    except KeyboardInterrupt:
        print("\n[INFO] 서버 종료 중...")
    finally:
        # 서버 종료 시 카메라 정리
        try:
            picam2.stop()
            print("[INFO] 카메라 정리 완료")
        except NameError:
             # picam2 초기화에 실패한 경우
            pass