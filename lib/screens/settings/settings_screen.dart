import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_mode_provider.dart';

/// 설정 탭 화면
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isDarkMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        children: [
          // 알림 설정 섹션
          _buildSectionHeader(context, '알림 설정'),
          _buildSwitchTile(
            context,
            icon: Icons.notifications,
            title: '푸시 알림',
            subtitle: '감지 이벤트 발생 시 알림을 받습니다',
            value: settings.notificationsEnabled,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).toggleNotifications(value);
            },
          ),

          const Divider(height: 32),

          // 감지 설정 섹션
          _buildSectionHeader(context, '감지 설정'),
          _buildSwitchTile(
            context,
            icon: Icons.smoking_rooms,
            title: '흡연 감지',
            subtitle: '흡연 행위를 자동으로 감지합니다',
            value: settings.cigaretteDetectionEnabled,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).toggleCigaretteDetection(value);
            },
          ),

          const Divider(height: 32),

          // 파라미터 설정 섹션
          _buildSectionHeader(context, '파라미터 설정'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.analytics),
                        const SizedBox(width: 12),
                        Text(
                          '신뢰도 임계값',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '감지 결과의 신뢰도가 이 값보다 높을 때만 알림을 보냅니다',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: settings.confidenceThreshold,
                            min: 0.0,
                            max: 1.0,
                            divisions: 20,
                            label: '${(settings.confidenceThreshold * 100).toInt()}%',
                            onChanged: (value) {
                              ref.read(settingsProvider.notifier).setConfidenceThreshold(value);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(settings.confidenceThreshold * 100).toInt()}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Divider(height: 32),

          // 스트림 설정 섹션
          _buildSectionHeader(context, '스트림 설정'),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('스트림 URL'),
            subtitle: Text(settings.streamUrl),
            trailing: const Icon(Icons.edit),
            onTap: () {
              _showStreamUrlDialog(context, ref, settings.streamUrl);
            },
          ),

          const Divider(height: 32),

          // 테마 설정 섹션
          _buildSectionHeader(context, '화면 설정'),
          _buildSwitchTile(
            context,
            icon: Icons.dark_mode,
            title: '다크 모드',
            subtitle: '어두운 테마를 사용합니다',
            value: isDarkMode,
            onChanged: (value) {
              ref.read(themeModeProvider.notifier).setDarkMode(value);
            },
          ),

          const Divider(height: 32),

          // 앱 정보 섹션
          _buildSectionHeader(context, '앱 정보'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('버전 정보'),
            subtitle: const Text('2.3.0+5 (앱 아이콘 적용)'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: '흡연 감지 시스템',
                applicationVersion: '2.3.0+5 (앱 아이콘 적용)',
                applicationIcon: const Icon(Icons.smoke_free, size: 48),
                children: [
                  const Text('AI 기반 실시간 흡연 감지 모니터링 시스템'),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // 설정 초기화 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: () {
                _showResetDialog(context, ref);
              },
              icon: const Icon(Icons.restore),
              label: const Text('설정 초기화'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 섹션 헤더
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  /// 스위치 타일
  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  /// 스트림 URL 변경 다이얼로그
  void _showStreamUrlDialog(BuildContext context, WidgetRef ref, String currentUrl) {
    final controller = TextEditingController(text: currentUrl);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('스트림 URL 설정'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'MJPEG 스트림 URL',
            hintText: 'http://localhost:8080/stream',
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).setStreamUrl(controller.text);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('스트림 URL이 변경되었습니다')),
              );
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  /// 설정 초기화 다이얼로그
  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('설정 초기화'),
        content: const Text('모든 설정을 기본값으로 초기화하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).resetSettings();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('설정이 초기화되었습니다')),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
  }
}
