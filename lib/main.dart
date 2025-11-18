import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'router/app_router.dart';
import 'providers/theme_mode_provider.dart';
import 'services/notification_service.dart';

/// 앱 진입점
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 환경 변수 로드 (에러가 발생해도 계속 진행)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('환경 변수 파일을 찾을 수 없습니다: $e');
  }

  // Firebase 초기화
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase 초기화 성공');
  } catch (e) {
    debugPrint('Firebase 초기화 실패: $e');
    debugPrint('firebase_options.dart 파일에서 Firebase 구성을 업데이트하세요');
  }

  // 알림 서비스 초기화
  try {
    await NotificationService().initialize();
    // 기본 주제 구독 (모든 흡연 감지 이벤트)
    await NotificationService().subscribeToTopic('smoking_detection');
    debugPrint('알림 서비스 초기화 성공');
  } catch (e) {
    debugPrint('알림 서비스 초기화 실패: $e');
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

/// 메인 앱 위젯
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: '흡연 감지 시스템',
      debugShowCheckedModeBanner: false,

      // 테마 설정
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,

      // 라우터 설정
      routerConfig: appRouter,

      // 로케일 설정
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
