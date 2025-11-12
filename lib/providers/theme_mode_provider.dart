import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 테마 모드 Provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, bool>((ref) {
  return ThemeModeNotifier();
});

/// 테마 모드 상태 관리 클래스 (true = dark mode, false = light mode)
class ThemeModeNotifier extends StateNotifier<bool> {
  ThemeModeNotifier() : super(false);

  /// 테마 모드 토글
  void toggle() {
    state = !state;
  }

  /// 다크 모드 설정
  void setDarkMode(bool isDark) {
    state = isDark;
  }
}
