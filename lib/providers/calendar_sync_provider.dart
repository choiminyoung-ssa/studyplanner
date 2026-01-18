import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/calendar_sync_settings.dart';
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

  CalendarSyncSettings? _settings;
  SyncState _syncState = SyncState.idle;
  final List<SyncError> _errors = [];
  DateTime? _lastSyncAt;
  Timer? _syncTimer;

  CalendarSyncProvider({
    GoogleCalendarService? calendarService,
    FirebaseFirestore? firestore,
  })  : _calendarService = calendarService ?? GoogleCalendarService(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  // Getters
  CalendarSyncSettings? get settings => _settings;
  SyncState get syncState => _syncState;
  List<SyncError> get errors => List.unmodifiable(_errors);
  DateTime? get lastSyncAt => _lastSyncAt;
  bool get isAuthenticated => _calendarService.isAuthenticated;
  bool get isSyncing => _syncState == SyncState.syncing;

  /// Initialize provider with user ID
  Future<void> initialize(String userId) async {
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
        _settings = CalendarSyncSettings.fromFirestore(doc);
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
  Future<void> performManualSync() async {
    if (_syncState == SyncState.syncing) {
      return; // Already syncing
    }

    if (!_calendarService.isAuthenticated) {
      _addError('Not authenticated. Please connect your Google account first.');
      return;
    }

    try {
      _syncState = SyncState.syncing;
      notifyListeners();

      // TODO: Implement actual sync logic in Phase 2
      // For now, just simulate a sync
      await Future.delayed(const Duration(seconds: 2));

      _lastSyncAt = DateTime.now();

      // Update lastFullSyncAt in settings
      if (_settings != null) {
        await updateSettings(_settings!.copyWith(lastFullSyncAt: _lastSyncAt));
      }

      _syncState = SyncState.idle;
      notifyListeners();
    } catch (e) {
      _syncState = SyncState.error;
      _addError('Manual sync failed: $e');
      notifyListeners();
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
