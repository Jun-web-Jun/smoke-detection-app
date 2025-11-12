import 'package:flutter/material.dart';

/// 앱 테마 설정
class AppTheme {
  /// 라이트 테마
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2196F3),
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
    ),
  );

  /// 다크 테마
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2196F3),
      brightness: Brightness.dark,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
    ),
  );

  /// 라벨별 색상 매핑
  static Color getLabelColor(String label) {
    switch (label) {
      case 'person':
        return Colors.blue;
      case 'cigarette':
        return Colors.red;
      case 'smoke':
        return Colors.orange;
      case 'fire':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  /// 라벨별 아이콘 매핑
  static IconData getLabelIcon(String label) {
    switch (label) {
      case 'person':
        return Icons.person;
      case 'cigarette':
        return Icons.smoking_rooms;
      case 'smoke':
        return Icons.cloud;
      case 'fire':
        return Icons.local_fire_department;
      default:
        return Icons.help_outline;
    }
  }
}
