import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/daily_plan.dart';
import '../services/firestore_service.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final FirestoreService _firestoreService;

  NotificationService(this._firestoreService);

  Future<void> initialize() async {
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    } catch (_) {
      tz.setLocalLocation(tz.local);
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _notifications.initialize(settings);
  }

  Future<bool> requestPermissions() async {
    final androidStatus = await Permission.notification.request();
    final androidGranted = androidStatus.isGranted;

    // Request iOS permissions
    bool iosGranted = true;
    try {
      final iosImpl = _notifications.resolvePlatformSpecificImplementation();
      if (iosImpl != null) {
        iosGranted = await (iosImpl as dynamic).requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            true;
      }
    } catch (e) {
      iosGranted = true;
    }

    return androidGranted && iosGranted;
  }

  DateTime _calculateReminderTime(DateTime date, String startTime, int minutesBefore) {
    final parts = startTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final start = DateTime(date.year, date.month, date.day, hour, minute);
    return start.subtract(Duration(minutes: minutesBefore));
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> schedulePlanReminder(DailyPlan plan, int minutesBefore) async {
    final scheduledTime = _calculateReminderTime(plan.date, plan.startTime, minutesBefore);
    if (scheduledTime.isBefore(DateTime.now())) return;

    final notificationId = plan.id.hashCode;
    final payload = json.encode({
      'type': 'plan_reminder',
      'planId': plan.id,
      'date': plan.date.toIso8601String(),
    });

    await _notifications.zonedSchedule(
      notificationId,
      '${plan.title} 시작 ${minutesBefore}분 전입니다',
      '${plan.startTime} - ${plan.endTime} | 준비하세요!',
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'plan_reminder',
          '일정 알림',
          channelDescription: '일정 시작 전 알림',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> rescheduleAllPlanReminders(String userId, int minutesBefore) async {
    final now = DateTime.now();
    final rangeEnd = now.add(const Duration(days: 30));
    final plans = await _firestoreService.getDailyPlansByDateRange(userId, now, rangeEnd);

    for (final plan in plans) {
      await cancelPlanReminder(plan.id);
      await schedulePlanReminder(plan, minutesBefore);
    }
  }

  Future<void> scheduleDailySummary(String userId, String time) async {
    final timeParts = time.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    final todayPlans = await _firestoreService.getDailyPlansByDateRange(
      userId,
      DateTime.now(),
      DateTime.now(),
    );
    final count = todayPlans.length;

    await _notifications.zonedSchedule(
      999999,
      '오늘의 학습 일정',
      count > 0 ? '오늘 일정 $count개가 기다리고 있어요!' : '오늘은 가볍게 시작해볼까요?',
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_summary',
          '일일 요약',
          channelDescription: '아침 일일 요약 알림',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleEveningReview(String userId, String time) async {
    final timeParts = time.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    await _notifications.zonedSchedule(
      999998,
      '오늘의 미완료 일정',
      '아직 완료하지 않은 일정이 있어요. 오늘을 마무리해볼까요?',
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'evening_review',
          '저녁 리마인더',
          channelDescription: '미완료 일정 리마인더',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelPlanReminder(String planId) async {
    await _notifications.cancel(planId.hashCode);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  Future<void> showTestNotification() async {
    await _notifications.show(
      777777,
      '테스트 알림',
      '알림이 정상적으로 동작합니다.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test',
          '테스트',
          channelDescription: '테스트 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
