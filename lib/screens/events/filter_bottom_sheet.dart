import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';

/// 필터 바텀시트
class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  // 선택된 라벨들
  final Set<String> _selectedLabels = {};

  // 날짜 범위
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // 핸들
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 헤더
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '필터',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedLabels.clear();
                          _startDate = null;
                          _endDate = null;
                        });
                      },
                      child: const Text('초기화'),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // 필터 옵션들
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    // 라벨 필터
                    Text(
                      '감지 유형',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildLabelFilters(),
                    const SizedBox(height: 24),

                    // 날짜 필터
                    Text(
                      '기간',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildDateFilters(),
                  ],
                ),
              ),

              // 적용 버튼
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: () {
                      // 필터 적용 로직 (나중에 Provider와 연동)
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '필터 적용: ${_selectedLabels.length}개 유형, '
                            '${_startDate != null || _endDate != null ? "날짜 범위 설정됨" : "모든 날짜"}',
                          ),
                        ),
                      );
                    },
                    child: const Text('적용', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 라벨 필터 위젯
  Widget _buildLabelFilters() {
    final labels = ['person', 'cigarette', 'smoke', 'fire'];
    final labelNames = ['사람', '담배', '연기', '불'];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(labels.length, (index) {
        final label = labels[index];
        final isSelected = _selectedLabels.contains(label);

        return FilterChip(
          selected: isSelected,
          label: Text(labelNames[index]),
          avatar: Icon(
            AppTheme.getLabelIcon(label),
            size: 18,
            color: isSelected
                ? AppTheme.getLabelColor(label)
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedLabels.add(label);
              } else {
                _selectedLabels.remove(label);
              }
            });
          },
          selectedColor: AppTheme.getLabelColor(label).withOpacity(0.2),
          checkmarkColor: AppTheme.getLabelColor(label),
        );
      }),
    );
  }

  /// 날짜 필터 위젯
  Widget _buildDateFilters() {
    return Column(
      children: [
        // 시작 날짜
        ListTile(
          leading: const Icon(Icons.calendar_today),
          title: const Text('시작 날짜'),
          subtitle: Text(
            _startDate != null
                ? '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}'
                : '선택 안 됨',
          ),
          trailing: _startDate != null
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                    });
                  },
                )
              : null,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _startDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() {
                _startDate = picked;
              });
            }
          },
        ),

        // 종료 날짜
        ListTile(
          leading: const Icon(Icons.event),
          title: const Text('종료 날짜'),
          subtitle: Text(
            _endDate != null
                ? '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}'
                : '선택 안 됨',
          ),
          trailing: _endDate != null
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _endDate = null;
                    });
                  },
                )
              : null,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _endDate ?? DateTime.now(),
              firstDate: _startDate ?? DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() {
                _endDate = picked;
              });
            }
          },
        ),
      ],
    );
  }
}
