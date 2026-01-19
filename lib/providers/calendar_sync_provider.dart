import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import '../models/calendar_sync_settings.dart';
import '../models/daily_plan.dart';
import '../models/monthly_plan.dart';
import '../models/subject.dart';
import '../models/weekly_plan.dart';
import '../models/weekly_timetable_entry.dart';
import '../services/calendar_event_mapper.dart';
import '../services/firestore_service.dart';
import '../services/google_calendar_service.dart';

enum SyncState { idle, syncing, error }

class SyncError {
  final String message;
  final DateTime timestamp;
  final String? itemId;

  SyncError({
    required this.message,
    required this.timestamp,
    this.itemId,
  });
}

/// Provider for managing Google Calendar sync state and settings
class CalendarSyncProvider extends ChangeNotifier {
  final GoogleCalendarService _calendarService;
  final FirebaseFirestore _firestore;
  final FirestoreService _firestoreService;

  CalendarSyncSettings? _settings;
  SyncState _syncState = SyncState.idle;
  final List<SyncError> _errors = [];
  DateTime? _lastSyncAt;
  Timer? _syncTimer;
  String? _userId;

  CalendarSyncProvider({
    GoogleCalendarService? calendarService,
    FirebaseFirestore? firestore,
    FirestoreService? firestoreService,
  })  : _calendarService = calendarService ?? GoogleCalendarService(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _firestoreService = firestoreService ?? FirestoreService();

  // Getters
  CalendarSyncSettings? get settings => _settings;
  SyncState get syncState => _syncState;
  List<SyncError> get errors => List.unmodifiable(_errors);
  DateTime? get lastSyncAt => _lastSyncAt;
  bool get isAuthenticated => _calendarService.isAuthenticated;
  bool get isSyncing => _syncState == SyncState.syncing;

  /// Initialize provider with user ID
  Future<void> initialize(String userId) async {
    _userId = userId;
    await loadSettings(userId);

    // Start periodic sync if enabled
    if (_settings?.isEnabled == true && _settings!.syncIntervalMinutes > 0) {
      startPeriodicSync();
    }
  }

  /// Load sync settings from Firestore
  Future<void> loadSettings(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('calendar_sync_settings')
          .doc('settings')
          .get();

      if (doc.exists) {
        _settings =
            CalendarSyncSettings.fromFirestore(doc).copyWith(userId: userId);
      } else {
        // Create default settings
        _settings = CalendarSyncSettings.defaultSettings(userId);
        await saveSettings(_settings!);
      }

      notifyListeners();
    } catch (e) {
      _addError('Failed to load sync settings: $e');
    }
  }

  /// Save sync settings to Firestore
  Future<void> saveSettings(CalendarSyncSettings settings) async {
    try {
      await _firestore
          .collection('users')
          .doc(settings.userId)
          .collection('calendar_sync_settings')
          .doc('settings')
          .set(settings.toFirestore());

      _settings = settings;
      notifyListeners();
    } catch (e) {
      _addError('Failed to save sync settings: $e');
    }
  }

  /// Update sync settings
  Future<void> updateSettings(CalendarSyncSettings newSettings) async {
    final oldSettings = _settings;

    // Save new settings
    await saveSettings(newSettings);

    // Restart periodic sync if interval changed
    if (oldSettings?.syncIntervalMinutes != newSettings.syncIntervalMinutes) {
      stopPeriodicSync();
      if (newSettings.isEnabled && newSettings.syncIntervalMinutes > 0) {
        startPeriodicSync();
      }
    }
  }

