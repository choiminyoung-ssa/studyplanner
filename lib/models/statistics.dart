import 'daily_plan.dart';

class StudyStatistics {
  final DateTime startDate;
  final DateTime endDate;
  final int totalMinutes;
  final int completedPlans;
  final int totalPlans;
  final int totalSubtasks;
  final int completedSubtasks;
  final int totalUnits;
  final int completedUnits;
  final Map<String, SubjectStats> subjectStats;
  final List<DailyStats> dailyStats;
  final List<DailyPlan> plans;

  StudyStatistics({
    required this.startDate,
    required this.endDate,
    required this.totalMinutes,
    required this.completedPlans,
    required this.totalPlans,
    required this.totalSubtasks,
    required this.completedSubtasks,
    required this.totalUnits,
    required this.completedUnits,
    required this.subjectStats,
    required this.dailyStats,
    required this.plans,
  });

  double get completionRate => totalPlans > 0 ? (completedPlans / totalPlans * 100) : 0;

  double get averageDailyMinutes {
    final days = endDate.difference(startDate).inDays + 1;
    if (days <= 0) return 0;
    return totalMinutes / days;
  }
}

class SubjectStats {
  final int minutes;
  final int totalSubtasks;
  final int completedSubtasks;
  final int totalUnits;
  final int completedUnits;

  const SubjectStats({
    required this.minutes,
    required this.totalSubtasks,
    required this.completedSubtasks,
    required this.totalUnits,
    required this.completedUnits,
  });

  SubjectStats copyWith({
    int? minutes,
    int? totalSubtasks,
    int? completedSubtasks,
    int? totalUnits,
    int? completedUnits,
  }) {
    return SubjectStats(
      minutes: minutes ?? this.minutes,
      totalSubtasks: totalSubtasks ?? this.totalSubtasks,
      completedSubtasks: completedSubtasks ?? this.completedSubtasks,
      totalUnits: totalUnits ?? this.totalUnits,
      completedUnits: completedUnits ?? this.completedUnits,
    );
  }
}

class DailyStats {
  final DateTime date;
  final int minutes;
  final int completedPlans;
  final int totalPlans;
  final int completedSubtasks;
  final int totalSubtasks;
  final int completedUnits;
  final int totalUnits;

  DailyStats({
    required this.date,
    required this.minutes,
    required this.completedPlans,
    required this.totalPlans,
    required this.completedSubtasks,
    required this.totalSubtasks,
    required this.completedUnits,
    required this.totalUnits,
  });
}
