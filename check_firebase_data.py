"""Check what's actually in Firebase"""
import firebase_admin
from firebase_admin import credentials, firestore

print("Checking Firebase data...")

# Initialize
cred = credentials.Certificate('firebase-service-account.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

print("\n" + "="*60)
print("DEVICES Collection:")
print("="*60)
devices = db.collection('devices').stream()
device_count = 0
for doc in devices:
    device_count += 1
    print(f"\nDocument ID: {doc.id}")
    print(f"Data: {doc.to_dict()}")

if device_count == 0:
    print("(empty)")
else:
    print(f"\nTotal devices: {device_count}")

print("\n" + "="*60)
print("EVENTS Collection:")
print("="*60)
events = db.collection('events').stream()
event_count = 0
for doc in events:
    event_count += 1
    print(f"\nDocument ID: {doc.id}")
    data = doc.to_dict()
    print(f"Location: {data.get('location')}")
    print(f"Objects: {data.get('detected_objects')}")
    print(f"Confidence: {data.get('confidence')}")
    print(f"Status: {data.get('status')}")

if event_count == 0:
    print("(empty)")
else:
    print(f"\nTotal events: {event_count}")

print("\n" + "="*60)
print("Summary:")
print(f"  Devices: {device_count}")
print(f"  Events: {event_count}")
print("="*60)
