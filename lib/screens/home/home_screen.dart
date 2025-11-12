import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/events_provider.dart';
import '../../widgets/event_card.dart';
import '../../widgets/hourly_chart.dart';

/// 홈 탭 화면
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayCount = ref.watch(todayDetectionCountProvider);
    final recentEvents = ref.watch(recentEventsProvider);
    final activeCameras = ref.watch(activeCamerasProvider);
    final thisWeekCount = ref.watch(thisWeekDetectionCountProvider);
    final avgResponseTime = ref.watch(averageResponseTimeProvider);
    final locationStats = ref.watch(locationStatsProvider);
    final allEvents = ref.watch(eventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('홈'),
        actions: [
          // 테마 전환 버튼 (나중에 구현)
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () {
              // 테마 전환 로직
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // 새로고침 로직
          ref.read(eventsProvider.notifier).refresh();
          await Future.delayed(const Duration(seconds: 1));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 오늘의 감지 건수 카드
              _buildTodayCountCard(context, todayCount),
              const SizedBox(height: 16),

              // 실시간 통계 카드들
              _buildStatisticsCards(context, activeCameras, thisWeekCount, avgResponseTime),
              const SizedBox(height: 16),

              // 시간대별 차트
              HourlyChart(events: allEvents),
              const SizedBox(height: 16),

              // 금연구역 현황
              _buildZoneStatus(context, locationStats),
              const SizedBox(height: 24),

              // 빠른 액세스 버튼들
              _buildQuickAccessButtons(context),
              const SizedBox(height: 24),

              // 최근 적발 섹션
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '최근 적발 이력',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  TextButton(
                    onPressed: () {
                      // 적발 이력 탭으로 이동
                      context.go('/events');
                    },
                    child: const Text('전체 보기'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 최근 3건의 적발 카드
              if (recentEvents.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '최근 적발된 내역이 없습니다',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...recentEvents.map((event) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: EventCard(
                        event: event,
                        onTap: () {
                          // 적발 상세 페이지로 이동
                          context.push('/events/detail/${event.id}');
                        },
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  /// 오늘의 감지 건수 카드
  Widget _buildTodayCountCard(BuildContext context, int count) {
    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.secondaryContainer,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.today,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  '오늘의 감지 건수',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '$count',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '건',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// 실시간 통계 카드들
  Widget _buildStatisticsCards(BuildContext context, int activeCameras, int thisWeekCount, int avgResponseTime) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.access_time,
            label: '실시간 모니터링',
            value: activeCameras.toString(),
            unit: '대',
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.warning_amber,
            label: '금주 적발',
            value: thisWeekCount.toString(),
            unit: '건',
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.trending_up,
            label: '평균 대응시간',
            value: avgResponseTime.toString(),
            unit: '초',
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  /// 금연구역 현황
  Widget _buildZoneStatus(BuildContext context, Map<String, dynamic> locationStats) {
    // 위치별로 정렬 (본관, 주차장, 후문 순)
    final sortedLocations = ['본관 1층 입구', '주차장', '후문'];
    final zones = sortedLocations.where((loc) => locationStats.containsKey(loc)).toList();

    // 데이터가 없으면 기본 메시지 표시
    if (zones.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '금연구역 현황',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  '금연구역 데이터가 없습니다',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '금연구역 현황',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        ...zones.map((location) {
          final stats = locationStats[location]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ZoneStatusCard(
              zoneName: location,
              cameraCount: 1, // 각 위치마다 카메라 1대로 가정
              status: '정상',
              riskLevel: stats.riskLevel,
              riskColor: stats.riskColor,
            ),
          );
        }),
      ],
    );
  }

  /// 빠른 액세스 버튼들
  Widget _buildQuickAccessButtons(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _QuickAccessButton(
                icon: Icons.videocam,
                label: '라이브 보기',
                color: Colors.red,
                onTap: () {
                  context.go('/live');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickAccessButton(
                icon: Icons.warning_amber,
                label: '적발 이력',
                color: Colors.blue,
                onTap: () {
                  context.go('/events');
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickAccessButton(
                icon: Icons.map,
                label: '카메라 위치',
                color: Colors.cyan,
                onTap: () {
                  context.push('/map');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickAccessButton(
                icon: Icons.settings,
                label: '설정',
                color: Colors.green,
                onTap: () {
                  context.go('/settings');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 빠른 액세스 버튼 위젯
class _QuickAccessButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 통계 카드 위젯
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    unit,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 금연구역 상태 카드 위젯
class _ZoneStatusCard extends StatelessWidget {
  final String zoneName;
  final int cameraCount;
  final String status;
  final String riskLevel;
  final Color riskColor;

  const _ZoneStatusCard({
    required this.zoneName,
    required this.cameraCount,
    required this.status,
    required this.riskLevel,
    required this.riskColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 아이콘
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: riskColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.location_on,
                color: riskColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zoneName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.videocam,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$cameraCount대',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 위험도 뱃지
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: riskColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                riskLevel,
                style: TextStyle(
                  color: riskColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
