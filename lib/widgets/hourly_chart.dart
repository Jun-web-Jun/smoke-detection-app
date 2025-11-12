import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/detection_event.dart';

/// 시간대별 흡연 감지 차트
class HourlyChart extends StatelessWidget {
  final List<DetectionEvent> events;

  const HourlyChart({
    super.key,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    final hourlyData = _calculateHourlyData();
    final maxCount = hourlyData.values.fold<int>(0, (max, count) => count > max ? count : max);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bar_chart,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '시간대별 감지 현황',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Text(
                  '(최근 24시간)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxCount > 0 ? (maxCount + 2).toDouble() : 5,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.blueGrey,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${group.x.toInt()}시\n${rod.toY.toInt()}건',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final hour = value.toInt();
                          // 3시간 간격으로만 표시
                          if (hour % 3 == 0) {
                            return Text(
                              '${hour}시',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withValues(alpha: 0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(
                    show: false,
                  ),
                  barGroups: hourlyData.entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(),
                          color: _getBarColor(context, entry.value),
                          width: 12,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 시간대별 데이터 계산
  Map<int, int> _calculateHourlyData() {
    final now = DateTime.now();
    final last24Hours = now.subtract(const Duration(hours: 24));

    // 0-23시 초기화
    final hourlyCount = <int, int>{};
    for (var i = 0; i < 24; i++) {
      hourlyCount[i] = 0;
    }

    // 최근 24시간 이벤트만 필터링
    final recentEvents = events.where((event) {
      return event.timestamp.isAfter(last24Hours);
    });

    // 시간대별 카운트
    for (final event in recentEvents) {
      final hour = event.timestamp.hour;
      hourlyCount[hour] = (hourlyCount[hour] ?? 0) + 1;
    }

    return hourlyCount;
  }

  /// 막대 색상 결정
  Color _getBarColor(BuildContext context, int count) {
    if (count == 0) {
      return Colors.grey.shade300;
    } else if (count <= 2) {
      return Colors.green;
    } else if (count <= 5) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
