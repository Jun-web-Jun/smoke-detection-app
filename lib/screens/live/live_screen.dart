import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/stream_provider.dart';
import '../../providers/settings_provider.dart';

/// 라이브 스트림 탭 화면
class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key});

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  @override
  void initState() {
    super.initState();
    // 화면 진입 시 자동으로 연결 시도
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(streamStateProvider.notifier).connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    final streamState = ref.watch(streamStateProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
                  SizedBox(width: 4),
                  Text('LIVE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Text('실시간 모니터링'),
          ],
        ),
        actions: [
          // 전체화면 버튼
          IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('전체화면 모드')),
              );
            },
          ),
          // 새로고침 버튼
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(streamStateProvider.notifier).reconnect();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 카메라 정보 헤더
          _buildCameraInfoHeader(streamState),

          // 스트림 표시 영역
          Expanded(
            child: _buildStreamViewer(context, streamState, settings.streamUrl),
          ),

          // 컨트롤 패널
          _buildControlPanel(context, streamState),
        ],
      ),
    );
  }

  /// 카메라 정보 헤더
  Widget _buildCameraInfoHeader(StreamState streamState) {
    final now = DateTime.now();
    final timeString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          bottom: BorderSide(
            color: Colors.cyan.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 카메라 아이콘
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.cyan.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.videocam,
              color: Colors.cyan,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // 카메라 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '본관 1층 입구',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: streamState.status == StreamStatus.connected
                          ? Colors.green
                          : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      streamState.status == StreamStatus.connected
                          ? '정상 작동'
                          : '연결 안 됨',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.hd,
                      size: 16,
                      color: Colors.cyan,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '1080p',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 시간
          Text(
            timeString,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  /// 연결 상태 표시기
  Widget _buildConnectionStatus(StreamState streamState) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (streamState.status) {
      case StreamStatus.connected:
        statusColor = Colors.green;
        statusText = '연결됨';
        statusIcon = Icons.check_circle;
        break;
      case StreamStatus.connecting:
        statusColor = Colors.orange;
        statusText = '연결 중...';
        statusIcon = Icons.sync;
        break;
      case StreamStatus.error:
        statusColor = Colors.red;
        statusText = '오류: ${streamState.errorMessage ?? "알 수 없는 오류"}';
        statusIcon = Icons.error;
        break;
      case StreamStatus.disconnected:
      default:
        statusColor = Colors.grey;
        statusText = '연결 안 됨';
        statusIcon = Icons.cancel;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: statusColor.withOpacity(0.1),
      child: Row(
        children: [
          Icon(
            statusIcon,
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (streamState.status == StreamStatus.connecting)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
        ],
      ),
    );
  }

  /// 스트림 뷰어
  Widget _buildStreamViewer(
    BuildContext context,
    StreamState streamState,
    String streamUrl,
  ) {
    if (streamState.status == StreamStatus.connected) {
      // 실제 구현에서는 mjpeg 패키지 사용
      // return Mjpeg(
      //   isLive: true,
      //   stream: streamUrl,
      // );

      // 더미 구현: CCTV 화면 느낌
      return Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.cyan.withOpacity(0.5), width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              // CCTV 화면 배경
              Container(
                color: const Color(0xFF0A0A0A),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 대형 CCTV 아이콘
                      Icon(
                        Icons.videocam,
                        size: 120,
                        color: Colors.cyan.withOpacity(0.3),
                      ),
                      const SizedBox(height: 24),
                      // 그리드 라인 효과
                      Container(
                        width: 300,
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.cyan.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: CustomPaint(
                          painter: _GridPainter(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '스트림 준비 완료',
                        style: TextStyle(
                          color: Colors.cyan.withOpacity(0.7),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '라즈베리파이 카메라 연결 대기 중',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        streamUrl,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 좌상단: 녹화 중 표시
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                      SizedBox(width: 6),
                      Text(
                        'REC',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 우상단: 타임스탬프
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getCurrentTimestamp(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),

              // 좌하단: 카메라 ID
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'CAM-01',
                    style: TextStyle(
                      color: Colors.cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),

              // 우하단: 감지 상태
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        '정상',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (streamState.status == StreamStatus.connecting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '스트림에 연결하는 중...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    } else if (streamState.status == StreamStatus.error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '스트림 연결 실패',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              streamState.errorMessage ?? '알 수 없는 오류가 발생했습니다',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                ref.read(streamStateProvider.notifier).reconnect();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('재연결'),
            ),
          ],
        ),
      );
    } else {
      // 연결 안 됨
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '스트림이 연결되지 않았습니다',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                ref.read(streamStateProvider.notifier).connect();
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('연결'),
            ),
          ],
        ),
      );
    }
  }

  /// 컨트롤 패널
  Widget _buildControlPanel(BuildContext context, StreamState streamState) {
    final isConnected = streamState.status == StreamStatus.connected;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          top: BorderSide(
            color: Colors.cyan.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // 연결/해제 버튼
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (isConnected) {
                      ref.read(streamStateProvider.notifier).disconnect();
                    } else {
                      ref.read(streamStateProvider.notifier).connect();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConnected ? Colors.red : Colors.cyan,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: Icon(isConnected ? Icons.stop : Icons.play_arrow),
                  label: Text(
                    isConnected ? '스트림 중지' : '스트림 시작',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 스냅샷 버튼
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isConnected
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('스냅샷 저장됨'),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.cyan,
                    side: BorderSide(
                      color: isConnected ? Colors.cyan : Colors.grey,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('캡처'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 추가 정보 표시
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.cyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.cyan.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem(
                  icon: Icons.schedule,
                  label: '가동시간',
                  value: isConnected ? '00:15:32' : '--:--:--',
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.cyan.withOpacity(0.3),
                ),
                _buildInfoItem(
                  icon: Icons.speed,
                  label: 'FPS',
                  value: isConnected ? '30' : '--',
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.cyan.withOpacity(0.3),
                ),
                _buildInfoItem(
                  icon: Icons.warning_amber,
                  label: '금일 적발',
                  value: '0건',
                  valueColor: Colors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 정보 항목 위젯
  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.cyan, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// 현재 타임스탬프 가져오기
  String _getCurrentTimestamp() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }
}

/// 그리드 페인터 (CCTV 화면 효과용)
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.1)
      ..strokeWidth = 0.5;

    // 수평선
    for (var i = 0; i <= 10; i++) {
      final y = size.height * i / 10;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // 수직선
    for (var i = 0; i <= 10; i++) {
      final x = size.width * i / 10;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
