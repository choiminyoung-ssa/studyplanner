class StudyStatistics {
  final DateTime startDate;
  final DateTime endDate;
  final int totalMinutes;
  final int completedPlans;
  final int totalPlans;
  final Map<String, int> subjectMinutes;
  final List<DailyStats> dailyStats;

  StudyStatistics({
    required this.startDate,
    required this.endDate,
    required this.totalMinutes,
    required this.completedPlans,
    required this.totalPlans,
    required this.subjectMinutes,
    required this.dailyStats,
  });

  double get completionRate => totalPlans > 0 ? (completedPlans / totalPlans * 100) : 0;

  double get averageDailyMinutes {
    final days = endDate.difference(startDate).inDays + 1;
    if (days <= 0) return 0;
    return totalMinutes / days;
  }
}

class DailyStats {
  final DateTime date;
  final int minutes;
  final int completedPlans;
  final int totalPlans;

  DailyStats({
    required this.date,
    required this.minutes,
    required this.completedPlans,
    required this.totalPlans,
  });
}
