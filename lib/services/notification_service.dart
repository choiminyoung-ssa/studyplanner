import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/daily_plan.dart';
import '../services/firestore_service.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final FirestoreService _firestoreService;

  NotificationService(this._firestoreService);

  Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
    if (kIsWeb) return AndroidScheduleMode.inexactAllowWhileIdle;
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl == null) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }

    try {
      final canScheduleExact = await androidImpl
          .canScheduleExactNotifications();
      if (canScheduleExact == true) {
        return AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (e) {
      debugPrint('Exact alarm check failed: $e');
    }

    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> _safeZonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails details,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    if (kIsWeb) return;
    final scheduleMode = await _resolveAndroidScheduleMode();

    Future<void> attempt(AndroidScheduleMode mode) async {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        payload: payload,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    }

    try {
      await attempt(scheduleMode);
    } catch (e) {
      debugPrint('Notification schedule failed ($scheduleMode): $e');
      if (scheduleMode == AndroidScheduleMode.exactAllowWhileIdle) {
        try {
          await attempt(AndroidScheduleMode.inexactAllowWhileIdle);
        } catch (fallbackError) {
          debugPrint('Notification schedule fallback failed: $fallbackError');
        }
      }
    }
  }

  Future<void> initialize() async {
    if (kIsWeb) return;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.local);

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notifications.initialize(settings);

    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        'plan_reminder',
        '일정 시작 알림',
        description: '일정 시작 전에 알려드리는 알림',
        importance: Importance.high,
      ),
    );
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        'daily_summary',
        '일일 요약',
        description: '아침 요약 알림',
        importance: Importance.defaultImportance,
      ),
    );
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        'evening_review',
        '저녁 리마인더',
        description: '미완료 일정 리마인더',
        importance: Importance.defaultImportance,
      ),
    );
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        'test',
        '테스트',
        description: '알림 테스트 채널',
        importance: Importance.high,
      ),
    );
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    final androidStatus = await Permission.notification.request();
    final androidGranted = androidStatus.isGranted;

    // Request iOS permissions
    bool iosGranted = true;
    try {
      final iosImpl = _notifications.resolvePlatformSpecificImplementation();
      if (iosImpl != null) {
        iosGranted =
            await (iosImpl as dynamic).requestPermissions(
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

  DateTime _calculateReminderTime(
    DateTime date,
    String startTime,
    int minutesBefore,
  ) {
    final parts = startTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final start = DateTime(date.year, date.month, date.day, hour, minute);
    return start.subtract(Duration(minutes: minutesBefore));
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> schedulePlanReminder(DailyPlan plan, int minutesBefore) async {
    if (kIsWeb) return;
    final scheduledTime = _calculateReminderTime(
      plan.date,
      plan.startTime,
      minutesBefore,
    );
    if (scheduledTime.isBefore(DateTime.now())) return;

    final notificationId = plan.id.hashCode;
    final payload = json.encode({
      'type': 'plan_reminder',
      'planId': plan.id,
      'date': plan.date.toIso8601String(),
    });

    await _safeZonedSchedule(
      id: notificationId,
      title: '${plan.title} 곧 시작해요',
      body: '$minutesBefore분 후 시작 • ${plan.startTime} ~ ${plan.endTime}',
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      details: const NotificationDetails(
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
    );
  }

  Future<void> rescheduleAllPlanReminders(
    String userId,
    int minutesBefore,
  ) async {
    if (kIsWeb) return;
    final now = DateTime.now();
    final rangeEnd = now.add(const Duration(days: 30));
    final plans = await _firestoreService.getDailyPlansByDateRange(
      userId,
      now,
      rangeEnd,
    );

    for (final plan in plans) {
      await cancelPlanReminder(plan.id);
      await schedulePlanReminder(plan, minutesBefore);
    }
  }

  Future<void> scheduleDailySummary(String userId, String time) async {
    if (kIsWeb) return;
    final timeParts = time.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    final todayPlans = await _firestoreService.getDailyPlansByDateRange(
      userId,
      DateTime.now(),
      DateTime.now(),
    );
    final count = todayPlans.length;

    await _safeZonedSchedule(
      id: 999999,
      title: '오늘의 학습 일정',
      body: count > 0 ? '오늘 일정 $count개가 있어요. 하루를 시작해볼까요?' : '오늘은 가볍게 시작해볼까요?',
      scheduledDate: _nextInstanceOfTime(hour, minute),
      details: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_summary',
          '일일 요약',
          channelDescription: '아침 일일 요약 알림',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleEveningReview(String userId, String time) async {
    if (kIsWeb) return;
    final timeParts = time.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    final todayPlans = await _firestoreService.getDailyPlansByDateRange(
      userId,
      DateTime.now(),
      DateTime.now(),
    );
    final remaining = todayPlans.where((plan) => !plan.isCompleted).length;
    final body = remaining > 0
        ? '미완료 일정 $remaining개가 있어요. 오늘을 마무리해볼까요?'
        : '오늘 일정 완료! 내일 준비도 가볍게 해볼까요?';

    await _safeZonedSchedule(
      id: 999998,
      title: '오늘의 마무리 리마인더',
      body: body,
      scheduledDate: _nextInstanceOfTime(hour, minute),
      details: const NotificationDetails(
        android: AndroidNotificationDetails(
          'evening_review',
          '저녁 리마인더',
          channelDescription: '미완료 일정 리마인더',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelPlanReminder(String planId) async {
    if (kIsWeb) return;
    await _notifications.cancel(planId.hashCode);
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _notifications.cancelAll();
  }

  Future<void> showTestNotification() async {
    if (kIsWeb) return;
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
