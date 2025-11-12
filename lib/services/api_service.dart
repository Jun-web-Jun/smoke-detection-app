import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/detection_event.dart';

/// API 서비스 클래스
class ApiService {
  static const String baseUrl = 'http://localhost:5000';

  /// 감지 이벤트 목록 가져오기
  static Future<List<DetectionEvent>> fetchDetectionEvents({
    int limit = 50,
    String? status,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };

      if (status != null) {
        queryParams['status'] = status;
      }

      final uri = Uri.parse('$baseUrl/api/detection/events')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> eventsJson = data['events'] ?? [];

        return eventsJson.map((eventJson) {
          return _convertToDetectionEvent(eventJson);
        }).toList();
      } else {
        throw Exception('Failed to load detection events: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching detection events: $e');
      return [];
    }
  }

  /// 서버 상태 가져오기
  static Future<Map<String, dynamic>?> fetchServerStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/status'));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load server status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching server status: $e');
      return null;
    }
  }

  /// API JSON을 DetectionEvent 모델로 변환
  static DetectionEvent _convertToDetectionEvent(Map<String, dynamic> json) {
    // API 응답 형식:
    // {
    //   "id": "uuid",
    //   "camera_id": 1,
    //   "location": "본관 1층 입구",
    //   "detected_objects": ["person", "cigarette"],
    //   "confidence": 0.95,
    //   "timestamp": "2025-10-24T16:30:00",
    //   "status": "pending",
    //   "created_at": "2025-10-24T16:39:56.037816",
    //   "image_filename": "...", // optional
    //   "image_url": "/api/detection/image/..." // optional
    // }

    final detectedObjects = List<String>.from(json['detected_objects'] ?? []);

    // 여러 객체 중 첫 번째를 라벨로 사용, 담배가 있으면 우선
    String label = 'person';
    if (detectedObjects.contains('cigarette')) {
      label = 'cigarette';
    } else if (detectedObjects.contains('smoke')) {
      label = 'smoke';
    } else if (detectedObjects.isNotEmpty) {
      label = detectedObjects.first;
    }

    // 상태 변환
    EventStatus eventStatus = EventStatus.pending;
    final statusStr = json['status'] as String? ?? 'pending';
    if (statusStr == 'processing') {
      eventStatus = EventStatus.processing;
    } else if (statusStr == 'completed') {
      eventStatus = EventStatus.completed;
    }

    // 이미지 URL 생성
    String imageUrl = '';
    String thumbnailUrl = '';
    if (json['image_url'] != null) {
      imageUrl = '$baseUrl${json['image_url']}';
      thumbnailUrl = imageUrl; // 썸네일도 같은 이미지 사용
    } else {
      // 이미지가 없으면 더미 이미지 사용
      imageUrl = 'https://via.placeholder.com/640x480?text=No+Image';
      thumbnailUrl = 'https://via.placeholder.com/150?text=No+Image';
    }

    return DetectionEvent(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String? ?? json['created_at'] as String),
      label: label,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      imageUrl: imageUrl,
      thumbnailUrl: thumbnailUrl,
      metadata: {
        'camera_id': json['camera_id'],
        'detected_objects': detectedObjects,
        'created_at': json['created_at'],
      },
      status: eventStatus,
      location: json['location'] as String?,
    );
  }

  /// 감지 이벤트 보고 (라즈베리파이용)
  static Future<bool> reportDetection({
    required int cameraId,
    required String location,
    required List<String> detectedObjects,
    required double confidence,
    String? imageBase64,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/detection/report'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'camera_id': cameraId,
          'location': location,
          'detected_objects': detectedObjects,
          'confidence': confidence,
          'timestamp': DateTime.now().toIso8601String(),
          if (imageBase64 != null) 'image_base64': imageBase64,
        }),
      );

      return response.statusCode == 201;
    } catch (e) {
      print('Error reporting detection: $e');
      return false;
    }
  }

  /// 스크린샷 캡처
  static Future<Map<String, dynamic>?> captureScreenshot(int cameraId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/camera/$cameraId/capture'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to capture screenshot: ${response.statusCode}');
      }
    } catch (e) {
      print('Error capturing screenshot: $e');
      return null;
    }
  }

  /// 스크린샷 목록 가져오기
  static Future<List<Map<String, dynamic>>> fetchScreenshots() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/screenshots'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to load screenshots: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching screenshots: $e');
      return [];
    }
  }

  /// 스크린샷 URL 생성
  static String getScreenshotUrl(String filename) {
    return '$baseUrl/api/screenshots/$filename';
  }
}
