import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/detection_event.dart';
import '../theme/app_theme.dart';

/// 이벤트 카드 위젯
class EventCard extends StatelessWidget {
  final DetectionEvent event;
  final VoidCallback? onTap;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm:ss');
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 썸네일 이미지
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: event.thumbnailUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 80,
                    height: 80,
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 80,
                    height: 80,
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 이벤트 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 라벨 칩
                    Row(
                      children: [
                        Chip(
                          avatar: Icon(
                            AppTheme.getLabelIcon(event.label),
                            size: 16,
                            color: AppTheme.getLabelColor(event.label),
                          ),
                          label: Text(
                            event.labelDisplayName,
                            style: TextStyle(
                              color: AppTheme.getLabelColor(event.label),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          side: BorderSide(
                            color: AppTheme.getLabelColor(event.label),
                          ),
                          backgroundColor: AppTheme.getLabelColor(event.label).withValues(alpha: 0.1),
                        ),
                        const SizedBox(width: 8),
                        // 신뢰도
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            event.confidencePercent,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 시간 정보
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${dateFormat.format(event.timestamp)} ${timeFormat.format(event.timestamp)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // 위치 정보
                    if (event.location != null)
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.location!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // 화살표 아이콘
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
