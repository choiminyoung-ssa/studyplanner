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
import '../utils/date_utils.dart';

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
  Future<bool> performManualSync({bool interactive = true}) async {
    if (_syncState == SyncState.syncing) {
      return false; // Already syncing
    }

    try {
      _errors.clear();
      _syncState = SyncState.syncing;
      notifyListeners();

      final ready = await _calendarService.ensureAuthenticated(
        interactive: interactive,
      );
      if (!ready) {
        _recordError('Google Calendar authentication is required.');
        _syncState = SyncState.error;
        notifyListeners();
        return false;
      }

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

      final dailyPlans =
          await _firestoreService.getDailyPlansByDateRange(userId, rangeStart, rangeEnd);
      final weeklyPlans = await _firestoreService
          .getWeeklyPlansByDateRange(userId, rangeStart, rangeEnd)
          .first;
      final monthlyPlans = await _firestoreService.getAllMonthlyPlans(userId).first;
      final timetable = await _firestoreService.getWeeklyTimetable(userId).first;

      if (settings.syncDailyPlans) {
        await _syncDailyPlans(dailyPlans, subjectById, calendarId);
      }

      if (settings.syncWeeklyPlans) {
        await _syncWeeklyPlans(weeklyPlans, subjectById, calendarId);
      }

      if (settings.syncMonthlyPlans) {
        await _syncMonthlyPlans(monthlyPlans, subjectById, calendarId);
      }

      if (settings.syncWeeklyTimetable) {
        await _syncWeeklyTimetable(timetable, calendarId, userId);
      }

      await _syncFromGoogle(
        settings: settings,
        calendarId: calendarId,
        userId: userId,
        subjectByName: {
          for (final subject in subjects)
            subject.name.trim().toLowerCase(): subject,
        },
        dailyPlans: dailyPlans,
        weeklyPlans: weeklyPlans,
        monthlyPlans: monthlyPlans,
        timetableEntries: timetable,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

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
        await performManualSync(interactive: false);
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

  Future<void> _syncFromGoogle({
    required CalendarSyncSettings settings,
    required String calendarId,
    required String userId,
    required Map<String, Subject> subjectByName,
    required List<DailyPlan> dailyPlans,
    required List<WeeklyPlan> weeklyPlans,
    required List<MonthlyPlan> monthlyPlans,
    required List<WeeklyTimetableEntry> timetableEntries,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    if (!settings.syncDailyPlans &&
        !settings.syncWeeklyPlans &&
        !settings.syncMonthlyPlans &&
        !settings.syncWeeklyTimetable) {
      return;
    }

    final dailyByEventId = <String, DailyPlan>{
      for (final plan in dailyPlans)
        if (plan.googleEventId != null && plan.googleEventId!.isNotEmpty)
          plan.googleEventId!: plan,
    };
    final weeklyByEventId = <String, WeeklyPlan>{
      for (final plan in weeklyPlans)
        if (plan.googleEventId != null && plan.googleEventId!.isNotEmpty)
          plan.googleEventId!: plan,
    };
    final monthlyByEventId = <String, MonthlyPlan>{
      for (final plan in monthlyPlans)
        if (plan.googleEventId != null && plan.googleEventId!.isNotEmpty)
          plan.googleEventId!: plan,
    };
    final timetableByEventId = <String, WeeklyTimetableEntry>{
      for (final entry in timetableEntries)
        if (entry.googleEventId != null && entry.googleEventId!.isNotEmpty)
          entry.googleEventId!: entry,
    };

    final events = await _calendarService.listEvents(
      timeMin: rangeStart,
      timeMax: rangeEnd,
      calendarId: calendarId,
      singleEvents: true,
      showDeleted: true,
    );

    for (final event in events) {
      final eventId = event.id;
      if (eventId == null || eventId.isEmpty) continue;

      if (event.status == 'cancelled') {
        await _handleCancelledEvent(
          eventId,
          dailyByEventId,
          weeklyByEventId,
          monthlyByEventId,
          timetableByEventId,
          userId,
        );
        continue;
      }

      final eventType = event.extendedProperties?.private?['type'];
      final recurringId = event.recurringEventId;

      if (recurringId != null && timetableByEventId.containsKey(recurringId)) {
        if (settings.syncWeeklyTimetable) {
          await _upsertTimetableFromEvent(
            event,
            existing: timetableByEventId[recurringId],
            userId: userId,
          );
        }
        continue;
      }

      if (eventType == 'weekly' && settings.syncWeeklyPlans) {
        await _upsertWeeklyFromEvent(
          event,
          existing: weeklyByEventId[eventId],
          subjectByName: subjectByName,
          userId: userId,
        );
        continue;
      }

      if (eventType == 'monthly' && settings.syncMonthlyPlans) {
        await _upsertMonthlyFromEvent(
          event,
          existing: monthlyByEventId[eventId],
          subjectByName: subjectByName,
          userId: userId,
        );
        continue;
      }

      if (eventType == 'timetable' && settings.syncWeeklyTimetable) {
        await _upsertTimetableFromEvent(
          event,
          existing: timetableByEventId[eventId],
          userId: userId,
        );
        continue;
      }

      if (settings.syncDailyPlans) {
        await _upsertDailyFromEvent(
          event,
          existing: dailyByEventId[eventId],
          subjectByName: subjectByName,
          userId: userId,
        );
      }
    }
  }

  Future<void> _handleCancelledEvent(
    String eventId,
    Map<String, DailyPlan> dailyByEventId,
    Map<String, WeeklyPlan> weeklyByEventId,
    Map<String, MonthlyPlan> monthlyByEventId,
    Map<String, WeeklyTimetableEntry> timetableByEventId,
    String userId,
  ) async {
    final daily = dailyByEventId[eventId];
    if (daily != null) {
      await _firestoreService.deleteDailyPlan(daily.id);
      return;
    }

    final weekly = weeklyByEventId[eventId];
    if (weekly != null) {
      await _firestoreService.deleteWeeklyPlan(weekly.id);
      return;
    }

    final monthly = monthlyByEventId[eventId];
    if (monthly != null) {
      await _firestoreService.deleteMonthlyPlan(monthly.id);
      return;
    }

    final timetable = timetableByEventId[eventId];
    if (timetable != null) {
      await _firestoreService.deleteWeeklyTimetableEntry(userId, timetable.id);
    }
  }

  Future<void> _upsertDailyFromEvent(
    calendar.Event event, {
    required DailyPlan? existing,
    required Map<String, Subject> subjectByName,
    required String userId,
  }) async {
    final parsed = _parseEvent(event, subjectByName);
    if (parsed == null) return;

    if (existing != null) {
      final updates = <String, dynamic>{
        'date': Timestamp.fromDate(parsed.date),
        'startTime': parsed.startTime,
        'endTime': parsed.endTime,
        'googleEventId': event.id,
      };

      if (parsed.title.isNotEmpty) updates['title'] = parsed.title;
      if (parsed.notes.isNotEmpty) updates['notes'] = parsed.notes;
      if (parsed.subjectId != null) {
        updates['subjectId'] = parsed.subjectId;
        updates['subject'] = parsed.subjectName;
      }

      await _firestoreService.updateDailyPlan(existing.id, updates);
      return;
    }

    final plan = DailyPlan(
      id: '',
      userId: userId,
      date: parsed.date,
      startTime: parsed.startTime,
      endTime: parsed.endTime,
      title: parsed.title.isNotEmpty ? parsed.title : 'Google Calendar Event',
      notes: parsed.notes,
      subject: parsed.subjectName,
      subjectId: parsed.subjectId,
      pageRanges: const [],
      subtasks: const [],
      tag: '',
      priority: 2,
      isCompleted: false,
      completedAt: null,
      parentWeeklyId: null,
      sessionIds: const [],
      totalStudiedSeconds: 0,
      googleEventId: event.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firestoreService.createDailyPlan(plan);
  }

  Future<void> _upsertWeeklyFromEvent(
    calendar.Event event, {
    required WeeklyPlan? existing,
    required Map<String, Subject> subjectByName,
    required String userId,
  }) async {
    final parsed = _parseEvent(event, subjectByName);
    if (parsed == null) return;

    final weekStart = DateHelper.getWeekStartDate(parsed.date);
    final weekEnd = DateHelper.getWeekEndDate(parsed.date);

    if (existing != null) {
      final updates = <String, dynamic>{
        'date': Timestamp.fromDate(parsed.date),
        'weekStartDate': Timestamp.fromDate(weekStart),
        'weekEndDate': Timestamp.fromDate(weekEnd),
        'googleEventId': event.id,
      };

      if (parsed.title.isNotEmpty) updates['title'] = parsed.title;
      if (parsed.notes.isNotEmpty) updates['notes'] = parsed.notes;
      if (parsed.subjectId != null) {
        updates['subjectId'] = parsed.subjectId;
        updates['subject'] = parsed.subjectName;
      }

      await _firestoreService.updateWeeklyPlan(existing.id, updates);
      return;
    }

    final plan = WeeklyPlan(
      id: '',
      userId: userId,
      weekStartDate: weekStart,
      weekEndDate: weekEnd,
      date: parsed.date,
      title: parsed.title.isNotEmpty ? parsed.title : 'Google Calendar Event',
      notes: parsed.notes,
      subject: parsed.subjectName,
      subjectId: parsed.subjectId,
      pageRanges: const [],
      subtasks: const [],
      tag: '',
      priority: 2,
      isCompleted: false,
      completedAt: null,
      parentMonthlyId: null,
      relatedDailyIds: const [],
      googleEventId: event.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firestoreService.createWeeklyPlan(plan);
  }

  Future<void> _upsertMonthlyFromEvent(
    calendar.Event event, {
    required MonthlyPlan? existing,
    required Map<String, Subject> subjectByName,
    required String userId,
  }) async {
    final parsed = _parseEvent(event, subjectByName);
    if (parsed == null) return;

    final month = _formatMonth(parsed.date);
    final startDate = parsed.date;
    final endDate = parsed.endDate;

    if (existing != null) {
      final updates = <String, dynamic>{
        'month': month,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'googleEventId': event.id,
      };

      if (parsed.title.isNotEmpty) updates['title'] = parsed.title;
      if (parsed.notes.isNotEmpty) updates['notes'] = parsed.notes;
      if (parsed.subjectId != null) {
        updates['subjectId'] = parsed.subjectId;
        updates['subject'] = parsed.subjectName;
      }

      await _firestoreService.updateMonthlyPlan(existing.id, updates);
      return;
    }

    final plan = MonthlyPlan(
      id: '',
      userId: userId,
      month: month,
      title: parsed.title.isNotEmpty ? parsed.title : 'Google Calendar Event',
      notes: parsed.notes,
      subject: parsed.subjectName,
      subjectId: parsed.subjectId,
      pageRanges: const [],
      startDate: startDate,
      endDate: endDate,
      subtasks: const [],
      tag: '',
      priority: 2,
      isCompleted: false,
      completedAt: null,
      relatedWeeklyIds: const [],
      googleEventId: event.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firestoreService.createMonthlyPlan(plan);
  }

  Future<void> _upsertTimetableFromEvent(
    calendar.Event event, {
    required WeeklyTimetableEntry? existing,
    required String userId,
  }) async {
    final timeRange = _parseEventTime(event);
    if (timeRange == null || timeRange.isAllDay) return;

    final weekday = timeRange.start.weekday;
    final startTime = _formatTime(timeRange.start);
    final endTime = _formatTime(_ensureSameDayEnd(timeRange.start, timeRange.end));

    if (existing != null) {
      final updates = <String, dynamic>{
        'weekday': weekday,
        'startTime': startTime,
        'endTime': endTime,
        'title': event.summary?.trim().isNotEmpty == true
            ? event.summary!.trim()
            : existing.title,
        'location': event.location,
        'googleEventId': event.id,
      };
      await _firestoreService.updateWeeklyTimetableEntry(
        userId,
        existing.id,
        updates,
      );
      return;
    }

    final entry = WeeklyTimetableEntry(
      id: '',
      userId: userId,
      weekday: weekday,
      startTime: startTime,
      endTime: endTime,
      title: event.summary?.trim().isNotEmpty == true
          ? event.summary!.trim()
          : 'Google Calendar Event',
      location: event.location,
      googleEventId: event.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firestoreService.createWeeklyTimetableEntry(entry);
  }

  _ParsedEvent? _parseEvent(
    calendar.Event event,
    Map<String, Subject> subjectByName,
  ) {
    final timeRange = _parseEventTime(event);
    if (timeRange == null) return null;

    final summary = event.summary?.trim() ?? '';
    final parsedSummary = _parseSummary(summary, subjectByName);
    final notes = _buildNotes(event);

    final date = DateTime(
      timeRange.start.year,
      timeRange.start.month,
      timeRange.start.day,
    );
    final endDate = _resolveEndDate(timeRange);

    final startTime = timeRange.isAllDay ? '00:00' : _formatTime(timeRange.start);
    var endTime = timeRange.isAllDay
        ? '23:59'
        : _formatTime(_ensureSameDayEnd(timeRange.start, timeRange.end));

    if (!DateHelper.isValidTimeRange(startTime, endTime)) {
      final fallbackEnd = timeRange.start.add(const Duration(minutes: 30));
      endTime = _formatTime(fallbackEnd);
    }

    return _ParsedEvent(
      title: parsedSummary.title,
      notes: notes,
      subjectId: parsedSummary.subject?.id,
      subjectName: parsedSummary.subject?.name ?? '',
      date: date,
      endDate: endDate,
      startTime: startTime,
      endTime: endTime,
      isAllDay: timeRange.isAllDay,
    );
  }

  _ParsedSummary _parseSummary(
    String summary,
    Map<String, Subject> subjectByName,
  ) {
    final trimmed = summary.trim();
    final subjectPattern = RegExp(r'^\[(.+?)\]\s*(.*)$');
    String title = trimmed;
    Subject? subject;

    final match = subjectPattern.firstMatch(trimmed);
    if (match != null) {
      final subjectName = match.group(1)?.trim() ?? '';
      final remainingTitle = match.group(2)?.trim() ?? '';
      if (subjectName.isNotEmpty) {
        subject = subjectByName[subjectName.toLowerCase()];
      }
      if (remainingTitle.isNotEmpty) {
        title = remainingTitle;
      } else if (subjectName.isNotEmpty) {
        title = subjectName;
      }
    }

    return _ParsedSummary(
      title: title,
      subject: subject,
    );
  }

  String _buildNotes(calendar.Event event) {
    final description = event.description?.trim() ?? '';
    final location = event.location?.trim() ?? '';

    if (description.isEmpty && location.isEmpty) {
      return '';
    }
    if (description.isNotEmpty && location.isNotEmpty) {
      return '$description\nLocation: $location';
    }
    if (description.isNotEmpty) return description;
    return 'Location: $location';
  }

  _EventTimeRange? _parseEventTime(calendar.Event event) {
    final start = event.start?.dateTime ?? event.start?.date;
    if (start == null) return null;
    final rawEnd = event.end?.dateTime ?? event.end?.date;
    var end = rawEnd ?? start.add(const Duration(hours: 1));
    final isAllDay = event.start?.date != null && event.start?.dateTime == null;
    if (isAllDay) {
      final exclusiveEnd = DateTime(end.year, end.month, end.day);
      end = exclusiveEnd.subtract(const Duration(days: 1));
      if (end.isBefore(start)) {
        end = start;
      }
    }
    return _EventTimeRange(start: start, end: end, isAllDay: isAllDay);
  }

  DateTime _ensureSameDayEnd(DateTime start, DateTime end) {
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return end;
    }
    return DateTime(start.year, start.month, start.day, 23, 59);
  }

  DateTime _resolveEndDate(_EventTimeRange range) {
    if (range.isAllDay) {
      return DateTime(range.end.year, range.end.month, range.end.day);
    }
    final endDate = _ensureSameDayEnd(range.start, range.end);
    return DateTime(endDate.year, endDate.month, endDate.day);
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatMonth(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
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

class _ParsedSummary {
  final String title;
  final Subject? subject;

  const _ParsedSummary({
    required this.title,
    required this.subject,
  });
}

class _ParsedEvent {
  final String title;
  final String notes;
  final String? subjectId;
  final String subjectName;
  final DateTime date;
  final DateTime endDate;
  final String startTime;
  final String endTime;
  final bool isAllDay;

  const _ParsedEvent({
    required this.title,
    required this.notes,
    required this.subjectId,
    required this.subjectName,
    required this.date,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.isAllDay,
  });
}

class _EventTimeRange {
  final DateTime start;
  final DateTime end;
  final bool isAllDay;

  const _EventTimeRange({
    required this.start,
    required this.end,
    required this.isAllDay,
  });
}
