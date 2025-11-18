"""Send simple event to Firebase (no image)"""
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

print("Sending test event to Firebase...")

# Initialize
cred = credentials.Certificate('firebase-service-account.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

# Send device data
print("\n1. Sending device data...")
db.collection('devices').document('raspberry-pi-001').set({
    'device_id': 'raspberry-pi-001',
    'device_name': 'Test Camera',
    'location': 'Building 1 - Floor 1',
    'status': 'online',
    'last_seen': firestore.SERVER_TIMESTAMP,
    'created_at': firestore.SERVER_TIMESTAMP,
})
print("   OK: Device registered")

# Send event data
print("\n2. Sending detection event...")
event_id = f'test_{datetime.now().strftime("%Y%m%d_%H%M%S")}'
db.collection('events').document(event_id).set({
    'camera_id': 1,
    'location': 'Building 1 - Floor 1',
    'detected_objects': ['person', 'cigarette'],
    'confidence': 0.95,
    'timestamp': firestore.SERVER_TIMESTAMP,
    'created_at': firestore.SERVER_TIMESTAMP,
    'status': 'pending',
})
print(f"   OK: Event created - ID: {event_id}")

print("\n" + "="*60)
print("SUCCESS! Data sent to Firebase")
print("="*60)
print("\nNow check Firebase Console:")
print("1. Go to: https://console.firebase.google.com/")
print("2. Select project: smoke-detection-system-d85b6")
print("3. Click: Build > Firestore Database")
print("4. You should see:")
print("   - 'devices' collection with 'raspberry-pi-001'")
print(f"   - 'events' collection with '{event_id}'")
print("="*60)
