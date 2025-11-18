"""Send Korean test data to Firebase"""
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

print("Sending Korean test event...")

# Initialize
cred = credentials.Certificate('firebase-service-account.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

# Korean test data
event_id = f'korean_test_{datetime.now().strftime("%Y%m%d_%H%M%S")}'
db.collection('events').document(event_id).set({
    'camera_id': 1,
    'location': '본관 1층 입구',  # Korean
    'detected_objects': ['person', 'cigarette'],
    'confidence': 0.95,
    'timestamp': firestore.SERVER_TIMESTAMP,
    'created_at': firestore.SERVER_TIMESTAMP,
    'status': 'pending',
})
print(f"OK: Korean event created - ID: {event_id}")
print(f"Location: 본관 1층 입구")
print("\nCheck Firebase Console to see Korean text!")
