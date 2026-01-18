import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Service for interacting with Google Calendar API
class GoogleCalendarService {
  calendar.CalendarApi? _calendarApi;
  GoogleSignIn? _googleSignIn;

  // OAuth scopes required for calendar access
  static const List<String> _scopes = [
    calendar.CalendarApi.calendarEventsScope,
  ];

  /// Check if user is authenticated with calendar access
  bool get isAuthenticated => _calendarApi != null;

  /// Authenticate user with Google Calendar access
  /// Returns true if authentication is successful
  Future<bool> authenticate() async {
    try {
      // Initialize GoogleSignIn with calendar scopes
      _googleSignIn = kIsWeb
          ? GoogleSignIn(
              clientId:
                  '227699159450-d98oul5ujdvuao49k0jqv7s2pmkfappi.apps.googleusercontent.com',
              scopes: _scopes,
            )
          : GoogleSignIn(scopes: _scopes);

      // Always force a fresh sign-in to ensure calendar scope is requested
      // ignore: avoid_print
      print('Starting Google Sign-In for Calendar access...');

      final account = await _googleSignIn!.signIn();

      if (account == null) {
        // ignore: avoid_print
        print('User cancelled sign-in');
        // User cancelled sign-in
        return false;
      }

      // ignore: avoid_print
      print('Sign-in successful, getting authenticated client...');

      // Get authenticated HTTP client with calendar scopes
      // For web, this will trigger OAuth consent if needed
      final httpClient = (await _googleSignIn!.authenticatedClient())!;

      // ignore: avoid_print
      print('Got authenticated client successfully');

      // Initialize Calendar API
      _calendarApi = calendar.CalendarApi(httpClient);

      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Authentication error: $e');
      // ignore: avoid_print
      print('Error type: ${e.runtimeType}');
      _handleApiError(e);
      return false;
    }
  }

  /// Sign out and revoke calendar access
  Future<void> signOut() async {
    try {
      await _googleSignIn?.disconnect();
      await _googleSignIn?.signOut();
      _calendarApi = null;
      _googleSignIn = null;
    } catch (e) {
      _handleApiError(e);
    }
  }

  /// Create a new calendar event
  Future<calendar.Event?> createEvent(calendar.Event event,
      {String calendarId = 'primary'}) async {
    if (_calendarApi == null) {
      throw Exception('Not authenticated. Call authenticate() first.');
    }

    return await _withRateLimit(() async {
      try {
        return await _calendarApi!.events.insert(event, calendarId);
      } catch (e) {
        _handleApiError(e);
        return null;
      }
    });
  }

  /// Update an existing calendar event
  Future<calendar.Event?> updateEvent(
    String eventId,
    calendar.Event event, {
    String calendarId = 'primary',
  }) async {
    if (_calendarApi == null) {
      throw Exception('Not authenticated. Call authenticate() first.');
    }

    return await _withRateLimit(() async {
      try {
        return await _calendarApi!.events.update(event, calendarId, eventId);
      } catch (e) {
        _handleApiError(e);
        return null;
      }
    });
  }

  /// Delete a calendar event
  Future<bool> deleteEvent(String eventId,
      {String calendarId = 'primary'}) async {
    if (_calendarApi == null) {
      throw Exception('Not authenticated. Call authenticate() first.');
    }

    return await _withRateLimit(() async {
      try {
        await _calendarApi!.events.delete(calendarId, eventId);
        return true;
      } catch (e) {
        _handleApiError(e);
        return false;
      }
    });
  }

  /// Get a single event by ID
  Future<calendar.Event?> getEvent(String eventId,
      {String calendarId = 'primary'}) async {
    if (_calendarApi == null) {
      throw Exception('Not authenticated. Call authenticate() first.');
    }

    return await _withRateLimit(() async {
      try {
        return await _calendarApi!.events.get(calendarId, eventId);
      } catch (e) {
        _handleApiError(e);
        return null;
      }
    });
  }

