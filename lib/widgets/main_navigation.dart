import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 메인 네비게이션 위젯 (Bottom Navigation Bar)
class MainNavigation extends StatelessWidget {
  final Widget child;

  const MainNavigation({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 현재 위치 확인
        final String location = GoRouterState.of(context).uri.path;

        // 홈 화면이 아니면 홈으로 이동
        if (!location.startsWith('/home')) {
          context.go('/home');
        } else {
          // 홈 화면에서 뒤로가기 누르면 앱 종료 확인
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('앱 종료'),
              content: const Text('앱을 종료하시겠습니까?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('종료'),
                ),
              ],
            ),
          );

          if (shouldPop == true && context.mounted) {
            // 앱 종료
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (index) => _onItemTapped(index, context),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            selectedIcon: Icon(Icons.videocam),
            label: '라이브',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: '이벤트',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
      ),
    );
  }

  /// 현재 선택된 탭 인덱스 계산
  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;

    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/live')) return 1;
    if (location.startsWith('/events')) return 2;
    if (location.startsWith('/settings')) return 3;

    return 0;
  }

  /// 탭 선택 시 호출되는 함수
  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/live');
        break;
      case 2:
        context.go('/events');
        break;
      case 3:
        context.go('/settings');
        break;
    }
  }
}
