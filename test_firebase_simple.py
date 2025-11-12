"""Simple Firebase test"""

from raspberry_pi_client import SmokingDetectionClient
import numpy as np
import cv2

try:
    print("Initializing Firebase client...")
    client = SmokingDetectionClient('firebase-service-account.json')
    print("SUCCESS: Firebase client initialized")

    print("\nRegistering device...")
    client.register_device(
        device_id='test-device-001',
        device_name='Test Camera',
        location='Test Location'
    )
    print("SUCCESS: Device registered")

    print("\nCreating test image...")
    image = np.zeros((480, 640, 3), dtype=np.uint8)
    cv2.putText(image, 'Firebase Test', (50, 240), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
    print("SUCCESS: Test image created")

    print("\nSending detection event...")
    event_id = client.send_detection(
        camera_id=1,
        location='Test Location',
        detected_objects=['person', 'cigarette'],
        confidence=0.95,
        image=image
    )

    if event_id:
        print(f"\nSUCCESS! Event ID: {event_id}")
        print("\nNext steps:")
        print("1. Check Firebase Console > Firestore Database")
        print("2. Check Firebase Storage for uploaded image")
        print("3. Run Flutter app to see real-time data")
    else:
        print("\nFAILED: Could not send event")

except Exception as e:
    print(f"\nERROR: {e}")
