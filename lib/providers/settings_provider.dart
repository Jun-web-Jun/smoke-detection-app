import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../services/notification_service.dart';

/// 앱 설정 Provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

/// 앱 설정 상태 관리 클래스
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(AppSettings());

  /// 알림 설정 토글
  void toggleNotifications(bool value) async {
    state = state.copyWith(notificationsEnabled: value);

    // FCM 주제 구독/해제
    final notificationService = NotificationService();
    if (value) {
      await notificationService.subscribeToTopic('smoking_detection');
    } else {
      await notificationService.unsubscribeFromTopic('smoking_detection');
    }

    // SharedPreferences에 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
  }

  /// 사람 감지 토글
  void togglePersonDetection(bool value) {
    state = state.copyWith(personDetectionEnabled: value);
  }

  /// 담배 감지 토글
  void toggleCigaretteDetection(bool value) {
    state = state.copyWith(cigaretteDetectionEnabled: value);
  }

  /// 연기 감지 토글
  void toggleSmokeDetection(bool value) {
    state = state.copyWith(smokeDetectionEnabled: value);
  }

  /// 불 감지 토글
  void toggleFireDetection(bool value) {
    state = state.copyWith(fireDetectionEnabled: value);
  }

  /// 신뢰도 임계값 설정
  void setConfidenceThreshold(double value) {
    state = state.copyWith(confidenceThreshold: value);
  }

  /// 스트림 URL 설정
  void setStreamUrl(String url) {
    state = state.copyWith(streamUrl: url);
  }

  /// 설정 초기화
  void resetSettings() {
    state = AppSettings();
  }
}
