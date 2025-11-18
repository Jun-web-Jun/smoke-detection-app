import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/events_provider.dart';
import '../../models/detection_event.dart';
import '../../widgets/event_card.dart';

/// 이벤트 탭 화면
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

enum SortOption {
  dateNewest,
  dateOldest,
  confidenceHigh,
  confidenceLow,
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  String? _filterLocation;
  DateTime? _filterDateStart;
  DateTime? _filterDateEnd;
  SortOption _sortOption = SortOption.dateNewest;
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DetectionEvent> _filterEvents(List<DetectionEvent> events) {
    var filtered = events;

    // 위치 필터
    if (_filterLocation != null && _filterLocation!.isNotEmpty) {
      filtered = filtered.where((e) => e.location == _filterLocation).toList();
    }

    // 날짜 필터
    if (_filterDateStart != null) {
      filtered = filtered.where((e) {
        return e.timestamp.isAfter(_filterDateStart!) ||
            e.timestamp.isAtSameMomentAs(_filterDateStart!);
      }).toList();
    }
    if (_filterDateEnd != null) {
      final endOfDay = DateTime(
        _filterDateEnd!.year,
        _filterDateEnd!.month,
        _filterDateEnd!.day,
        23,
        59,
        59,
      );
      filtered = filtered.where((e) {
        return e.timestamp.isBefore(endOfDay) ||
            e.timestamp.isAtSameMomentAs(endOfDay);
      }).toList();
    }

    // 검색
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((e) {
        return e.id.toLowerCase().contains(query) ||
            e.labelDisplayName.toLowerCase().contains(query) ||
            (e.location?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // 정렬
    switch (_sortOption) {
      case SortOption.dateNewest:
        filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case SortOption.dateOldest:
        filtered.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        break;
      case SortOption.confidenceHigh:
        filtered.sort((a, b) => b.confidence.compareTo(a.confidence));
        break;
      case SortOption.confidenceLow:
        filtered.sort((a, b) => a.confidence.compareTo(b.confidence));
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final allEvents = ref.watch(eventsProvider);
    final filteredEvents = _filterEvents(allEvents);

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: '검색...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() {}),
              )
            : const Text('적발 이력'),
        actions: [
          // 검색 버튼
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                }
              });
            },
          ),
          // 정렬 버튼
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (option) {
              setState(() {
                _sortOption = option;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: SortOption.dateNewest,
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward, size: 20),
                    SizedBox(width: 8),
                    Text('최신순'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: SortOption.dateOldest,
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward, size: 20),
                    SizedBox(width: 8),
                    Text('오래된순'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: SortOption.confidenceHigh,
                child: Row(
                  children: [
                    Icon(Icons.trending_up, size: 20),
                    SizedBox(width: 8),
                    Text('신뢰도 높은순'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: SortOption.confidenceLow,
                child: Row(
                  children: [
                    Icon(Icons.trending_down, size: 20),
                    SizedBox(width: 8),
                    Text('신뢰도 낮은순'),
                  ],
                ),
              ),
            ],
          ),
          // 필터 버튼
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (_filterLocation != null || _filterDateStart != null || _filterDateEnd != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.cyan,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => _showFilterBottomSheet(context, allEvents),
          ),
        ],
      ),
      body: Column(
        children: [
          // 통계 헤더
          _buildStatsHeader(allEvents),

          // 필터 칩들
          if (_filterLocation != null || _filterDateStart != null || _filterDateEnd != null)
            _buildActiveFilters(),

          // 이벤트 목록
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.read(eventsProvider.notifier).refresh();
                await Future.delayed(const Duration(seconds: 1));
              },
              child: filteredEvents.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredEvents.length,
                      itemBuilder: (context, index) {
                        final event = filteredEvents[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: EventCard(
                            event: event,
                            onTap: () {
                              context.push('/events/detail/${event.id}');
                            },
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// 통계 헤더
  Widget _buildStatsHeader(List<DetectionEvent> events) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));

    final todayCount = events.where((e) {
      final eventDate = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
      return eventDate == today;
    }).length;

    final weekCount = events.where((e) => e.timestamp.isAfter(weekAgo)).length;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.today,
              label: '오늘',
              value: todayCount.toString(),
              color: Colors.blue,
            ),
            _buildStatItem(
              icon: Icons.date_range,
              label: '이번 주',
              value: weekCount.toString(),
              color: Colors.green,
            ),
            _buildStatItem(
              icon: Icons.inbox,
              label: '전체',
              value: events.length.toString(),
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 11,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 활성 필터 표시
  Widget _buildActiveFilters() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 8,
          children: [
            if (_filterLocation != null)
            Chip(
              label: Text('위치: $_filterLocation'),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => setState(() => _filterLocation = null),
              backgroundColor: Colors.cyan.withValues(alpha: 0.2),
            ),
            if (_filterDateStart != null)
              Chip(
                label: Text('시작: ${_formatDate(_filterDateStart!)}'),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => setState(() => _filterDateStart = null),
                backgroundColor: Colors.cyan.withValues(alpha: 0.2),
              ),
            if (_filterDateEnd != null)
              Chip(
                label: Text('종료: ${_formatDate(_filterDateEnd!)}'),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => setState(() => _filterDateEnd = null),
                backgroundColor: Colors.cyan.withValues(alpha: 0.2),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }

  /// 빈 상태 표시
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Colors.grey.shade700,
          ),
          const SizedBox(height: 16),
          Text(
            '적발된 내역이 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '흡연이 적발되면 여기에 표시됩니다',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  /// 필터 바텀시트 표시
  void _showFilterBottomSheet(BuildContext context, List<DetectionEvent> events) {
    // 고유 위치 목록 추출
    final locations = events
        .where((e) => e.location != null)
        .map((e) => e.location!)
        .toSet()
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '필터',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filterLocation = null;
                      _filterDateStart = null;
                      _filterDateEnd = null;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('초기화'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (locations.isNotEmpty) ...[
              const Text(
                '위치',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: locations.map((location) {
                  return _buildFilterChip(
                    label: location,
                    isSelected: _filterLocation == location,
                    onTap: () {
                      setState(() {
                        _filterLocation =
                            _filterLocation == location ? null : location;
                      });
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 24),

            // 날짜 필터
            const Text(
              '날짜',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _filterDateStart == null
                          ? '시작일'
                          : _formatDate(_filterDateStart!),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.cyan,
                      side: BorderSide(
                        color: _filterDateStart == null
                            ? Colors.grey.shade700
                            : Colors.cyan,
                      ),
                    ),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _filterDateStart ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _filterDateStart = date);
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const Text('~', style: TextStyle(color: Colors.white)),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _filterDateEnd == null
                          ? '종료일'
                          : _formatDate(_filterDateEnd!),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.cyan,
                      side: BorderSide(
                        color: _filterDateEnd == null
                            ? Colors.grey.shade700
                            : Colors.cyan,
                      ),
                    ),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _filterDateEnd ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _filterDateEnd = date);
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: Colors.cyan,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey.shade400,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.grey.shade800,
    );
  }
}
