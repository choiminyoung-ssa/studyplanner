import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarSyncSettings {
  final String userId;
  final bool isEnabled;
  final bool syncMonthlyPlans;
  final bool syncWeeklyPlans;
  final bool syncWeeklyTimetable;
  final String? googleCalendarId; // Target calendar ID (null = primary)
  final DateTime? lastFullSyncAt;
  final String? syncFrequency; // '15min', '30min', '1hour', 'manual'

  const CalendarSyncSettings({
    required this.userId,
    this.isEnabled = false,
    this.syncMonthlyPlans = true,
    this.syncWeeklyPlans = true,
    this.syncWeeklyTimetable = true,
    this.googleCalendarId,
    this.lastFullSyncAt,
    this.syncFrequency = '30min',
  });

  // Convert from Firestore
  factory CalendarSyncSettings.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CalendarSyncSettings(
      userId: doc.id,
      isEnabled: data['isEnabled'] ?? false,
      syncMonthlyPlans: data['syncMonthlyPlans'] ?? true,
      syncWeeklyPlans: data['syncWeeklyPlans'] ?? true,
      syncWeeklyTimetable: data['syncWeeklyTimetable'] ?? true,
      googleCalendarId: data['googleCalendarId'],
      lastFullSyncAt: data['lastFullSyncAt'] != null
          ? (data['lastFullSyncAt'] as Timestamp).toDate()
          : null,
      syncFrequency: data['syncFrequency'] ?? '30min',
    );
  }

  // Convert to Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'isEnabled': isEnabled,
      'syncMonthlyPlans': syncMonthlyPlans,
      'syncWeeklyPlans': syncWeeklyPlans,
      'syncWeeklyTimetable': syncWeeklyTimetable,
      'googleCalendarId': googleCalendarId,
      'lastFullSyncAt':
          lastFullSyncAt != null ? Timestamp.fromDate(lastFullSyncAt!) : null,
      'syncFrequency': syncFrequency,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Create default settings
  factory CalendarSyncSettings.defaultSettings(String userId) {
    return CalendarSyncSettings(userId: userId);
  }

  // Copy with method for immutability
  CalendarSyncSettings copyWith({
    String? userId,
    bool? isEnabled,
    bool? syncMonthlyPlans,
    bool? syncWeeklyPlans,
    bool? syncWeeklyTimetable,
    String? googleCalendarId,
    DateTime? lastFullSyncAt,
    String? syncFrequency,
  }) {
    return CalendarSyncSettings(
      userId: userId ?? this.userId,
      isEnabled: isEnabled ?? this.isEnabled,
      syncMonthlyPlans: syncMonthlyPlans ?? this.syncMonthlyPlans,
      syncWeeklyPlans: syncWeeklyPlans ?? this.syncWeeklyPlans,
      syncWeeklyTimetable: syncWeeklyTimetable ?? this.syncWeeklyTimetable,
      googleCalendarId: googleCalendarId ?? this.googleCalendarId,
      lastFullSyncAt: lastFullSyncAt ?? this.lastFullSyncAt,
      syncFrequency: syncFrequency ?? this.syncFrequency,
    );
  }

  // Helper to get sync interval in minutes
  int get syncIntervalMinutes {
    switch (syncFrequency) {
      case '15min':
        return 15;
      case '30min':
        return 30;
      case '1hour':
        return 60;
      case 'manual':
      default:
        return 0; // 0 = manual only
    }
  }
}
