#!/usr/bin/env python3
"""
라즈베리파이 카메라 MJPEG 스트리밍 서버 (picamera2 - Debian 12 호환)
[CORS 수정 완료] - Chrome 웹 테스트용
"""
from flask import Flask, Response
from flask_cors import CORS  # <-- 1. CORS 부품 가져오기
from picamera2 import Picamera2
import cv2
import time

app = Flask(__name__)
CORS(app)  # <-- 2. CORS 보안 허용 (Chrome이 접속할 수 있도록)

# 카메라 초기화 (picamera2 사용)
print("[INFO] Picamera2 초기화 중...")
picam2 = Picamera2()
config = picam2.create_preview_configuration(
    main={"size": (640, 480), "format": "RGB888"}
)
picam2.configure(config)
picam2.start()
time.sleep(2)
print("[INFO] 카메라 준비 완료 (picamera2 방식)")

def generate_frames():
    """카메라 프레임을 JPEG로 인코딩하여 스트리밍"""
    while True:
        # 프레임 캡처 (picamera2 방식)
        frame = picam2.capture_array()

        # JPEG로 인코딩
        _, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
        frame_bytes = buffer.tobytes()

        # MJPEG 형식으로 전송
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')

        # FPS 조절
        time.sleep(0.066)

@app.route('/video_feed')
def video_feed():
    """비디오 스트림 엔드포인트"""
    return Response(generate_frames(),
                    mimetype='multipart/x-mixed-replace; boundary=frame')

@app.route('/')
def index():
    """간단한 웹 뷰어 (앱 호환성 테스트용)"""
    return """
    <html>
    <head><title>🔥 Picamera2 스트림 (정상 - CORS)</title></head>
    <body>
        <h1>🔥 Picamera2 스트림 (정상 - CORS)</h1>
        <p>'신형' 서버 (CORS 수정 완료)가 작동 중입니다.</p>
        <img src="/video_feed" alt="Camera Stream">
    </body>
    </html>
    """

if __name__ == '__main__':
    try:
        print("[INFO] MJPEG 스트림 서버 시작 (picamera2 / CORS 활성화)...")
        print("[INFO] 접속 주소: http://<라즈베리파이_IP>:5000")
        print("[INFO] 스트림 URL: http://<라즈베리파이_IP>:5000/video_feed")
        app.run(host='0.0.0.0', port=5000, threaded=True)
    except KeyboardInterrupt:
        print("\n[INFO] 서버 종료 중...")
    finally:
        picam2.stop()
        print("[INFO] 카메라 정리 완료")