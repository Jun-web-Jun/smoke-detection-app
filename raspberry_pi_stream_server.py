#!/usr/bin/env python3
"""
Raspberry Pi Camera Streaming Server
라즈베리파이 카메라 스트리밍 서버 (MJPEG)
"""

from flask import Flask, Response, render_template_string
import cv2
import threading
import time

app = Flask(__name__)

# 전역 변수
output_frame = None
lock = threading.Lock()

# 카메라 설정
CAMERA_INDEX = 0  # 0 = 첫 번째 카메라
FRAME_WIDTH = 640
FRAME_HEIGHT = 480
FPS = 30


class VideoCamera:
    """비디오 카메라 클래스"""

    def __init__(self):
        self.video = cv2.VideoCapture(CAMERA_INDEX)
        self.video.set(cv2.CAP_PROP_FRAME_WIDTH, FRAME_WIDTH)
        self.video.set(cv2.CAP_PROP_FRAME_HEIGHT, FRAME_HEIGHT)
        self.video.set(cv2.CAP_PROP_FPS, FPS)

        if not self.video.isOpened():
            raise RuntimeError("Could not start camera")

    def __del__(self):
        if self.video.isOpened():
            self.video.release()

    def get_frame(self):
        """프레임 읽기"""
        success, image = self.video.read()
        if not success:
            return None

        # 텍스트 오버레이 추가
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        cv2.putText(
            image,
            f"Raspberry Pi Camera - {timestamp}",
            (10, 30),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.6,
            (0, 255, 0),
            2,
        )

        # JPEG 인코딩
        ret, jpeg = cv2.imencode('.jpg', image)
        return jpeg.tobytes()


def capture_frames():
    """백그라운드에서 프레임 캡처"""
    global output_frame, lock

    camera = VideoCamera()
    print("✓ Camera initialized successfully")

    while True:
        frame = camera.get_frame()

        if frame is not None:
            with lock:
                output_frame = frame

        time.sleep(1 / FPS)


def generate_frames():
    """프레임 생성기 (MJPEG 스트림용)"""
    global output_frame, lock

    while True:
        with lock:
            if output_frame is None:
                continue

            frame = output_frame

        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')


# HTML 템플릿
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>Raspberry Pi Camera Stream</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            text-align: center;
            background-color: #1a1a2e;
            color: white;
            padding: 20px;
        }
        h1 {
            color: #00d4ff;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
        }
        img {
            border: 3px solid #00d4ff;
            border-radius: 10px;
            width: 100%;
            max-width: 640px;
        }
        .info {
            background-color: #16213e;
            padding: 15px;
            border-radius: 10px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎥 Raspberry Pi Camera Stream</h1>
        <p>연기 감지 시스템 - 실시간 카메라</p>

        <img src="{{ url_for('video_feed') }}" alt="Camera Stream">

        <div class="info">
            <p><strong>스트림 정보:</strong></p>
            <p>해상도: {{ width }}x{{ height }} @ {{ fps }} FPS</p>
            <p>형식: MJPEG</p>
        </div>
    </div>
</body>
</html>
"""


@app.route('/')
def index():
    """메인 페이지"""
    return render_template_string(
        HTML_TEMPLATE,
        width=FRAME_WIDTH,
        height=FRAME_HEIGHT,
        fps=FPS
    )


@app.route('/video_feed')
def video_feed():
    """비디오 스트림 엔드포인트"""
    return Response(
        generate_frames(),
        mimetype='multipart/x-mixed-replace; boundary=frame'
    )


@app.route('/api/camera/status')
def camera_status():
    """카메라 상태 API"""
    return {
        'status': 'active' if output_frame is not None else 'inactive',
        'resolution': f'{FRAME_WIDTH}x{FRAME_HEIGHT}',
        'fps': FPS,
        'timestamp': time.strftime("%Y-%m-%d %H:%M:%S")
    }


if __name__ == '__main__':
    print("=" * 60)
    print("Raspberry Pi Camera Streaming Server")
    print("=" * 60)
    print()

    # 카메라 캡처 스레드 시작
    print("Starting camera capture thread...")
    capture_thread = threading.Thread(target=capture_frames, daemon=True)
    capture_thread.start()

    # 카메라 초기화 대기
    time.sleep(2)

    # 서버 정보 출력
    print()
    print("✓ Server is ready!")
    print()
    print("Access the camera stream at:")
    print(f"  http://<raspberry-pi-ip>:5000")
    print()
    print("API endpoints:")
    print(f"  http://<raspberry-pi-ip>:5000/video_feed")
    print(f"  http://<raspberry-pi-ip>:5000/api/camera/status")
    print()
    print("Press Ctrl+C to stop the server")
    print("=" * 60)
    print()

    # Flask 서버 시작
    app.run(host='0.0.0.0', port=5000, threaded=True, debug=False)
