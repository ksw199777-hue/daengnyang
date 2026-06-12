import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

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

    // FCM 포그라운드 메시지 처리
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final android = message.notification?.android;
      if (notification != null && android != null) {
        _plugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
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
        );
      }
    });
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
  }) async {
    if (!await _checkSetting('medication')) return;

    final now = DateTime.now();

    // 설정한 시간
    if (scheduledDate.isAfter(now)) {
      await _schedule(
        id: '${docId}_med'.hashCode.abs() % 2147483647,
        title: '투약 알림',
        body: '$petName · $title 투약 시간이에요',
        scheduledDate: scheduledDate,
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
    );
  }
}
