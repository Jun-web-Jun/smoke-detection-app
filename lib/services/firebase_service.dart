import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/detection_event.dart';

/// Firebase 백엔드 서비스
class FirebaseService {
  // Firestore 인스턴스
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Storage 인스턴스
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // 컬렉션 참조
  static final CollectionReference _eventsCollection =
      _firestore.collection('detection_events');
  static final CollectionReference _devicesCollection =
      _firestore.collection('devices');

  /// 감지 이벤트 목록 스트림 (실시간 업데이트)
  static Stream<List<DetectionEvent>> getEventsStream({
    int limit = 100,
    EventStatus? statusFilter,
  }) {
    Query query = _eventsCollection
        .orderBy('timestamp', descending: true)
        .limit(limit);

    // 상태 필터링 (라즈베리파이 데이터는 resolved 필드 사용)
    if (statusFilter != null) {
      if (statusFilter == EventStatus.completed) {
        query = query.where('resolved', isEqualTo: true);
      } else {
        query = query.where('resolved', isEqualTo: false);
      }
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _convertFirestoreToDetectionEvent(doc.id, data);
      }).toList();
    });
  }

  /// 감지 이벤트 목록 한번 가져오기
  static Future<List<DetectionEvent>> getEvents({
    int limit = 100,
    EventStatus? statusFilter,
  }) async {
    try {
      Query query = _eventsCollection
          .orderBy('created_at', descending: true)
          .limit(limit);

      if (statusFilter != null) {
        query = query.where('status', isEqualTo: statusFilter.name);
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _convertFirestoreToDetectionEvent(doc.id, data);
      }).toList();
    } catch (e) {
      print('Error fetching events: $e');
      return [];
    }
  }

  /// 특정 이벤트 가져오기
  static Future<DetectionEvent?> getEvent(String eventId) async {
    try {
      final doc = await _eventsCollection.doc(eventId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      return _convertFirestoreToDetectionEvent(doc.id, data);
    } catch (e) {
      print('Error fetching event: $e');
      return null;
    }
  }

  /// 새 감지 이벤트 생성 (라즈베리파이에서 호출)
  static Future<String?> createDetectionEvent({
    required int cameraId,
    required String location,
    required List<String> detectedObjects,
    required double confidence,
    Uint8List? imageData,
  }) async {
    try {
      final docRef = _eventsCollection.doc();
      final eventId = docRef.id;
      final now = DateTime.now();

      // 이미지 업로드 (있으면)
      String? imageUrl;
      if (imageData != null) {
        imageUrl = await _uploadImage(eventId, imageData);
      }

      // Firestore에 이벤트 데이터 저장
      await docRef.set({
        'camera_id': cameraId,
        'location': location,
        'detected_objects': detectedObjects,
        'confidence': confidence,
        'timestamp': Timestamp.fromDate(now),
        'created_at': Timestamp.fromDate(now),
        'status': 'pending',
        if (imageUrl != null) 'image_url': imageUrl,
      });

      print('Event created: $eventId');
      return eventId;
    } catch (e) {
      print('Error creating event: $e');
      return null;
    }
  }

  /// 이벤트 상태 업데이트
  static Future<bool> updateEventStatus(
    String eventId,
    EventStatus status,
  ) async {
    try {
      await _eventsCollection.doc(eventId).update({
        'status': status.name,
        'updated_at': Timestamp.now(),
      });
      return true;
    } catch (e) {
      print('Error updating event status: $e');
      return false;
    }
  }

  /// 이벤트 삭제
  static Future<bool> deleteEvent(String eventId) async {
    try {
      // 이미지도 삭제
      await _deleteEventImage(eventId);

      // Firestore 문서 삭제
      await _eventsCollection.doc(eventId).delete();
      return true;
    } catch (e) {
      print('Error deleting event: $e');
      return false;
    }
  }

  /// 이미지 업로드 (Firebase Storage)
  static Future<String?> _uploadImage(
    String eventId,
    Uint8List imageData,
  ) async {
    try {
      final storageRef = _storage
          .ref()
          .child('detection_images')
          .child('$eventId.jpg');

      await storageRef.putData(
        imageData,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  /// 이벤트 이미지 삭제
  static Future<void> _deleteEventImage(String eventId) async {
    try {
      final storageRef = _storage
          .ref()
          .child('detection_images')
          .child('$eventId.jpg');
      await storageRef.delete();
    } catch (e) {
      print('Error deleting image: $e');
    }
  }

  /// Firestore 데이터를 DetectionEvent 모델로 변환
  static DetectionEvent _convertFirestoreToDetectionEvent(
    String id,
    Map<String, dynamic> data,
  ) {
    // 라즈베리파이에서 저장한 데이터 구조
    // { type: 'smoking', timestamp: ..., details: {...}, resolved: false }

    final type = data['type'] as String? ?? 'unknown';
    final details = data['details'] as Map<String, dynamic>? ?? {};
    final resolved = data['resolved'] as bool? ?? false;

    // 라벨 결정 (type에서 가져옴)
    String label = 'cigarette'; // 기본값은 cigarette
    if (type == 'smoking') {
      label = 'cigarette';
    } else if (type == 'person') {
      label = 'person';
    }

    // details에서 실제 감지된 객체 확인
    final person = details['person'] as bool? ?? false;
    final cigarette = details['cigarette'] as bool? ?? false;
    final smoke = details['smoke'] as bool? ?? false;
    final fire = details['fire'] as bool? ?? false;

    // 우선순위: fire > cigarette > smoke > person
    if (fire) {
      label = 'fire';
    } else if (cigarette) {
      label = 'cigarette';
    } else if (smoke) {
      label = 'smoke';
    } else if (person) {
      label = 'person';
    }

    // 상태 변환
    EventStatus status = resolved ? EventStatus.completed : EventStatus.pending;

    // 타임스탬프 처리
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

    // 이미지 URL (현재는 플레이스홀더)
    final imageUrl = data['image_url'] as String? ??
        'https://via.placeholder.com/640x480/FF6B6B/FFFFFF?text=흡연+감지';

    // 신뢰도 계산 (기본값 0.9)
    double confidence = 0.9;

    return DetectionEvent(
      id: id,
      timestamp: timestamp,
      label: label,
      confidence: confidence,
      imageUrl: imageUrl,
      thumbnailUrl: imageUrl,
      metadata: {
        'type': type,
        'details': details,
        'message': details['message'] ?? '',
      },
      status: status,
      location: data['location'] as String? ?? 'N1동(본부관) 1층 입구',
    );
  }

  /// 장치 정보 등록 (라즈베리파이)
  static Future<void> registerDevice({
    required String deviceId,
    required String deviceName,
    required String location,
    String? streamUrl,
  }) async {
    try {
      await _devicesCollection.doc(deviceId).set({
        'device_id': deviceId,
        'device_name': deviceName,
        'location': location,
        'stream_url': streamUrl,
        'status': 'online',
        'last_seen': Timestamp.now(),
        'created_at': Timestamp.now(),
      });
    } catch (e) {
      print('Error registering device: $e');
    }
  }

  /// 장치 상태 업데이트
  static Future<void> updateDeviceStatus(
    String deviceId,
    String status,
  ) async {
    try {
      await _devicesCollection.doc(deviceId).update({
        'status': status,
        'last_seen': Timestamp.now(),
      });
    } catch (e) {
      print('Error updating device status: $e');
    }
  }

  /// 장치 목록 가져오기
  static Stream<List<Map<String, dynamic>>> getDevicesStream() {
    return _devicesCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return doc.data() as Map<String, dynamic>;
      }).toList();
    });
  }
}
