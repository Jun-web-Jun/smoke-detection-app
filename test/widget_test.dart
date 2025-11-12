import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smoke_detection_app/main.dart';
import 'package:smoke_detection_app/models/detection_event.dart';
import 'package:smoke_detection_app/models/app_settings.dart';
import 'package:smoke_detection_app/widgets/event_card.dart';

void main() {
  /// 앱 시작 테스트
  testWidgets('App starts and shows splash screen', (WidgetTester tester) async {
    // 앱 빌드
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    // 스플래시 화면이 표시되는지 확인
    expect(find.byIcon(Icons.smoke_free), findsOneWidget);
    expect(find.text('흡연 감지 시스템'), findsOneWidget);
  });

  /// EventCard 위젯 테스트
  testWidgets('EventCard displays event information correctly', (WidgetTester tester) async {
    // 테스트용 이벤트 생성
    final testEvent = DetectionEvent(
      id: 'test_001',
      timestamp: DateTime.now(),
      label: 'cigarette',
      confidence: 0.95,
      imageUrl: 'https://via.placeholder.com/800x600',
      thumbnailUrl: 'https://via.placeholder.com/150x150',
      metadata: {
        'location': '테스트 위치',
        'camera_id': 'cam_test',
        'detection_count': 1,
      },
    );

    // EventCard 빌드
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventCard(event: testEvent),
        ),
      ),
    );

    // 라벨이 표시되는지 확인
    expect(find.text('담배'), findsOneWidget);

    // 신뢰도가 표시되는지 확인
    expect(find.text('95.0%'), findsOneWidget);

    // 위치 정보가 표시되는지 확인
    expect(find.text('테스트 위치'), findsOneWidget);
  });

  /// DetectionEvent 모델 테스트
  test('DetectionEvent model correctly converts to/from JSON', () {
    final event = DetectionEvent(
      id: 'test_001',
      timestamp: DateTime.parse('2024-01-01T12:00:00'),
      label: 'smoke',
      confidence: 0.87,
      imageUrl: 'https://example.com/image.jpg',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      metadata: {
        'location': '테스트',
        'camera_id': 'cam_001',
      },
    );

    // JSON으로 변환
    final json = event.toJson();

    // JSON에서 다시 객체 생성
    final fromJson = DetectionEvent.fromJson(json);

    // 값이 올바르게 변환되었는지 확인
    expect(fromJson.id, event.id);
    expect(fromJson.label, event.label);
    expect(fromJson.confidence, event.confidence);
    expect(fromJson.metadata['location'], event.metadata['location']);
  });

  /// labelDisplayName 테스트
  test('DetectionEvent returns correct Korean label names', () {
    final labels = {
      'person': '사람',
      'cigarette': '담배',
      'smoke': '연기',
      'fire': '불',
    };

    labels.forEach((label, expected) {
      final event = DetectionEvent(
        id: 'test',
        timestamp: DateTime.now(),
        label: label,
        confidence: 0.9,
        imageUrl: '',
        thumbnailUrl: '',
        metadata: {},
      );

      expect(event.labelDisplayName, expected);
    });
  });

  /// confidencePercent 테스트
  test('DetectionEvent formats confidence as percentage', () {
    final event = DetectionEvent(
      id: 'test',
      timestamp: DateTime.now(),
      label: 'smoke',
      confidence: 0.8765,
      imageUrl: '',
      thumbnailUrl: '',
      metadata: {},
    );

    expect(event.confidencePercent, '87.7%');
  });

  /// AppSettings 모델 테스트
  test('AppSettings copyWith works correctly', () {
    final settings = AppSettings(
      notificationsEnabled: true,
      confidenceThreshold: 0.5,
    );

    final updated = settings.copyWith(
      notificationsEnabled: false,
      confidenceThreshold: 0.7,
    );

    expect(updated.notificationsEnabled, false);
    expect(updated.confidenceThreshold, 0.7);
    // 다른 값들은 그대로 유지되어야 함
    expect(updated.personDetectionEnabled, settings.personDetectionEnabled);
  });
}