  /// Authenticate with Google Calendar
  Future<bool> authenticate() async {
    try {
      _syncState = SyncState.syncing;
      notifyListeners();

      final success = await _calendarService.authenticate();

      if (success) {
        _syncState = SyncState.idle;

        // Enable sync if authentication successful
        if (_settings != null && !_settings!.isEnabled) {
          await updateSettings(_settings!.copyWith(isEnabled: true));
        }

        notifyListeners();
        return true;
      } else {
        _syncState = SyncState.error;
        _addError('Authentication cancelled or failed');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _syncState = SyncState.error;
      _addError('Authentication error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Disconnect Google Calendar
  Future<void> disconnect() async {
    try {
      _syncState = SyncState.syncing;
      notifyListeners();

      await _calendarService.signOut();

      // Disable sync
      if (_settings != null) {
        await updateSettings(_settings!.copyWith(isEnabled: false));
      }

      stopPeriodicSync();

      _syncState = SyncState.idle;
      notifyListeners();
    } catch (e) {
      _syncState = SyncState.error;
      _addError('Disconnect error: $e');
      notifyListeners();
    }
  }

  /// Perform manual sync
  Future<bool> performManualSync() async {
    if (_syncState == SyncState.syncing) {
      return false; // Already syncing
    }

    if (!_calendarService.isAuthenticated) {
      _addError('Not authenticated. Please connect your Google account first.');
      return false;
    }

    try {
      _errors.clear();
      _syncState = SyncState.syncing;
      notifyListeners();

      final settings = _settings;
      if (settings == null) {
        _recordError('Sync settings not loaded.');
        _syncState = SyncState.error;
        notifyListeners();
        return false;
      }

      final userId = _userId ?? settings.userId;
      if (userId.isEmpty) {
        _recordError('User ID is missing. Please sign in again.');
        _syncState = SyncState.error;
        notifyListeners();
        return false;
      }

      final calendarId = settings.googleCalendarId ?? 'primary';
      final now = DateTime.now();
      final rangeStart = now.subtract(const Duration(days: 7));
      final rangeEnd = now.add(const Duration(days: 60));

      final subjects = await _firestoreService.getAllSubjects(userId).first;
      final subjectById = {
        for (final subject in subjects) subject.id: subject,
      };

      if (settings.syncDailyPlans) {
        final dailyPlans =
            await _firestoreService.getDailyPlansByDateRange(userId, rangeStart, rangeEnd);
        await _syncDailyPlans(dailyPlans, subjectById, calendarId);
      }

      if (settings.syncWeeklyPlans) {
        final weeklyPlans = await _firestoreService
            .getWeeklyPlansByDateRange(userId, rangeStart, rangeEnd)
            .first;
        await _syncWeeklyPlans(weeklyPlans, subjectById, calendarId);
      }

      if (settings.syncMonthlyPlans) {
        final monthlyPlans = await _firestoreService.getAllMonthlyPlans(userId).first;
        await _syncMonthlyPlans(monthlyPlans, subjectById, calendarId);
      }

      if (settings.syncWeeklyTimetable) {
        final timetable = await _firestoreService.getWeeklyTimetable(userId).first;
        await _syncWeeklyTimetable(timetable, calendarId, userId);
      }

      _lastSyncAt = DateTime.now();

      // Update lastFullSyncAt in settings
      await updateSettings(settings.copyWith(lastFullSyncAt: _lastSyncAt));

      _syncState = _errors.isEmpty ? SyncState.idle : SyncState.error;
      notifyListeners();
      return _errors.isEmpty;
    } catch (e) {
      _syncState = SyncState.error;
      _addError('Manual sync failed: $e');
      notifyListeners();
      return false;
    }
  }

  /// Start periodic background sync
  void startPeriodicSync() {
    stopPeriodicSync(); // Clear any existing timer

    if (_settings == null || _settings!.syncIntervalMinutes <= 0) {
      return;
    }

    final interval = Duration(minutes: _settings!.syncIntervalMinutes);

    _syncTimer = Timer.periodic(interval, (_) async {
      if (_calendarService.isAuthenticated && _settings?.isEnabled == true) {
        await performManualSync();
      }
    });
  }

  /// Stop periodic background sync
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Clear all sync errors
  void clearErrors() {
    _errors.clear();
    if (_syncState == SyncState.error) {
      _syncState = SyncState.idle;
    }
    notifyListeners();
  }

  /// Add a sync error
  void _addError(String message, {String? itemId}) {
    _errors.add(SyncError(
      message: message,
      timestamp: DateTime.now(),
      itemId: itemId,
    ));
    _syncState = SyncState.error;
    notifyListeners();
  }

  void _recordError(String message, {String? itemId}) {
    _errors.add(SyncError(
      message: message,
      timestamp: DateTime.now(),
      itemId: itemId,
    ));
  }

  Future<int> _syncDailyPlans(List<DailyPlan> plans,
      Map<String, Subject> subjectById, String calendarId) async {
    var synced = 0;
    for (final plan in plans) {
      try {
        final subject = plan.subjectId != null ? subjectById[plan.subjectId] : null;
        final event = CalendarEventMapper.fromDailyPlan(plan, subject: subject);
        final result = await _upsertEvent(plan.googleEventId, event, calendarId);
        if (result != null) {
          synced++;
          await _updateEventId('daily_plans', plan.id, plan.googleEventId, result);
        }
      } catch (e) {
        _recordError('Daily plan sync failed: $e', itemId: plan.id);
      }
    }
    return synced;
  }

  Future<int> _syncWeeklyPlans(List<WeeklyPlan> plans,
      Map<String, Subject> subjectById, String calendarId) async {
    var synced = 0;
    for (final plan in plans) {
      try {
        final subject = plan.subjectId != null ? subjectById[plan.subjectId] : null;
        final event = CalendarEventMapper.fromWeeklyPlan(plan, subject: subject);
        final result = await _upsertEvent(plan.googleEventId, event, calendarId);
        if (result != null) {
          synced++;
          await _updateEventId('weekly_plans', plan.id, plan.googleEventId, result);
        }
      } catch (e) {
        _recordError('Weekly plan sync failed: $e', itemId: plan.id);
      }
    }
    return synced;
  }

  Future<int> _syncMonthlyPlans(List<MonthlyPlan> plans,
      Map<String, Subject> subjectById, String calendarId) async {
    var synced = 0;
    for (final plan in plans) {
      try {
        final subject = plan.subjectId != null ? subjectById[plan.subjectId] : null;
        final event = CalendarEventMapper.fromMonthlyPlan(plan, subject: subject);
        final result = await _upsertEvent(plan.googleEventId, event, calendarId);
        if (result != null) {
          synced++;
          await _updateEventId('monthly_plans', plan.id, plan.googleEventId, result);
        }
      } catch (e) {
        _recordError('Monthly plan sync failed: $e', itemId: plan.id);
      }
    }
    return synced;
  }

  Future<int> _syncWeeklyTimetable(
      List<WeeklyTimetableEntry> entries, String calendarId, String userId) async {
    var synced = 0;
    for (final entry in entries) {
      try {
        final event = CalendarEventMapper.fromWeeklyTimetableEntry(entry);
        final result = await _upsertEvent(entry.googleEventId, event, calendarId);
        if (result != null) {
          synced++;
          await _updateTimetableEventId(userId, entry.id, entry.googleEventId, result);
        }
      } catch (e) {
        _recordError('Timetable sync failed: $e', itemId: entry.id);
      }
    }
    return synced;
  }

  Future<String?> _upsertEvent(
      String? existingEventId, calendar.Event event, String calendarId) async {
    if (existingEventId != null && existingEventId.isNotEmpty) {
      final updated = await _calendarService.updateEvent(
        existingEventId,
        event,
        calendarId: calendarId,
      );
      return updated?.id ?? existingEventId;
    }

    final created = await _calendarService.createEvent(event, calendarId: calendarId);
    return created?.id;
  }

  Future<void> _updateEventId(
      String collection, String docId, String? currentId, String newId) async {
    if (currentId == newId) return;
    await _firestore.collection(collection).doc(docId).update({
      'googleEventId': newId,
    });
  }

  Future<void> _updateTimetableEventId(
      String userId, String entryId, String? currentId, String newId) async {
    if (currentId == newId) return;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('weekly_timetable')
        .doc(entryId)
        .update({'googleEventId': newId});
  }

  /// Check if calendar scopes are granted
  Future<bool> hasCalendarScopes() async {
    return await _calendarService.hasCalendarScopes();
  }

  /// Request calendar scopes
  Future<bool> requestCalendarScopes() async {
    try {
      _syncState = SyncState.syncing;
      notifyListeners();

      final success = await _calendarService.requestCalendarScopes();

      _syncState = success ? SyncState.idle : SyncState.error;
      notifyListeners();

      return success;
    } catch (e) {
      _syncState = SyncState.error;
      _addError('Failed to request calendar scopes: $e');
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    stopPeriodicSync();
    super.dispose();
  }
}
