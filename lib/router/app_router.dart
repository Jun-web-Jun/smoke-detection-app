import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/live/live_screen_simple.dart';
import '../screens/events/events_screen.dart';
import '../screens/events/event_detail_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/map/map_screen.dart';
import '../widgets/main_navigation.dart';

/// 앱 라우터 설정
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // 스플래시 화면
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),

    // 로그인 화면
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),

    // 메인 네비게이션 (4개 탭)
    ShellRoute(
      builder: (context, state, child) {
        return MainNavigation(child: child);
      },
      routes: [
        // 홈 탭
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomeScreen(),
          ),
        ),

        // 라이브 탭
        GoRoute(
          path: '/live',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: LiveScreenSimple(),
          ),
        ),

        // 이벤트 탭
        GoRoute(
          path: '/events',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: EventsScreen(),
          ),
        ),

        // 설정 탭
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsScreen(),
          ),
        ),
      ],
    ),

    // 이벤트 상세 화면
    GoRoute(
      path: '/events/detail/:id',
      builder: (context, state) {
        final eventId = state.pathParameters['id']!;
        return EventDetailScreen(eventId: eventId);
      },
    ),

    // 카메라 지도 화면
    GoRoute(
      path: '/map',
      builder: (context, state) => const MapScreen(),
    ),
  ],

  // 에러 화면
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64),
          const SizedBox(height: 16),
          Text(
            '페이지를 찾을 수 없습니다',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(state.uri.toString()),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/home'),
            child: const Text('홈으로 이동'),
          ),
        ],
      ),
    ),
  ),
);