  /// List events within a date range
  ///
  /// [timeMin] - Lower bound (inclusive) for event's end time
  /// [timeMax] - Upper bound (exclusive) for event's start time
  /// [updatedMin] - Lower bound for event's last modification time (optional, for sync)
  /// [maxResults] - Maximum number of events returned (default: 250)
  Future<List<calendar.Event>> listEvents({
    required DateTime timeMin,
    required DateTime timeMax,
    DateTime? updatedMin,
    String calendarId = 'primary',
    int maxResults = 250,
  }) async {
    if (_calendarApi == null) {
      throw Exception('Not authenticated. Call authenticate() first.');
    }

    return await _withRateLimit(() async {
      try {
        final events = await _calendarApi!.events.list(
          calendarId,
          timeMin: timeMin,
          timeMax: timeMax,
          updatedMin: updatedMin,
          maxResults: maxResults,
          singleEvents: true,
          orderBy: 'startTime',
        );

        return events.items ?? [];
      } catch (e) {
        _handleApiError(e);
        return [];
      }
    });
  }

  /// List all calendars accessible to the user
  Future<List<calendar.CalendarListEntry>> listCalendars() async {
    if (_calendarApi == null) {
      throw Exception('Not authenticated. Call authenticate() first.');
    }

    return await _withRateLimit(() async {
      try {
        final calendarList = await _calendarApi!.calendarList.list();
        return calendarList.items ?? [];
      } catch (e) {
        _handleApiError(e);
        return [];
      }
    });
  }

  /// Batch delete events
  /// Returns number of successfully deleted events
  Future<int> batchDeleteEvents(List<String> eventIds,
      {String calendarId = 'primary'}) async {
    if (_calendarApi == null) {
      throw Exception('Not authenticated. Call authenticate() first.');
    }

    int deletedCount = 0;

    for (final eventId in eventIds) {
      final success = await deleteEvent(eventId, calendarId: calendarId);
      if (success) deletedCount++;

      // Small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 100));
    }

    return deletedCount;
  }

  // Rate limiting wrapper
  // Google Calendar API quota: 10 queries per second per user
  DateTime? _lastRequestTime;
  static const _minRequestInterval = Duration(milliseconds: 100);

  Future<T> _withRateLimit<T>(Future<T> Function() operation) async {
    // Implement simple rate limiting
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < _minRequestInterval) {
        await Future.delayed(_minRequestInterval - elapsed);
      }
    }

    _lastRequestTime = DateTime.now();
    return await operation();
  }

  // Error handling
  void _handleApiError(dynamic error) {
    // Log error or convert to user-friendly message
    // In production, use a proper logging framework
    // ignore: avoid_print
    print('Google Calendar API Error: $error');

    if (error.toString().contains('401')) {
      throw Exception('Authentication expired. Please reconnect your Google account.');
    } else if (error.toString().contains('403')) {
      throw Exception('Calendar access denied. Please check permissions.');
    } else if (error.toString().contains('404')) {
      throw Exception('Event not found. It may have been deleted.');
    } else if (error.toString().contains('429')) {
      throw Exception('Too many requests. Please try again later.');
    } else if (error.toString().contains('500') ||
        error.toString().contains('503')) {
      throw Exception('Google Calendar service is temporarily unavailable.');
    } else {
      throw Exception('Failed to sync with Google Calendar: ${error.toString()}');
    }
  }

  /// Check if current Google Sign-In has calendar scopes
  Future<bool> hasCalendarScopes() async {
    try {
      _googleSignIn ??= kIsWeb
          ? GoogleSignIn(
              clientId:
                  '227699159450-d98oul5ujdvuao49k0jqv7s2pmkfappi.apps.googleusercontent.com',
              scopes: _scopes,
            )
          : GoogleSignIn(scopes: _scopes);

      final account = await _googleSignIn!.signInSilently();
      if (account == null) return false;

      // Try to get authenticated client
      final httpClient = await _googleSignIn!.authenticatedClient();
      return httpClient != null;
    } catch (e) {
      return false;
    }
  }

  /// Request additional calendar scopes for existing sign-in
  Future<bool> requestCalendarScopes() async {
    try {
      // Request additional scopes
      final account = await _googleSignIn?.signIn();
      if (account == null) return false;

      final httpClient = await _googleSignIn?.authenticatedClient();
      if (httpClient == null) return false;

      _calendarApi = calendar.CalendarApi(httpClient);
      return true;
    } catch (e) {
      _handleApiError(e);
      return false;
    }
  }
}
