"""
CCTV 카메라 스트리밍 서버
웹캠을 MJPEG 스트림으로 변환하여 제공합니다.
"""

from flask import Flask, Response, jsonify, send_file, request
from flask_cors import CORS
import cv2
import threading
import time
import os
import json
import base64
from datetime import datetime, timedelta
import uuid

app = Flask(__name__)
CORS(app)  # CORS 활성화 (Flutter 웹에서 접근 가능하도록)

# 카메라 관리
cameras = {}
camera_lock = threading.Lock()

# 스크린샷 저장 디렉토리
SCREENSHOTS_DIR = 'screenshots'
if not os.path.exists(SCREENSHOTS_DIR):
    os.makedirs(SCREENSHOTS_DIR)

# 감지 이벤트 저장 디렉토리
DETECTION_EVENTS_DIR = 'detection_events'
if not os.path.exists(DETECTION_EVENTS_DIR):
    os.makedirs(DETECTION_EVENTS_DIR)

# 감지 이벤트 저장소 (메모리)
detection_events = []
detection_events_lock = threading.Lock()

class CameraStream:
    """카메라 스트림 클래스"""
    def __init__(self, camera_id, source=0):
        self.camera_id = camera_id
        self.source = source
        self.camera = None
        self.is_running = False
        self.last_frame = None
        self.frame_lock = threading.Lock()

    def start(self):
        """카메라 스트림 시작"""
        if self.is_running:
            return True

        self.camera = cv2.VideoCapture(self.source)
        if not self.camera.isOpened():
            return False

        self.is_running = True
        thread = threading.Thread(target=self._update_frame, daemon=True)
        thread.start()
        return True

    def _update_frame(self):
        """프레임 지속적으로 업데이트"""
        while self.is_running:
            success, frame = self.camera.read()
            if success:
                # 타임스탬프 추가
                timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                cv2.putText(frame, timestamp, (10, 30),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                cv2.putText(frame, f'Camera {self.camera_id}', (10, 60),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

                with self.frame_lock:
                    self.last_frame = frame
            time.sleep(0.033)  # ~30 FPS

    def get_frame(self):
        """현재 프레임 가져오기"""
        with self.frame_lock:
            return self.last_frame.copy() if self.last_frame is not None else None

    def stop(self):
        """카메라 스트림 정지"""
        self.is_running = False
        if self.camera:
            self.camera.release()
            self.camera = None

def generate_frames(camera_id):
    """프레임 생성기 (MJPEG 스트림용)"""
    camera = cameras.get(camera_id)
    if not camera:
        return

    while camera.is_running:
        frame = camera.get_frame()
        if frame is None:
            time.sleep(0.1)
            continue

        # JPEG로 인코딩
        ret, buffer = cv2.imencode('.jpg', frame)
        if not ret:
            continue

        frame_bytes = buffer.tobytes()
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')

@app.route('/api/cameras', methods=['GET'])
def get_cameras():
    """사용 가능한 카메라 목록 반환"""
    with camera_lock:
        camera_list = [
            {
                'id': cam_id,
                'name': f'Camera {cam_id}',
                'status': 'running' if cam.is_running else 'stopped',
                'location': ['본관 1층 입구', '주차장', '후문'][cam_id - 1] if cam_id <= 3 else f'Zone {cam_id}'
            }
            for cam_id, cam in cameras.items()
        ]
    return jsonify(camera_list)

@app.route('/api/camera/<int:camera_id>/start', methods=['POST'])
def start_camera(camera_id):
    """카메라 시작"""
    with camera_lock:
        if camera_id not in cameras:
            # 새 카메라 생성 (웹캠은 0번만 사용, 나머지는 더미)
            source = 0 if camera_id == 1 else None
            cameras[camera_id] = CameraStream(camera_id, source)

        success = cameras[camera_id].start()

    return jsonify({
        'success': success,
        'camera_id': camera_id,
        'message': 'Camera started' if success else 'Failed to start camera'
    })

@app.route('/api/camera/<int:camera_id>/stop', methods=['POST'])
def stop_camera(camera_id):
    """카메라 정지"""
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
    """비디오 스트림 엔드포인트"""
    if camera_id not in cameras:
        return jsonify({'error': 'Camera not found'}), 404

    return Response(
        generate_frames(camera_id),
        mimetype='multipart/x-mixed-replace; boundary=frame'
    )

@app.route('/api/camera/<int:camera_id>/capture', methods=['POST'])
def capture_screenshot(camera_id):
    """스크린샷 캡처"""
    if camera_id not in cameras:
        return jsonify({'error': 'Camera not found'}), 404

    camera = cameras[camera_id]
    if not camera.is_running:
        return jsonify({'error': 'Camera is not running'}), 400

    # 현재 프레임 가져오기
    frame = camera.get_frame()
    if frame is None:
        return jsonify({'error': 'No frame available'}), 500

    # 파일명 생성 (타임스탬프 포함)
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f'camera_{camera_id}_{timestamp}.jpg'
    filepath = os.path.join(SCREENSHOTS_DIR, filename)

    # 이미지 저장
    success = cv2.imwrite(filepath, frame)

    if success:
        return jsonify({
            'success': True,
            'filename': filename,
            'filepath': filepath,
            'url': f'/api/screenshots/{filename}',
            'timestamp': datetime.now().isoformat()
        })
    else:
        return jsonify({'error': 'Failed to save screenshot'}), 500

@app.route('/api/screenshots/<filename>')
def get_screenshot(filename):
    """스크린샷 이미지 반환"""
    filepath = os.path.join(SCREENSHOTS_DIR, filename)
    if os.path.exists(filepath):
        return send_file(filepath, mimetype='image/jpeg')
    else:
        return jsonify({'error': 'Screenshot not found'}), 404

@app.route('/api/screenshots', methods=['GET'])
def list_screenshots():
    """저장된 스크린샷 목록"""
    if not os.path.exists(SCREENSHOTS_DIR):
        return jsonify([])

    screenshots = []
    for filename in os.listdir(SCREENSHOTS_DIR):
        if filename.endswith('.jpg'):
            filepath = os.path.join(SCREENSHOTS_DIR, filename)
            screenshots.append({
                'filename': filename,
                'url': f'/api/screenshots/{filename}',
                'size': os.path.getsize(filepath),
                'created': os.path.getctime(filepath)
            })

    # 최신순으로 정렬
    screenshots.sort(key=lambda x: x['created'], reverse=True)
    return jsonify(screenshots)

@app.route('/api/detection/report', methods=['POST'])
def report_detection():
    """
    라즈베리파이에서 흡연 감지 결과 보고

    Expected JSON format:
    {
        "camera_id": 1,
        "location": "본관 1층 입구",
        "detected_objects": ["person", "cigarette"],
        "confidence": 0.95,
        "image_base64": "...",  # optional
        "timestamp": "2025-10-24T16:30:00"
    }
    """
    try:
        data = request.get_json()

        # 필수 필드 검증
        if not data or 'camera_id' not in data:
            return jsonify({'error': 'Missing camera_id'}), 400

        # 이벤트 ID 생성
        event_id = str(uuid.uuid4())
        timestamp = data.get('timestamp', datetime.now().isoformat())

        # 이벤트 객체 생성
        event = {
            'id': event_id,
            'camera_id': data.get('camera_id'),
            'location': data.get('location', '알 수 없음'),
            'detected_objects': data.get('detected_objects', []),
            'confidence': data.get('confidence', 0.0),
            'timestamp': timestamp,
            'status': 'pending',  # pending, processing, completed
            'created_at': datetime.now().isoformat()
        }

        # 이미지 저장 (있는 경우)
        image_filename = None
        if 'image_base64' in data and data['image_base64']:
            try:
                # Base64 디코딩
                image_data = base64.b64decode(data['image_base64'])

                # 파일명 생성
                timestamp_str = datetime.now().strftime('%Y%m%d_%H%M%S')
                image_filename = f'detection_{event_id}_{timestamp_str}.jpg'
                image_path = os.path.join(DETECTION_EVENTS_DIR, image_filename)

                # 파일 저장
                with open(image_path, 'wb') as f:
                    f.write(image_data)

                event['image_filename'] = image_filename
                event['image_url'] = f'/api/detection/image/{image_filename}'
            except Exception as e:
                print(f"Failed to save image: {e}")

        # 메모리에 이벤트 추가
        with detection_events_lock:
            detection_events.append(event)

            # 최근 1000개만 유지
            if len(detection_events) > 1000:
                detection_events[:] = detection_events[-1000:]

        # JSON 파일로도 저장
        json_filename = f'detection_{event_id}.json'
        json_path = os.path.join(DETECTION_EVENTS_DIR, json_filename)

        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(event, f, indent=2, ensure_ascii=False)

        return jsonify({
            'success': True,
            'event_id': event_id,
            'message': 'Detection event recorded',
            'event': event
        }), 201

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/detection/events', methods=['GET'])
def get_detection_events():
    """감지 이벤트 목록 조회"""
    with detection_events_lock:
        # 쿼리 파라미터
        limit = request.args.get('limit', default=50, type=int)
        status_filter = request.args.get('status', default=None, type=str)

        # 필터링
        events = detection_events.copy()

        if status_filter:
            events = [e for e in events if e.get('status') == status_filter]

        # 최신순 정렬 후 제한
        events.sort(key=lambda x: x.get('created_at', ''), reverse=True)
        events = events[:limit]

        return jsonify({
            'total': len(events),
            'events': events
        })

@app.route('/api/detection/image/<filename>')
def get_detection_image(filename):
    """감지 이벤트 이미지 조회"""
    filepath = os.path.join(DETECTION_EVENTS_DIR, filename)
    if os.path.exists(filepath):
        return send_file(filepath, mimetype='image/jpeg')
    else:
        return jsonify({'error': 'Image not found'}), 404

@app.route('/api/status')
def status():
    """서버 상태"""
    with detection_events_lock:
        recent_detections = len([e for e in detection_events
                                if datetime.fromisoformat(e['created_at']) >
                                datetime.now() - timedelta(hours=1)])

    return jsonify({
        'status': 'running',
        'timestamp': datetime.now().isoformat(),
        'active_cameras': len([c for c in cameras.values() if c.is_running]),
        'total_detection_events': len(detection_events),
        'recent_detections_1h': recent_detections
    })

@app.route('/')
def index():
    """메인 페이지"""
    return """
    <html>
        <head><title>CCTV 스트리밍 서버</title></head>
        <body>
            <h1>CCTV 카메라 스트리밍 서버</h1>
            <p>서버가 정상적으로 실행 중입니다.</p>
            <h2>사용 가능한 엔드포인트:</h2>
            <ul>
                <li>GET /api/cameras - 카메라 목록</li>
                <li>POST /api/camera/{id}/start - 카메라 시작</li>
                <li>POST /api/camera/{id}/stop - 카메라 정지</li>
                <li>GET /api/camera/{id}/stream - 비디오 스트림</li>
                <li>GET /api/status - 서버 상태</li>
            </ul>
            <h2>테스트:</h2>
            <p><a href="/api/camera/1/stream">카메라 1 스트림 보기</a></p>
        </body>
    </html>
    """

if __name__ == '__main__':
    print("=" * 60)
    print("CCTV 카메라 스트리밍 서버 시작")
    print("=" * 60)
    print(f"서버 주소: http://localhost:5000")
    print(f"API 문서: http://localhost:5000")
    print("=" * 60)

    # 기본 카메라 3개 초기화
    with camera_lock:
        for i in range(1, 4):
            cameras[i] = CameraStream(i, 0 if i == 1 else None)

    app.run(host='0.0.0.0', port=5000, debug=True, threaded=True)
