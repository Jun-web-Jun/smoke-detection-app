import '../models/detection_event.dart';

/// 더미 데이터 서비스
class DummyDataService {
  /// 더미 감지 이벤트 목록 생성 (발표용 데모 데이터)
  static List<DetectionEvent> generateDummyEvents() {
    final now = DateTime.now();

    return [
      // 오늘 - 최근
      DetectionEvent(
        id: 'event_001',
        timestamp: now.subtract(const Duration(minutes: 12)),
        label: 'cigarette',
        confidence: 0.94,
        imageUrl: 'https://via.placeholder.com/800x600/FF6B6B/FFFFFF?text=흡연+감지',
        thumbnailUrl: 'https://via.placeholder.com/150x150/FF6B6B/FFFFFF?text=흡연',
        metadata: {
          'camera_id': 'cam_001',
          'detection_count': 1,
        },
        location: 'N1동(본부관) 1층 입구',
      ),
      // 오늘 - 오전
      DetectionEvent(
        id: 'event_002',
        timestamp: now.subtract(const Duration(hours: 2, minutes: 30)),
        label: 'cigarette',
        confidence: 0.91,
        imageUrl: 'https://via.placeholder.com/800x600/FF6B6B/FFFFFF?text=흡연+감지',
        thumbnailUrl: 'https://via.placeholder.com/150x150/FF6B6B/FFFFFF?text=흡연',
        metadata: {
          'camera_id': 'cam_001',
          'detection_count': 1,
        },
        location: 'N1동(본부관) 1층 입구',
      ),
      DetectionEvent(
        id: 'event_003',
        timestamp: now.subtract(const Duration(hours: 4, minutes: 15)),
        label: 'cigarette',
        confidence: 0.88,
        imageUrl: 'https://via.placeholder.com/800x600/FF6B6B/FFFFFF?text=흡연+감지',
        thumbnailUrl: 'https://via.placeholder.com/150x150/FF6B6B/FFFFFF?text=흡연',
        metadata: {
          'camera_id': 'cam_001',
          'detection_count': 1,
        },
        location: 'N1동(본부관) 1층 입구',
      ),
      // 어제
      DetectionEvent(
        id: 'event_004',
        timestamp: now.subtract(const Duration(days: 1, hours: 3)),
        label: 'cigarette',
        confidence: 0.93,
        imageUrl: 'https://via.placeholder.com/800x600/FF6B6B/FFFFFF?text=흡연+감지',
        thumbnailUrl: 'https://via.placeholder.com/150x150/FF6B6B/FFFFFF?text=흡연',
        metadata: {
          'camera_id': 'cam_001',
          'detection_count': 1,
        },
        location: 'N1동(본부관) 1층 입구',
      ),
      DetectionEvent(
        id: 'event_005',
        timestamp: now.subtract(const Duration(days: 1, hours: 7)),
        label: 'cigarette',
        confidence: 0.89,
        imageUrl: 'https://via.placeholder.com/800x600/FF6B6B/FFFFFF?text=흡연+감지',
        thumbnailUrl: 'https://via.placeholder.com/150x150/FF6B6B/FFFFFF?text=흡연',
        metadata: {
          'camera_id': 'cam_001',
          'detection_count': 1,
        },
        location: 'N1동(본부관) 1층 입구',
      ),
      // 이번 주
      DetectionEvent(
        id: 'event_006',
        timestamp: now.subtract(const Duration(days: 2, hours: 5)),
        label: 'cigarette',
        confidence: 0.92,
        imageUrl: 'https://via.placeholder.com/800x600/FF6B6B/FFFFFF?text=흡연+감지',
        thumbnailUrl: 'https://via.placeholder.com/150x150/FF6B6B/FFFFFF?text=흡연',
        metadata: {
          'camera_id': 'cam_001',
          'detection_count': 1,
        },
        location: 'N1동(본부관) 1층 입구',
      ),
      DetectionEvent(
        id: 'event_007',
        timestamp: now.subtract(const Duration(days: 3, hours: 2)),
        label: 'cigarette',
        confidence: 0.87,
        imageUrl: 'https://via.placeholder.com/800x600/FF6B6B/FFFFFF?text=흡연+감지',
        thumbnailUrl: 'https://via.placeholder.com/150x150/FF6B6B/FFFFFF?text=흡연',
        metadata: {
          'camera_id': 'cam_001',
          'detection_count': 1,
        },
        location: 'N1동(본부관) 1층 입구',
      ),
      DetectionEvent(
        id: 'event_008',
        timestamp: now.subtract(const Duration(days: 5, hours: 6)),
        label: 'cigarette',
        confidence: 0.95,
        imageUrl: 'https://via.placeholder.com/800x600/FF6B6B/FFFFFF?text=흡연+감지',
        thumbnailUrl: 'https://via.placeholder.com/150x150/FF6B6B/FFFFFF?text=흡연',
        metadata: {
          'camera_id': 'cam_001',
          'detection_count': 1,
        },
        location: 'N1동(본부관) 1층 입구',
      ),
    ];
  }

  /// 오늘의 감지 건수 반환
  static int getTodayDetectionCount(List<DetectionEvent> events) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return events.where((event) {
      final eventDate = DateTime(
        event.timestamp.year,
        event.timestamp.month,
        event.timestamp.day,
      );
      return eventDate == today;
    }).length;
  }

  /// 최근 N개의 이벤트 반환
  static List<DetectionEvent> getRecentEvents(
    List<DetectionEvent> events,
    int count,
  ) {
    final sortedEvents = List<DetectionEvent>.from(events)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return sortedEvents.take(count).toList();
  }

  /// 라벨별 필터링
  static List<DetectionEvent> filterByLabel(
    List<DetectionEvent> events,
    List<String> labels,
  ) {
    if (labels.isEmpty) return events;
    return events.where((event) => labels.contains(event.label)).toList();
  }

  /// 날짜 범위별 필터링
  static List<DetectionEvent> filterByDateRange(
    List<DetectionEvent> events,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    return events.where((event) {
      if (startDate != null && event.timestamp.isBefore(startDate)) {
        return false;
      }
      if (endDate != null && event.timestamp.isAfter(endDate)) {
        return false;
      }
      return true;
    }).toList();
  }
}
