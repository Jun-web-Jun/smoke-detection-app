/// 앱 설정 모델
class AppSettings {
  final bool notificationsEnabled;
  final bool personDetectionEnabled;
  final bool cigaretteDetectionEnabled;
  final bool smokeDetectionEnabled;
  final bool fireDetectionEnabled;
  final double confidenceThreshold;
  final String streamUrl;

  AppSettings({
    this.notificationsEnabled = true,
    this.personDetectionEnabled = true,
    this.cigaretteDetectionEnabled = true,
    this.smokeDetectionEnabled = true,
    this.fireDetectionEnabled = true,
    this.confidenceThreshold = 0.5,
    this.streamUrl = 'http://localhost:5000/api/camera/1/stream',
  });

  /// JSON에서 AppSettings 객체 생성
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      personDetectionEnabled: json['personDetectionEnabled'] as bool? ?? true,
      cigaretteDetectionEnabled: json['cigaretteDetectionEnabled'] as bool? ?? true,
      smokeDetectionEnabled: json['smokeDetectionEnabled'] as bool? ?? true,
      fireDetectionEnabled: json['fireDetectionEnabled'] as bool? ?? true,
      confidenceThreshold: (json['confidenceThreshold'] as num?)?.toDouble() ?? 0.5,
      streamUrl: json['streamUrl'] as String? ?? 'http://localhost:8080/stream',
    );
  }

  /// AppSettings 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'notificationsEnabled': notificationsEnabled,
      'personDetectionEnabled': personDetectionEnabled,
      'cigaretteDetectionEnabled': cigaretteDetectionEnabled,
      'smokeDetectionEnabled': smokeDetectionEnabled,
      'fireDetectionEnabled': fireDetectionEnabled,
      'confidenceThreshold': confidenceThreshold,
      'streamUrl': streamUrl,
    };
  }

  /// 설정 복사 메서드
  AppSettings copyWith({
    bool? notificationsEnabled,
    bool? personDetectionEnabled,
    bool? cigaretteDetectionEnabled,
    bool? smokeDetectionEnabled,
    bool? fireDetectionEnabled,
    double? confidenceThreshold,
    String? streamUrl,
  }) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      personDetectionEnabled: personDetectionEnabled ?? this.personDetectionEnabled,
      cigaretteDetectionEnabled: cigaretteDetectionEnabled ?? this.cigaretteDetectionEnabled,
      smokeDetectionEnabled: smokeDetectionEnabled ?? this.smokeDetectionEnabled,
      fireDetectionEnabled: fireDetectionEnabled ?? this.fireDetectionEnabled,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      streamUrl: streamUrl ?? this.streamUrl,
    );
  }
}
