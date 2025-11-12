/// 이벤트 상태 (임시 - 향후 제거 예정)
enum EventStatus {
  pending,
  processing,
  completed,
  confirmed,
  dismissed,
}

/// 흡연 감지 이벤트 모델
class DetectionEvent {
  final String id;
  final DateTime timestamp;
  final String label; // person, cigarette, smoke, fire
  final double confidence;
  final String imageUrl;
  final String thumbnailUrl;
  final Map<String, dynamic> metadata;
  final String? location;
  final EventStatus? status; // 임시 필드

  DetectionEvent({
    required this.id,
    required this.timestamp,
    required this.label,
    required this.confidence,
    required this.imageUrl,
    required this.thumbnailUrl,
    required this.metadata,
    this.location,
    this.status,
  });

  /// JSON에서 DetectionEvent 객체 생성
  factory DetectionEvent.fromJson(Map<String, dynamic> json) {
    return DetectionEvent(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      label: json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      imageUrl: json['imageUrl'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      metadata: json['metadata'] as Map<String, dynamic>,
    );
  }

  /// DetectionEvent 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'label': label,
      'confidence': confidence,
      'imageUrl': imageUrl,
      'thumbnailUrl': thumbnailUrl,
      'metadata': metadata,
    };
  }

  /// 라벨에 따른 한글 표시명 반환
  String get labelDisplayName {
    switch (label) {
      case 'person':
      case 'cigarette':
      case 'smoke':
        return '흡연 적발';
      case 'fire':
        return '화재 감지';
      default:
        return '흡연 적발';
    }
  }

  /// 신뢰도를 퍼센트 문자열로 반환
  String get confidencePercent {
    return '${(confidence * 100).toStringAsFixed(1)}%';
  }

  /// copyWith 메서드
  DetectionEvent copyWith({
    String? id,
    DateTime? timestamp,
    String? label,
    double? confidence,
    String? imageUrl,
    String? thumbnailUrl,
    Map<String, dynamic>? metadata,
    String? location,
    EventStatus? status,
  }) {
    return DetectionEvent(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      label: label ?? this.label,
      confidence: confidence ?? this.confidence,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      metadata: metadata ?? this.metadata,
      location: location ?? this.location,
      status: status ?? this.status,
    );
  }
}
