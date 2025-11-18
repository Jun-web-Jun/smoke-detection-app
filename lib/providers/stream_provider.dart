import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'settings_provider.dart';

/// 스트림 상태 enum
enum StreamStatus {
  disconnected,
  connecting,
  connected,
  error,
}

/// 스트림 상태 모델
class StreamState {
  final StreamStatus status;
  final String? errorMessage;

  StreamState({
    required this.status,
    this.errorMessage,
  });

  StreamState copyWith({
    StreamStatus? status,
    String? errorMessage,
  }) {
    return StreamState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 스트림 상태 Provider
final streamStateProvider = StateNotifierProvider<StreamStateNotifier, StreamState>((ref) {
  final settings = ref.watch(settingsProvider);
  return StreamStateNotifier(settings.streamUrl);
});

/// 스트림 상태 관리 클래스
class StreamStateNotifier extends StateNotifier<StreamState> {
  final String streamUrl;

  StreamStateNotifier(this.streamUrl)
      : super(StreamState(status: StreamStatus.disconnected));

  /// 연결 시작
  void connect() async {
    state = state.copyWith(status: StreamStatus.connecting);

    try {
      // 헬스 체크로 서버 연결 확인
      final healthUrl = streamUrl.replaceAll('/video_feed', '/health');
      final response = await http.get(
        Uri.parse(healthUrl),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        // 연결 성공
        state = state.copyWith(
          status: StreamStatus.connected,
          errorMessage: null,
        );
      } else {
        throw Exception('서버 응답 오류: ${response.statusCode}');
      }
    } catch (e) {
      // 연결 실패 - MJPEG 위젯이 직접 연결을 시도하도록 connected 상태로 변경
      // 실제 스트림 연결은 MJPEG 위젯에서 처리
      state = state.copyWith(
        status: StreamStatus.connected,
        errorMessage: null,
      );
    }
  }

  /// 연결 해제
  void disconnect() {
    state = state.copyWith(status: StreamStatus.disconnected);
  }

  /// 에러 상태로 변경
  void setError(String message) {
    state = state.copyWith(
      status: StreamStatus.error,
      errorMessage: message,
    );
  }

  /// 재연결
  void reconnect() {
    disconnect();
    Future.delayed(const Duration(milliseconds: 500), () {
      connect();
    });
  }
}
