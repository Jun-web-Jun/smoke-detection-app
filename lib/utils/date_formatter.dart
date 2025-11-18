import 'package:intl/intl.dart';

/// 날짜 포맷 유틸리티 클래스
class DateFormatter {
  /// 상대 시간 표시 (예: "방금 전", "5분 전", "2시간 전")
  static String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return DateFormat('yyyy-MM-dd').format(dateTime);
    }
  }

  /// 시간만 표시 (예: "14:30:25")
  static String formatTime(DateTime dateTime) {
    return DateFormat('HH:mm:ss').format(dateTime);
  }

  /// 날짜만 표시 (예: "2024-01-15")
  static String formatDate(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

  /// 날짜와 시간 모두 표시 (예: "2024-01-15 14:30:25")
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }

  /// 한글 날짜 표시 (예: "2024년 1월 15일")
  static String formatKoreanDate(DateTime dateTime) {
    return DateFormat('yyyy년 MM월 dd일').format(dateTime);
  }

  /// 한글 날짜와 시간 표시 (예: "2024년 1월 15일 14:30")
  static String formatKoreanDateTime(DateTime dateTime) {
    return DateFormat('yyyy년 MM월 dd일 HH:mm').format(dateTime);
  }
}
