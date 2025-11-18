import 'package:flutter/material.dart';

/// MJPEG 스트림 뷰어 위젯
/// 웹에서 MJPEG 스트림을 표시합니다
class MjpegViewer extends StatelessWidget {
  final String streamUrl;
  final bool showOverlay;
  final String? cameraId;
  final String? location;

  const MjpegViewer({
    super.key,
    required this.streamUrl,
    this.showOverlay = true,
    this.cameraId,
    this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // MJPEG 스트림 이미지
        Image.network(
          streamUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.cyan),
                  const SizedBox(height: 16),
                  Text(
                    '스트림 로딩 중...',
                    style: TextStyle(
                      color: Colors.cyan.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: const Color(0xFF0A0A0A),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.withOpacity(0.7),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '스트림 로드 실패',
                      style: TextStyle(
                        color: Colors.red.withOpacity(0.7),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
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
            );
          },
        ),

        // 오버레이 (REC, 타임스탬프 등)
        if (showOverlay) ...[
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
              child: StreamBuilder<DateTime>(
                stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
                builder: (context, snapshot) {
                  final now = snapshot.data ?? DateTime.now();
                  final timeString = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
                      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
                  return Text(
                    timeString,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  );
                },
              ),
            ),
          ),

          // 좌하단: 카메라 ID
          if (cameraId != null)
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  cameraId!,
                  style: const TextStyle(
                    color: Colors.cyan,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),

          // 좌하단 (카메라 ID 아래): 위치
          if (location != null)
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      location!,
                      style: const TextStyle(
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
      ],
    );
  }
}
