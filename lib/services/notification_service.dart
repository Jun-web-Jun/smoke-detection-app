import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 백그라운드 메시지 핸들러 (top-level 함수여야 함)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('백그라운드 메시지 수신: ${message.messageId}');
    print('제목: ${message.notification?.title}');
    print('내용: ${message.notification?.body}');
  }
}

/// Firebase Cloud Messaging (FCM) 알림 서비스
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// 알림 서비스 초기화
  Future<void> initialize() async {
    try {
      // 알림 권한 요청
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        print('알림 권한 상태: ${settings.authorizationStatus}');
      }

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // FCM 토큰 가져오기
        _fcmToken = await _messaging.getToken();
        if (kDebugMode) {
          print('FCM 토큰: $_fcmToken');
        }

        // Firestore에 토큰 저장
        if (_fcmToken != null) {
          await _saveFcmTokenToFirestore(_fcmToken!);
        }

        // 토큰 갱신 리스너
        _messaging.onTokenRefresh.listen((newToken) {
          _fcmToken = newToken;
          _saveFcmTokenToFirestore(newToken);
          if (kDebugMode) {
            print('FCM 토큰 갱신: $newToken');
          }
        });

        // 백그라운드 메시지 핸들러 설정
        FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler);

        // 포그라운드 메시지 핸들러
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (kDebugMode) {
            print('포그라운드 메시지 수신: ${message.messageId}');
            print('제목: ${message.notification?.title}');
            print('내용: ${message.notification?.body}');
            print('데이터: ${message.data}');
          }

          // 포그라운드에서도 알림 표시
          _showForegroundNotification(message);
        });

        // 알림 클릭 시 처리
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          if (kDebugMode) {
            print('알림 클릭으로 앱 열림: ${message.messageId}');
          }
          _handleNotificationTap(message);
        });

        // 앱이 종료된 상태에서 알림으로 실행된 경우
        RemoteMessage? initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          if (kDebugMode) {
            print('앱이 종료 상태에서 알림으로 실행됨: ${initialMessage.messageId}');
          }
          _handleNotificationTap(initialMessage);
        }

        if (kDebugMode) {
          print('✅ 알림 서비스 초기화 완료');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ 알림 권한이 거부되었습니다.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 알림 서비스 초기화 실패: $e');
      }
    }
  }

  /// FCM 토큰을 Firestore에 저장
  Future<void> _saveFcmTokenToFirestore(String token) async {
    try {
      await _firestore.collection('fcm_tokens').doc(token).set({
        'token': token,
        'platform': defaultTargetPlatform.toString(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (kDebugMode) {
        print('✅ FCM 토큰 Firestore에 저장 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM 토큰 저장 실패: $e');
      }
    }
  }

  /// 포그라운드에서 알림 표시
  void _showForegroundNotification(RemoteMessage message) {
    // 실제로는 flutter_local_notifications 패키지를 사용하여
    // 시스템 알림을 표시해야 하지만, 여기서는 간단히 처리
    if (kDebugMode) {
      print('📱 포그라운드 알림 표시: ${message.notification?.title}');
    }
  }

  /// 알림 클릭 시 처리
  void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) {
      print('👆 알림 탭 처리: ${message.data}');
    }

    // 이벤트 상세 화면으로 이동
    final eventId = message.data['eventId'];
    if (eventId != null) {
      // GoRouter를 통한 네비게이션은 context가 필요하므로
      // 실제로는 StreamController나 다른 방법으로 처리
      if (kDebugMode) {
        print('이벤트 상세로 이동: $eventId');
      }
    }
  }

  /// 특정 주제(topic) 구독
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      if (kDebugMode) {
        print('✅ 주제 구독 완료: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 주제 구독 실패: $e');
      }
    }
  }

  /// 특정 주제(topic) 구독 해제
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      if (kDebugMode) {
        print('✅ 주제 구독 해제 완료: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 주제 구독 해제 실패: $e');
      }
    }
  }

  /// 테스트용: 현재 토큰 출력
  void printCurrentToken() {
    if (kDebugMode) {
      print('현재 FCM 토큰: $_fcmToken');
    }
  }
}
