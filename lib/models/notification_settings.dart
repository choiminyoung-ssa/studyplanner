class NotificationSettings {
  final bool dailySummaryEnabled;
  final String dailySummaryTime;
  final bool planReminderEnabled;
  final int reminderMinutesBefore;
  final bool eveningReviewEnabled;
  final String eveningReviewTime;
  final bool streakCelebrationEnabled;

  NotificationSettings({
    this.dailySummaryEnabled = true,
    this.dailySummaryTime = '08:00',
    this.planReminderEnabled = true,
    this.reminderMinutesBefore = 10,
    this.eveningReviewEnabled = true,
    this.eveningReviewTime = '20:00',
    this.streakCelebrationEnabled = true,
  });

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      dailySummaryEnabled: map['dailySummaryEnabled'] ?? true,
      dailySummaryTime: map['dailySummaryTime'] ?? '08:00',
      planReminderEnabled: map['planReminderEnabled'] ?? true,
      reminderMinutesBefore: map['reminderMinutesBefore'] ?? 10,
      eveningReviewEnabled: map['eveningReviewEnabled'] ?? true,
      eveningReviewTime: map['eveningReviewTime'] ?? '20:00',
      streakCelebrationEnabled: map['streakCelebrationEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dailySummaryEnabled': dailySummaryEnabled,
      'dailySummaryTime': dailySummaryTime,
      'planReminderEnabled': planReminderEnabled,
      'reminderMinutesBefore': reminderMinutesBefore,
      'eveningReviewEnabled': eveningReviewEnabled,
      'eveningReviewTime': eveningReviewTime,
      'streakCelebrationEnabled': streakCelebrationEnabled,
    };
  }

  NotificationSettings copyWith({
    bool? dailySummaryEnabled,
    String? dailySummaryTime,
    bool? planReminderEnabled,
    int? reminderMinutesBefore,
    bool? eveningReviewEnabled,
    String? eveningReviewTime,
    bool? streakCelebrationEnabled,
  }) {
    return NotificationSettings(
      dailySummaryEnabled: dailySummaryEnabled ?? this.dailySummaryEnabled,
      dailySummaryTime: dailySummaryTime ?? this.dailySummaryTime,
      planReminderEnabled: planReminderEnabled ?? this.planReminderEnabled,
      reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
      eveningReviewEnabled: eveningReviewEnabled ?? this.eveningReviewEnabled,
      eveningReviewTime: eveningReviewTime ?? this.eveningReviewTime,
      streakCelebrationEnabled: streakCelebrationEnabled ?? this.streakCelebrationEnabled,
    );
  }
}
