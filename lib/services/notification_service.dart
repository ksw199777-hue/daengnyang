import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:daengnyang/screens/community/community_screen.dart';
import 'package:daengnyang/screens/chat/chat_screen.dart';
import 'package:daengnyang/screens/health/health_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('[알림 탭] onDidReceiveNotificationResponse - payload: ${response.payload}');
        if (response.payload == null) {
          print('[알림 탭] payload가 null → 네비게이션 불가');
          return;
        }
        final data = Map<String, dynamic>.from(
          jsonDecode(response.payload!) as Map,
        );
        print('[알림 탭] 파싱된 data: $data');
        _handleNavigation(data);
      },
    );

    const channel = AndroidNotificationChannel(
      'high_importance_channel',
      '이제댕냥 알림',
      description: '반려동물 건강 관리 알림',
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // FCM 포그라운드 메시지 처리 (data-only 메시지)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.data['title'];
      final body = message.data['body'];
      print('[FCM 포그라운드] 수신 - data: ${message.data}');
      if (title == null || body == null) {
        print('[FCM 포그라운드] title 또는 body 없음 → 알림 스킵');
        return;
      }
      _plugin.show(
        message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            '이제댕냥 알림',
            channelDescription: '반려동물 건강 관리 알림',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: jsonEncode(message.data), // 탭 시 _handleNavigation에 전달
      );
    });

    // 백그라운드 상태에서 FCM 알림 탭 (data-only에서는 실질적으로 미사용)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[FCM 백그라운드 탭] data: ${message.data}');
      _handleNavigation(message.data);
    });
  }

  // 앱 종료 상태에서 알림 탭 → HomeScreen.initState에서 호출
  Future<void> checkInitialMessage() async {
    // 1) FCM 네이티브 알림으로 앱이 실행된 경우
    final fcmMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (fcmMessage != null) {
      print('[종료→탭] FCM getInitialMessage - data: ${fcmMessage.data}');
      _handleNavigation(fcmMessage.data);
      return;
    }

    // 2) flutter_local_notifications(백그라운드 핸들러)으로 앱이 실행된 경우
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    print('[종료→탭] didNotificationLaunchApp: ${launchDetails?.didNotificationLaunchApp}');
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails?.notificationResponse?.payload;
      print('[종료→탭] 로컬 알림 payload: $payload');
      if (payload != null) {
        final data = Map<String, dynamic>.from(jsonDecode(payload) as Map);
        _handleNavigation(data);
      }
    }
  }

  Future<void> _handleNavigation(Map<String, dynamic> data) async {
    print('[_handleNavigation] 진입 - data: $data');

    final type = data['type'] as String?;
    print('[_handleNavigation] type: $type');
    if (type == null) {
      print('[_handleNavigation] type null → 종료');
      return;
    }

    final navigator = _navigatorKey?.currentState;
    print('[_handleNavigation] navigatorKey: $_navigatorKey / currentState: $navigator');
    if (navigator == null) {
      print('[_handleNavigation] navigator null → 종료');
      return;
    }

    switch (type) {
      case 'comment':
      case 'reply':
        final postId = data['postId'] as String?;
        print('[_handleNavigation] postId: $postId');
        if (postId == null) {
          print('[_handleNavigation] postId null → 종료');
          return;
        }
        print('[_handleNavigation] → PostDetailScreen($postId)');
        navigator.push(MaterialPageRoute(
          builder: (_) => PostDetailScreen(postId: postId),
        ));

      case 'chat':
        final chatId = data['chatId'] as String?;
        print('[_handleNavigation] chatId: $chatId');
        if (chatId == null) {
          print('[_handleNavigation] chatId null → 종료');
          return;
        }

        final chatDoc = await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .get();
        print('[_handleNavigation] chatDoc.exists: ${chatDoc.exists}');
        if (!chatDoc.exists) return;

        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final participants =
            List<String>.from(chatDoc.data()?['participants'] ?? []);
        final otherUserId = participants.firstWhere(
          (id) => id != currentUserId,
          orElse: () => '',
        );
        print('[_handleNavigation] otherUserId: $otherUserId');
        if (otherUserId.isEmpty) return;

        final otherUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(otherUserId)
            .get();
        final otherNickname =
            otherUserDoc.data()?['nickname'] as String? ?? '';
        final postTitle = chatDoc.data()?['postTitle'] as String? ?? '';
        print('[_handleNavigation] → ChatScreen(chatId: $chatId, otherNickname: $otherNickname)');

        navigator.push(MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            otherUserId: otherUserId,
            otherNickname: otherNickname,
            postTitle: postTitle,
          ),
        ));

      case 'medication':
        final petId = data['petId'] as String?;
        print('[_handleNavigation] petId: $petId');
        print('[_handleNavigation] → HealthScreen(initialPetId: $petId)');
        navigator.push(MaterialPageRoute(
          builder: (_) => HealthScreen(initialPetId: petId),
        ));

      default:
        print('[_handleNavigation] 알 수 없는 type: $type → 종료');
    }
  }

  Future<bool> requestPermission() async {
    // FCM 권한
    await FirebaseMessaging.instance.requestPermission();

    // 로컬 알림 권한 (Android)
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? false;
  }

  // FCM 토큰 Firestore에 저장
  Future<void> registerFcmToken() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'fcmToken': token,
    });

    // 토큰 갱신 리스너
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      FirebaseFirestore.instance.collection('users').doc(userId).update({
        'fcmToken': newToken,
      });
    });
  }

  // 알림 설정 확인 (꺼져있으면 false)
  Future<bool> _checkSetting(String key) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return true;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    final settings =
        doc.data()?['notificationSettings'] as Map<String, dynamic>?;
    if (settings == null) return true;
    return settings[key] != false;
  }

  // 접종/진료 알림 예약 (3일 전, 하루 전, 1시간 전)
  Future<void> scheduleAppointmentNotification({
    required String docId,
    required String petName,
    required String title,
    required DateTime date,
  }) async {
    if (!await _checkSetting('appointment')) return;

    final now = DateTime.now();

    // 3일 전
    final threeDaysBefore = date.subtract(const Duration(days: 3));
    if (threeDaysBefore.isAfter(now)) {
      await _schedule(
        id: '${docId}_3d'.hashCode.abs() % 2147483647,
        title: '일정 알림',
        body: '$petName · $title 일정이 3일 남았어요',
        scheduledDate: threeDaysBefore,
      );
    }

    // 하루 전
    final oneDayBefore = date.subtract(const Duration(days: 1));
    if (oneDayBefore.isAfter(now)) {
      await _schedule(
        id: '${docId}_1d'.hashCode.abs() % 2147483647,
        title: '일정 알림',
        body: '$petName · 내일 $title 일정이 있어요',
        scheduledDate: oneDayBefore,
      );
    }

    // 1시간 전
    final oneHourBefore = date.subtract(const Duration(hours: 1));
    if (oneHourBefore.isAfter(now)) {
      await _schedule(
        id: '${docId}_1h'.hashCode.abs() % 2147483647,
        title: '일정 알림',
        body: '$petName · $title 일정 1시간 전이에요',
        scheduledDate: oneHourBefore,
      );
    }
  }

  // 투약 알림 예약 (설정 시간, 10분 후)
  Future<void> scheduleMedicationNotification({
    required String docId,
    required String petName,
    required String title,
    required DateTime scheduledDate,
    required String petId,
  }) async {
    if (!await _checkSetting('medication')) return;

    final now = DateTime.now();
    final payload = jsonEncode({'type': 'medication', 'petId': petId});

    // 설정한 시간
    if (scheduledDate.isAfter(now)) {
      await _schedule(
        id: '${docId}_med'.hashCode.abs() % 2147483647,
        title: '투약 알림',
        body: '$petName · $title 투약 시간이에요',
        scheduledDate: scheduledDate,
        payload: payload,
      );
    }

    // 10분 후 (완료 확인)
    final tenMinutesLater = scheduledDate.add(const Duration(minutes: 10));
    if (tenMinutesLater.isAfter(now)) {
      await _schedule(
        id: '${docId}_med_check'.hashCode.abs() % 2147483647,
        title: '투약 확인',
        body: '$petName · $title 투약 완료하셨나요?',
        scheduledDate: tenMinutesLater,
        payload: payload,
      );
    }
  }

  // 생일 알림 예약 (하루 전)
  Future<void> scheduleBirthdayNotification({
    required String petId,
    required String petName,
    required DateTime birthday,
  }) async {
    if (!await _checkSetting('birthday')) return;

    final now = DateTime.now();
    final oneDayBefore = birthday.subtract(const Duration(days: 1));
    if (oneDayBefore.isAfter(now)) {
      await _schedule(
        id: '${petId}_birthday'.hashCode.abs() % 2147483647,
        title: '생일 알림',
        body: '$petName의 생일이 내일이에요 🎂',
        scheduledDate: oneDayBefore,
      );
    }
  }

  // 기타 일정 알림 예약 (하루 전)
  Future<void> scheduleEtcNotification({
    required String docId,
    required String petName,
    required String title,
    required DateTime date,
  }) async {
    final now = DateTime.now();
    final oneDayBefore = date.subtract(const Duration(days: 1));
    if (oneDayBefore.isAfter(now)) {
      await _schedule(
        id: '${docId}_etc'.hashCode.abs() % 2147483647,
        title: '일정 알림',
        body: '$petName · 내일 일정이 있어요',
        scheduledDate: oneDayBefore,
      );
    }
  }

  // 알림 취소 (일정 삭제 시)
  Future<void> cancelAppointmentNotifications(String docId) async {
    await _plugin.cancel('${docId}_3d'.hashCode.abs() % 2147483647);
    await _plugin.cancel('${docId}_1d'.hashCode.abs() % 2147483647);
    await _plugin.cancel('${docId}_1h'.hashCode.abs() % 2147483647);
  }

  Future<void> cancelMedicationNotifications(String docId) async {
    await _plugin.cancel('${docId}_med'.hashCode.abs() % 2147483647);
    await _plugin.cancel('${docId}_med_check'.hashCode.abs() % 2147483647);
  }

  Future<void> cancelEtcNotification(String docId) async {
    await _plugin.cancel('${docId}_etc'.hashCode.abs() % 2147483647);
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          '이제댕냥 알림',
          channelDescription: '반려동물 건강 관리 알림',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }
}
