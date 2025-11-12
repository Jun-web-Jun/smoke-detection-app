"""
CCTV 카메라 스트리밍 서버 (더미 버전)
웹캠 없이도 테스트용 영상을 생성합니다.
"""

from flask import Flask, Response, jsonify
from flask_cors import CORS
import cv2
import numpy as np
import threading
import time
from datetime import datetime
import math

app = Flask(__name__)
CORS(app)

cameras = {}
camera_lock = threading.Lock()

class DummyCameraStream:
    """더미 카메라 스트림 (웹캠 없이 테스트용)"""
    def __init__(self, camera_id):
        self.camera_id = camera_id
        self.is_running = False
        self.last_frame = None
        self.frame_lock = threading.Lock()
        self.frame_count = 0

    def start(self):
        if self.is_running:
            return True

        self.is_running = True
        thread = threading.Thread(target=self._generate_frames, daemon=True)
        thread.start()
        return True

    def _generate_frames(self):
        """더미 프레임 생성"""
        while self.is_running:
            # 640x480 크기의 더미 이미지 생성
            frame = np.zeros((480, 640, 3), dtype=np.uint8)

            # 배경 그라데이션
            for y in range(480):
                color_value = int(30 + (y / 480) * 30)
                frame[y, :] = [color_value, color_value, color_value]

            # 움직이는 원 (카메라가 작동중임을 표시)
            t = self.frame_count / 30.0
            cx = int(320 + 200 * math.sin(t))
            cy = int(240 + 100 * math.cos(t * 1.5))
            cv2.circle(frame, (cx, cy), 30, (0, 255, 255), -1)

            # 그리드 라인
            for i in range(0, 640, 64):
                cv2.line(frame, (i, 0), (i, 480), (50, 50, 50), 1)
            for i in range(0, 480, 48):
                cv2.line(frame, (0, i), (640, i), (50, 50, 50), 1)

            # 카메라 정보
            cv2.putText(frame, f'Camera {self.camera_id} - DUMMY MODE',
                       (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)

            # 타임스탬프
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            cv2.putText(frame, timestamp, (20, 80),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

            # 프레임 카운트
            cv2.putText(frame, f'Frame: {self.frame_count}', (20, 120),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 2)

            # REC 표시
            if self.frame_count % 30 < 15:  # 깜빡임 효과
                cv2.circle(frame, (600, 30), 10, (0, 0, 255), -1)
                cv2.putText(frame, 'REC', (560, 40),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 2)

            with self.frame_lock:
                self.last_frame = frame

            self.frame_count += 1
            time.sleep(0.033)  # ~30 FPS

    def get_frame(self):
        with self.frame_lock:
            return self.last_frame.copy() if self.last_frame is not None else None

    def stop(self):
        self.is_running = False

def generate_frames(camera_id):
    """프레임 생성기"""
    camera = cameras.get(camera_id)
    if not camera:
        return

    while camera.is_running:
        frame = camera.get_frame()
        if frame is None:
            time.sleep(0.1)
            continue

        ret, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
        if not ret:
            continue

        frame_bytes = buffer.tobytes()
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')

@app.route('/api/cameras', methods=['GET'])
def get_cameras():
    with camera_lock:
        camera_list = [
            {
                'id': cam_id,
                'name': f'Camera {cam_id}',
                'status': 'running' if cam.is_running else 'stopped',
                'location': ['본관 1층 입구', '주차장', '후문'][cam_id - 1] if cam_id <= 3 else f'Zone {cam_id}',
                'mode': 'dummy'
            }
            for cam_id, cam in cameras.items()
        ]
    return jsonify(camera_list)

@app.route('/api/camera/<int:camera_id>/start', methods=['POST'])
def start_camera(camera_id):
    with camera_lock:
        if camera_id not in cameras:
            cameras[camera_id] = DummyCameraStream(camera_id)

        success = cameras[camera_id].start()

    return jsonify({
        'success': success,
        'camera_id': camera_id,
        'message': 'Dummy camera started',
        'mode': 'dummy'
    })

@app.route('/api/camera/<int:camera_id>/stop', methods=['POST'])
def stop_camera(camera_id):
    with camera_lock:
        if camera_id in cameras:
            cameras[camera_id].stop()

    return jsonify({
        'success': True,
        'camera_id': camera_id,
        'message': 'Camera stopped'
    })

@app.route('/api/camera/<int:camera_id>/stream')
def video_stream(camera_id):
    if camera_id not in cameras:
        return jsonify({'error': 'Camera not found'}), 404

    return Response(
        generate_frames(camera_id),
        mimetype='multipart/x-mixed-replace; boundary=frame'
    )

@app.route('/api/status')
def status():
    return jsonify({
        'status': 'running',
        'timestamp': datetime.now().isoformat(),
        'active_cameras': len([c for c in cameras.values() if c.is_running]),
        'mode': 'dummy'
    })

@app.route('/')
def index():
    return """
    <html>
        <head><title>CCTV 스트리밍 서버 (더미 모드)</title></head>
        <body style="background: #000; color: #0f0; font-family: monospace;">
            <h1>CCTV 카메라 스트리밍 서버 (더미 모드)</h1>
            <p>⚠️ 웹캠 없이 테스트용 영상을 생성합니다.</p>
            <h2>사용 가능한 엔드포인트:</h2>
            <ul>
                <li>GET /api/cameras - 카메라 목록</li>
                <li>POST /api/camera/{id}/start - 카메라 시작</li>
                <li>POST /api/camera/{id}/stop - 카메라 정지</li>
                <li>GET /api/camera/{id}/stream - 비디오 스트림</li>
                <li>GET /api/status - 서버 상태</li>
            </ul>
            <h2>테스트:</h2>
            <p><a href="/api/camera/1/stream" style="color: #0ff;">카메라 1 스트림 보기</a></p>
            <hr>
            <img src="/api/camera/1/stream" style="border: 2px solid #0ff; max-width: 100%;">
        </body>
    </html>
    """

if __name__ == '__main__':
    print("=" * 60)
    print("CCTV Camera Streaming Server (DUMMY MODE)")
    print("=" * 60)
    print("Server URL: http://localhost:5000")
    print("DUMMY MODE: Generating test video without webcam")
    print("=" * 60)

    with camera_lock:
        for i in range(1, 4):
            cameras[i] = DummyCameraStream(i)
            cameras[i].start()

    print("Cameras 1, 2, 3 auto-started")
    print("=" * 60)

    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
