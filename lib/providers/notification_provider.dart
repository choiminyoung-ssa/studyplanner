import 'package:flutter/material.dart';
import '../models/daily_plan.dart';
import '../models/notification_settings.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class NotificationProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  late final NotificationService _notificationService;
  NotificationSettings _settings = NotificationSettings();
  bool _permissionGranted = false;
  bool _initialized = false;

  NotificationProvider() {
    _notificationService = NotificationService(_firestoreService);
  }

  NotificationSettings get settings => _settings;
  bool get permissionGranted => _permissionGranted;

  Future<void> initialize() async {
    if (_initialized) return;
    await _notificationService.initialize();
    _initialized = true;
  }

  Future<void> loadSettings(String userId) async {
    await initialize();
    _settings = await _firestoreService.getNotificationSettings(userId);
    notifyListeners();
  }

  Future<void> updateSettings(String userId, NotificationSettings settings) async {
    await initialize();
    _settings = settings;
    await _firestoreService.saveNotificationSettings(userId, settings);
    notifyListeners();

    if (_permissionGranted) {
      await _notificationService.cancelAllNotifications();
      if (settings.dailySummaryEnabled) {
        await _notificationService.scheduleDailySummary(userId, settings.dailySummaryTime);
      }
      if (settings.eveningReviewEnabled) {
        await _notificationService.scheduleEveningReview(userId, settings.eveningReviewTime);
      }
      if (settings.planReminderEnabled) {
        await _notificationService.rescheduleAllPlanReminders(userId, settings.reminderMinutesBefore);
      }
    }
  }

  Future<bool> checkAndRequestPermission(String userId) async {
    await initialize();
    _permissionGranted = await _notificationService.requestPermissions();
    notifyListeners();
    if (_permissionGranted) {
      await _notificationService.cancelAllNotifications();
      if (_settings.dailySummaryEnabled) {
        await _notificationService.scheduleDailySummary(userId, _settings.dailySummaryTime);
      }
      if (_settings.eveningReviewEnabled) {
        await _notificationService.scheduleEveningReview(userId, _settings.eveningReviewTime);
      }
      if (_settings.planReminderEnabled) {
        await _notificationService.rescheduleAllPlanReminders(userId, _settings.reminderMinutesBefore);
      }
    }
    return _permissionGranted;
  }

  Future<void> onPlanCreated(DailyPlan plan) async {
    if (!_permissionGranted || !_settings.planReminderEnabled) return;
    await _notificationService.schedulePlanReminder(plan, _settings.reminderMinutesBefore);
  }

  Future<void> onPlanUpdated(DailyPlan plan) async {
    if (!_permissionGranted) return;
    await _notificationService.cancelPlanReminder(plan.id);
    if (_settings.planReminderEnabled) {
      await _notificationService.schedulePlanReminder(plan, _settings.reminderMinutesBefore);
    }
  }

  Future<void> onPlanDeleted(String planId) async {
    if (!_permissionGranted) return;
    await _notificationService.cancelPlanReminder(planId);
  }

  Future<void> showTestNotification() async {
    await _notificationService.showTestNotification();
  }
}
