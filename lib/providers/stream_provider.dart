import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  return StreamStateNotifier();
});

/// 스트림 상태 관리 클래스
class StreamStateNotifier extends StateNotifier<StreamState> {
  StreamStateNotifier()
      : super(StreamState(status: StreamStatus.disconnected));

  /// 연결 시작
  void connect() {
    state = state.copyWith(status: StreamStatus.connecting);

    // 더미 구현: 2초 후 연결 완료
    Future.delayed(const Duration(seconds: 2), () {
      state = state.copyWith(
        status: StreamStatus.connected,
        errorMessage: null,
      );
    });
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
