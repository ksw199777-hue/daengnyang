import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

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
  }

  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? false;
  }

  // 접종/진료 알림 예약 (3일 전, 하루 전, 1시간 전)
  Future<void> scheduleAppointmentNotification({
    required String docId,
    required String petName,
    required String title,
    required DateTime date,
  }) async {
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
