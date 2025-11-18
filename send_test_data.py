"""Send test data to Firebase - No emoji version"""
import firebase_admin
from firebase_admin import credentials, firestore, storage
import numpy as np
import cv2
from datetime import datetime

print("=" * 60)
print("Firebase Test - Sending Data")
print("=" * 60)

# Initialize Firebase
print("\n1. Initializing Firebase...")
cred = credentials.Certificate('firebase-service-account.json')
firebase_admin.initialize_app(cred, {
    'storageBucket': 'smoke-detection-system-d85b6.firebasestorage.app'
})
db = firestore.client()
bucket = storage.bucket()
print("OK: Firebase initialized")

# Register device
print("\n2. Registering device...")
device_data = {
    'device_id': 'raspberry-pi-001',
    'device_name': 'Main Camera',
    'location': 'Building 1 - Entrance',
    'status': 'online',
    'last_seen': firestore.SERVER_TIMESTAMP,
    'created_at': firestore.SERVER_TIMESTAMP,
}
db.collection('devices').document('raspberry-pi-001').set(device_data)
print("OK: Device registered")

# Create test image
print("\n3. Creating test image...")
image = np.zeros((480, 640, 3), dtype=np.uint8)
cv2.putText(image, 'Smoking Detection Test', (50, 200),
            cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
cv2.putText(image, datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            (50, 260), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)
print("OK: Test image created")

# Upload image to Storage
print("\n4. Uploading image to Storage...")
_, buffer = cv2.imencode('.jpg', image)
image_bytes = buffer.tobytes()
event_id = f'test_{datetime.now().strftime("%Y%m%d_%H%M%S")}'
blob = bucket.blob(f'detection_images/{event_id}.jpg')
blob.upload_from_string(image_bytes, content_type='image/jpeg')
blob.make_public()
image_url = blob.public_url
print(f"OK: Image uploaded - {event_id}.jpg")

# Create detection event in Firestore
print("\n5. Creating detection event...")
event_data = {
    'camera_id': 1,
    'location': 'Building 1 - Entrance',
    'detected_objects': ['person', 'cigarette'],
    'confidence': 0.95,
    'timestamp': firestore.SERVER_TIMESTAMP,
    'created_at': firestore.SERVER_TIMESTAMP,
    'status': 'pending',
    'image_url': image_url,
}
doc_ref = db.collection('events').document(event_id)
doc_ref.set(event_data)
print(f"OK: Event created - ID: {event_id}")

print("\n" + "=" * 60)
print("SUCCESS! All data sent to Firebase")
print("=" * 60)
print("\nCheck Firebase Console:")
print("1. Firestore > 'devices' collection")
print("2. Firestore > 'events' collection")
print("3. Storage > 'detection_images' folder")
print("=" * 60)
