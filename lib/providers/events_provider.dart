import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/detection_event.dart';
import '../services/dummy_data.dart';
import '../services/firebase_service.dart';
import 'dart:async';

/// 감지 이벤트 목록 Provider (Firebase 실시간 스트림)
final eventsProvider = StateNotifierProvider<EventsNotifier, List<DetectionEvent>>((ref) {
  return EventsNotifier();
});

/// 감지 이벤트 상태 관리 클래스
class EventsNotifier extends StateNotifier<List<DetectionEvent>> {
  StreamSubscription<List<DetectionEvent>>? _subscription;

  EventsNotifier() : super([]) {
    // Firebase 실시간 스트림 구독
    _startListening();
  }

  /// Firebase 실시간 스트림 시작
  void _startListening() {
    try {
      _subscription = FirebaseService.getEventsStream(limit: 100).listen(
        (events) {
          if (events.isNotEmpty) {
            state = events;
          } else {
            // Firebase에 데이터가 없으면 더미 데이터 사용
            state = DummyDataService.generateDummyEvents();
          }
        },
        onError: (error) {
          print('Error listening to Firebase events: $error');
          // 오류 발생 시 더미 데이터 사용
          state = DummyDataService.generateDummyEvents();
        },
      );
    } catch (e) {
      print('Error starting Firebase stream: $e');
      // Firebase 연결 실패 시 더미 데이터 사용
      state = DummyDataService.generateDummyEvents();
    }
  }

  /// 이벤트 목록 새로고침 (수동)
  Future<void> refresh() async {
    try {
      final events = await FirebaseService.getEvents(limit: 100);
      if (events.isNotEmpty) {
        state = events;
      }
    } catch (e) {
      print('Error refreshing events: $e');
    }
  }

  /// 새 이벤트 추가 (로컬 상태만 - Firebase는 자동 동기화)
  void addEvent(DetectionEvent event) {
    state = [event, ...state];
  }

  /// 이벤트 삭제
  Future<void> removeEvent(String eventId) async {
    try {
      // Firebase에서 삭제
      await FirebaseService.deleteEvent(eventId);
      // 로컬 상태 업데이트 (Firebase 스트림이 자동으로 업데이트하지만 즉시 반영)
      state = state.where((event) => event.id != eventId).toList();
    } catch (e) {
      print('Error deleting event: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// 오늘의 감지 건수 Provider
final todayDetectionCountProvider = Provider<int>((ref) {
  final events = ref.watch(eventsProvider);
  return DummyDataService.getTodayDetectionCount(events);
});

/// 최근 이벤트 Provider (최근 3건)
final recentEventsProvider = Provider<List<DetectionEvent>>((ref) {
  final events = ref.watch(eventsProvider);
  return DummyDataService.getRecentEvents(events, 3);
});

/// 실시간 모니터링 카메라 수 Provider (고유 location 기반)
final activeCamerasProvider = Provider<int>((ref) {
  final events = ref.watch(eventsProvider);
  final locations = events
      .where((e) => e.location != null)
      .map((e) => e.location!)
      .toSet();
  // 각 location마다 카메라가 있다고 가정
  return locations.length;
});

/// 금주 적발 건수 Provider (최근 7일)
final thisWeekDetectionCountProvider = Provider<int>((ref) {
  final events = ref.watch(eventsProvider);
  final now = DateTime.now();
  final weekAgo = now.subtract(const Duration(days: 7));

  return events.where((e) => e.timestamp.isAfter(weekAgo)).length;
});

/// 평균 대응시간 Provider (pending -> completed까지의 시간)
final averageResponseTimeProvider = Provider<int>((ref) {
  // 실제로는 상태 변경 시간을 추적해야 하지만,
  // 현재는 더미 데이터이므로 45초를 기본값으로 반환
  // TODO: 실제 상태 변경 로그를 추적하여 계산
  return 45;
});

/// 위치별 이벤트 통계 Provider
final locationStatsProvider = Provider<Map<String, LocationStats>>((ref) {
  final events = ref.watch(eventsProvider);
  final Map<String, LocationStats> stats = {};

  for (final event in events) {
    final location = event.location ?? '알 수 없음';
    if (!stats.containsKey(location)) {
      stats[location] = LocationStats(
        location: location,
        totalEvents: 0,
      );
    }

    final stat = stats[location]!;
    stats[location] = LocationStats(
      location: location,
      totalEvents: stat.totalEvents + 1,
    );
  }

  return stats;
});

/// 위치별 통계 데이터 클래스
class LocationStats {
  final String location;
  final int totalEvents;

  LocationStats({
    required this.location,
    required this.totalEvents,
  });

  /// 위험도 계산 (총 이벤트 건수 기반)
  String get riskLevel {
    if (totalEvents >= 5) return '높음';
    if (totalEvents >= 2) return '중간';
    return '낮음';
  }

  /// 위험도 색상
  Color get riskColor {
    if (totalEvents >= 5) return Colors.red;
    if (totalEvents >= 2) return Colors.orange;
    return Colors.green;
  }
}

/// 필터된 이벤트 Provider
final filteredEventsProvider = StateNotifierProvider<FilteredEventsNotifier, List<DetectionEvent>>((ref) {
  final events = ref.watch(eventsProvider);
  return FilteredEventsNotifier(events);
});

/// 필터된 이벤트 상태 관리 클래스
class FilteredEventsNotifier extends StateNotifier<List<DetectionEvent>> {
  FilteredEventsNotifier(List<DetectionEvent> events) : super(events);

  List<String> _selectedLabels = [];
  DateTime? _startDate;
  DateTime? _endDate;
  List<DetectionEvent> _allEvents = [];

  /// 초기 이벤트 설정
  void setEvents(List<DetectionEvent> events) {
    _allEvents = events;
    _applyFilters();
  }

  /// 라벨 필터 설정
  void setLabelFilter(List<String> labels) {
    _selectedLabels = labels;
    _applyFilters();
  }

  /// 날짜 필터 설정
  void setDateFilter(DateTime? startDate, DateTime? endDate) {
    _startDate = startDate;
    _endDate = endDate;
    _applyFilters();
  }

  /// 필터 초기화
  void clearFilters() {
    _selectedLabels = [];
    _startDate = null;
    _endDate = null;
    _applyFilters();
  }

  /// 필터 적용
  void _applyFilters() {
    List<DetectionEvent> filtered = _allEvents;

    // 라벨 필터 적용
    if (_selectedLabels.isNotEmpty) {
      filtered = DummyDataService.filterByLabel(filtered, _selectedLabels);
    }

    // 날짜 필터 적용
    filtered = DummyDataService.filterByDateRange(filtered, _startDate, _endDate);

    state = filtered;
  }
}
