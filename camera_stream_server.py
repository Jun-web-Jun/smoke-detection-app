"""
라즈베리파이 카메라 MJPEG 스트리밍 서버
Flask를 사용하여 카메라 영상을 웹으로 스트리밍
"""
from flask import Flask, Response
from picamera2 import Picamera2
import cv2
import time

app = Flask(__name__)

# 카메라 초기화
print("[INFO] Picamera2 초기화 중...")
picam2 = Picamera2()
config = picam2.create_preview_configuration(
    main={"size": (640, 480), "format": "RGB888"}
)
picam2.configure(config)
picam2.start()
time.sleep(2)
print("[INFO] 카메라 준비 완료")

def generate_frames():
    """카메라 프레임을 JPEG로 인코딩하여 스트리밍"""
    while True:
        # 프레임 캡처
        frame = picam2.capture_array()

        # JPEG로 인코딩
        _, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
        frame_bytes = buffer.tobytes()

        # MJPEG 형식으로 전송
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')

        # FPS 조절 (약 15 FPS)
        time.sleep(0.066)

@app.route('/video_feed')
def video_feed():
    """비디오 스트림 엔드포인트"""
    return Response(generate_frames(),
                    mimetype='multipart/x-mixed-replace; boundary=frame')

@app.route('/')
def index():
    """간단한 웹 뷰어"""
    return """
    <html>
    <head>
        <title>Smoke Detection Camera Stream</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                text-align: center;
                background-color: #1a1a2e;
                color: white;
                margin: 0;
                padding: 20px;
            }
            h1 {
                color: #ff6b6b;
            }
            img {
                max-width: 90%;
                border: 3px solid #ff6b6b;
                border-radius: 10px;
                box-shadow: 0 4px 8px rgba(0,0,0,0.5);
            }
            .info {
                margin-top: 20px;
                font-size: 14px;
                color: #aaa;
            }
        </style>
    </head>
    <body>
        <h1>🔥 흡연 감지 카메라 스트림</h1>
        <img src="/video_feed" alt="Camera Stream">
        <div class="info">
            <p>N1동(본부관) 1층 입구</p>
            <p>실시간 모니터링 중...</p>
        </div>
    </body>
    </html>
    """

@app.route('/health')
def health():
    """헬스 체크 엔드포인트"""
    return {"status": "ok", "camera": "active"}

if __name__ == '__main__':
    try:
        print("[INFO] MJPEG 스트림 서버 시작...")
        print("[INFO] 접속 주소: http://<라즈베리파이_IP>:5000")
        print("[INFO] 스트림 URL: http://<라즈베리파이_IP>:5000/video_feed")
        app.run(host='0.0.0.0', port=5000, threaded=True)
    except KeyboardInterrupt:
        print("\n[INFO] 서버 종료 중...")
    finally:
        picam2.stop()
        print("[INFO] 카메라 정리 완료")
