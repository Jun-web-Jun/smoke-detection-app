/// 카메라 장치 정보 모델
class CameraDevice {
  final String id;
  final String name;
  final String location;
  final double latitude;
  final double longitude;
  final CameraStatus status;
  final int todayDetections;
  final String? lastDetection;

  CameraDevice({
    required this.id,
    required this.name,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.todayDetections = 0,
    this.lastDetection,
  });

  CameraDevice copyWith({
    String? id,
    String? name,
    String? location,
    double? latitude,
    double? longitude,
    CameraStatus? status,
    int? todayDetections,
    String? lastDetection,
  }) {
    return CameraDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      todayDetections: todayDetections ?? this.todayDetections,
      lastDetection: lastDetection ?? this.lastDetection,
    );
  }
}

/// 카메라 상태
enum CameraStatus {
  online,   // 온라인 (정상)
  offline,  // 오프라인 (연결 끊김)
  warning,  // 경고 (최근 감지 발생)
}
