import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/camera_device.dart';

/// 카메라 목록 Provider
final camerasProvider = StateNotifierProvider<CamerasNotifier, List<CameraDevice>>((ref) {
  return CamerasNotifier();
});

/// 카메라 목록 관리 클래스
class CamerasNotifier extends StateNotifier<List<CameraDevice>> {
  CamerasNotifier() : super(_initialCameras);

  /// 초기 카메라 목록 (한밭대학교 본부관 위치)
  static final List<CameraDevice> _initialCameras = [
    CameraDevice(
      id: 'camera_001',
      name: 'N1동(본부관) 1층 입구',
      location: '한밭대학교 N1동',
      latitude: 36.3500,  // 한밭대학교 N1동(본부관) 정확한 좌표
      longitude: 127.3017,
      status: CameraStatus.online,
      todayDetections: 0,
      lastDetection: null,
    ),
  ];

  /// 카메라 상태 업데이트
  void updateCameraStatus(String cameraId, CameraStatus status) {
    state = state.map((camera) {
      if (camera.id == cameraId) {
        return camera.copyWith(status: status);
      }
      return camera;
    }).toList();
  }

  /// 카메라 감지 횟수 업데이트
  void updateDetections(String cameraId, int count, String lastDetection) {
    state = state.map((camera) {
      if (camera.id == cameraId) {
        return camera.copyWith(
          todayDetections: count,
          lastDetection: lastDetection,
          status: CameraStatus.warning, // 감지 발생 시 경고 상태로 변경
        );
      }
      return camera;
    }).toList();
  }

  /// 카메라 추가
  void addCamera(CameraDevice camera) {
    state = [...state, camera];
  }

  /// 카메라 제거
  void removeCamera(String cameraId) {
    state = state.where((camera) => camera.id != cameraId).toList();
  }
}
