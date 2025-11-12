# -*- coding: utf-8 -*-
"""
Push notification test (auto-run without input)
"""

from fcm_notification_sender import FCMNotificationSender
import time

print("=== Push Notification Test Started ===\n")

# Initialize FCM client
sender = FCMNotificationSender('firebase-service-account.json')

print("\nTest 1: Topic-based notification")
print("-" * 50)
result1 = sender.send_to_topic(
    topic='smoking_detection',
    title='Test Notification',
    body='This is a test notification. Check your app!',
    data={
        'type': 'test',
        'message': 'Hello from Python!'
    }
)
if result1:
    print(f"SUCCESS: Notification sent, message ID: {result1}")
else:
    print("FAILED: Could not send notification")

time.sleep(2)

print("\nTest 2: Smoking detection simulation")
print("-" * 50)
result2 = sender.send_smoking_detection_notification(
    camera_id=1,
    location='Building 1F Entrance (Test)',
    event_id='test_event_' + str(int(time.time()))
)
if result2:
    print(f"SUCCESS: Smoking detection notification sent")
else:
    print("FAILED: Could not send smoking detection notification")

time.sleep(2)

print("\nTest 3: Send to all devices")
print("-" * 50)
success_count = sender.send_smoking_detection_to_all(
    camera_id=2,
    location='Building 2F Corridor (Test)',
    event_id='test_event_' + str(int(time.time()))
)
print(f"SUCCESS: Notifications sent to {success_count} devices")

print("\n=== Test Completed ===")
print("Check your Flutter app for notifications!")
