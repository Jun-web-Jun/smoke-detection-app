import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../models/detection_event.dart';
import '../../providers/events_provider.dart';
import '../../theme/app_theme.dart';

/// 적발 상세 화면
class EventDetailScreen extends ConsumerWidget {
  final String eventId;

  const EventDetailScreen({
    super.key,
    required this.eventId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider);
    final event = events.firstWhere(
      (e) => e.id == eventId,
      orElse: () => events.first,
    );

    final dateFormat = DateFormat('yyyy년 MM월 dd일 HH:mm:ss');

    return Scaffold(
      appBar: AppBar(
        title: const Text('적발 상세'),
        actions: [
          // 공유 버튼
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('공유 기능은 준비 중입니다')),
              );
            },
          ),
          // 다운로드 버튼
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('이미지가 다운로드되었습니다')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 원본 이미지
            _buildMainImage(context, event.imageUrl),

            // 이벤트 정보
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 라벨 및 신뢰도
                  Row(
                    children: [
                      Chip(
                        avatar: Icon(
                          AppTheme.getLabelIcon(event.label),
                          size: 20,
                          color: AppTheme.getLabelColor(event.label),
                        ),
                        label: Text(
                          event.labelDisplayName,
                          style: TextStyle(
                            color: AppTheme.getLabelColor(event.label),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        side: BorderSide(
                          color: AppTheme.getLabelColor(event.label),
                          width: 2,
                        ),
                        backgroundColor: AppTheme.getLabelColor(event.label).withValues(alpha: 0.1),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.analytics, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              event.confidencePercent,
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 메타데이터 카드
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '적발 정보',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),

                          // 적발 시간
                          _buildInfoRow(
                            context,
                            Icons.access_time,
                            '적발 시간',
                            dateFormat.format(event.timestamp),
                          ),
                          const Divider(height: 24),

                          // 위치
                          if (event.location != null)
                            _buildInfoRow(
                              context,
                              Icons.location_on,
                              '적발 장소',
                              event.location!,
                            ),
                          if (event.location != null)
                            const Divider(height: 24),

                          // 카메라 ID
                          if (event.metadata.containsKey('camera_id'))
                            _buildInfoRow(
                              context,
                              Icons.videocam,
                              '카메라',
                              event.metadata['camera_id'] as String,
                            ),
                          if (event.metadata.containsKey('camera_id'))
                            const Divider(height: 24),

                          // 적발 횟수
                          if (event.metadata.containsKey('detection_count'))
                            _buildInfoRow(
                              context,
                              Icons.numbers,
                              '적발 횟수',
                              '${event.metadata['detection_count']}회',
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 추가 메타데이터 카드
                  if (event.metadata.isNotEmpty)
                    Card(
                      child: ExpansionTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('추가 정보'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Event ID: ${event.id}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontFamily: 'monospace',
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Raw Confidence: ${event.confidence}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontFamily: 'monospace',
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 메인 이미지 위젯
  Widget _buildMainImage(BuildContext context, String imageUrl) {
    return Hero(
      tag: 'event_image_$eventId',
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ),
    );
  }

  /// 정보 행 위젯
  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
