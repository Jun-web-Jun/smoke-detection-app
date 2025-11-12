#!/usr/bin/env python3
"""
Raspberry Pi Camera Test Script
라즈베리파이 카메라 테스트 스크립트
"""

import sys

def test_picamera2():
    """picamera2 라이브러리 테스트 (Raspberry Pi Camera Module용)"""
    try:
        print("=== Testing picamera2 (Raspberry Pi Camera Module) ===")
        from picamera2 import Picamera2

        # 카메라 초기화
        picam2 = Picamera2()

        # 카메라 설정 확인
        camera_config = picam2.create_still_configuration()
        picam2.configure(camera_config)

        # 카메라 시작
        picam2.start()
        print("✓ Picamera2 initialized successfully!")

        # 테스트 사진 촬영
        print("Taking test photo...")
        picam2.capture_file("test_photo.jpg")
        print("✓ Test photo saved as 'test_photo.jpg'")

        # 카메라 정지
        picam2.stop()
        print("✓ Picamera2 test completed successfully!\n")
        return True

    except ImportError:
        print("✗ picamera2 not installed")
        print("  Install with: sudo apt install -y python3-picamera2\n")
        return False
    except Exception as e:
        print(f"✗ Picamera2 error: {e}\n")
        return False


def test_opencv():
    """OpenCV로 USB 웹캠 테스트"""
    try:
        print("=== Testing OpenCV (USB Webcam) ===")
        import cv2

        # 카메라 열기 (장치 번호 0)
        cap = cv2.VideoCapture(0)

        if not cap.isOpened():
            print("✗ Cannot open camera (device 0)")
            return False

        # 프레임 읽기 테스트
        ret, frame = cap.read()

        if ret:
            print("✓ OpenCV camera initialized successfully!")
            print(f"  Resolution: {frame.shape[1]}x{frame.shape[0]}")

            # 테스트 이미지 저장
            cv2.imwrite("test_webcam.jpg", frame)
            print("✓ Test image saved as 'test_webcam.jpg'")
        else:
            print("✗ Failed to read frame from camera")
            cap.release()
            return False

        cap.release()
        print("✓ OpenCV test completed successfully!\n")
        return True

    except ImportError:
        print("✗ OpenCV not installed")
        print("  Install with: pip3 install opencv-python\n")
        return False
    except Exception as e:
        print(f"✗ OpenCV error: {e}\n")
        return False


def check_system_info():
    """시스템 정보 확인"""
    print("=== System Information ===")

    # Python 버전
    print(f"Python version: {sys.version}")

    # 카메라 장치 확인
    import os
    if os.path.exists('/dev/video0'):
        print("✓ Camera device found: /dev/video0")
    else:
        print("✗ No camera device found at /dev/video0")

    print()


if __name__ == "__main__":
    print("=" * 60)
    print("Raspberry Pi Camera Test")
    print("=" * 60)
    print()

    check_system_info()

    # Raspberry Pi Camera Module 테스트
    picamera_ok = test_picamera2()

    # USB 웹캠 테스트
    opencv_ok = test_opencv()

    # 결과 요약
    print("=" * 60)
    print("Test Summary:")
    print("=" * 60)
    print(f"Picamera2 (Pi Camera Module): {'✓ PASS' if picamera_ok else '✗ FAIL'}")
    print(f"OpenCV (USB Webcam):          {'✓ PASS' if opencv_ok else '✗ FAIL'}")
    print()

    if picamera_ok or opencv_ok:
        print("✓ At least one camera is working!")
        print("\nNext step: Run the camera streaming server")
        print("  python3 camera_stream_server.py")
    else:
        print("✗ No working camera found")
        print("\nPlease check:")
        print("  1. Camera is properly connected")
        print("  2. Camera is enabled in raspi-config")
        print("  3. Required libraries are installed")
