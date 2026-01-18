import '../models/statistics.dart';
import '../models/daily_plan.dart';
import '../services/firestore_service.dart';

class StatisticsService {
  final FirestoreService _firestoreService = FirestoreService();

  Future<StudyStatistics> getStatistics(
    String userId,
    DateTime startDate,
    DateTime endDate, {
    String? subjectId,
    bool completedOnly = false,
  }) async {
    var plans = await _firestoreService.getDailyPlansByDateRange(userId, startDate, endDate);
    if (subjectId != null && subjectId.isNotEmpty) {
      plans = plans.where((plan) => plan.subjectId == subjectId).toList();
    }
    if (completedOnly) {
      plans = plans.where((plan) => plan.isCompleted).toList();
    }

    int totalMinutes = 0;
    int totalSubtasks = 0;
    int completedSubtasks = 0;
    int totalUnits = 0;
    int completedUnits = 0;
    for (final plan in plans) {
      totalMinutes += _effectiveMinutes(plan);
      final subtaskStats = _collectSubtaskStats(plan);
      totalSubtasks += subtaskStats.totalSubtasks;
      completedSubtasks += subtaskStats.completedSubtasks;
      totalUnits += subtaskStats.totalUnits;
      completedUnits += subtaskStats.completedUnits;
    }

    final completedPlans = plans.where((p) => p.isCompleted).length;
    final totalPlans = plans.length;

    final Map<String, SubjectStats> subjectStats = {};
    for (final plan in plans) {
      if (plan.subjectId != null) {
        final subjectId = plan.subjectId!;
        final minutes = _effectiveMinutes(plan);
        final subtaskStats = _collectSubtaskStats(plan);
        final current = subjectStats[subjectId];
        subjectStats[subjectId] = SubjectStats(
          minutes: (current?.minutes ?? 0) + minutes,
          totalSubtasks: (current?.totalSubtasks ?? 0) + subtaskStats.totalSubtasks,
          completedSubtasks: (current?.completedSubtasks ?? 0) + subtaskStats.completedSubtasks,
          totalUnits: (current?.totalUnits ?? 0) + subtaskStats.totalUnits,
          completedUnits: (current?.completedUnits ?? 0) + subtaskStats.completedUnits,
        );
      }
    }

    final List<DailyStats> dailyStats = [];
    for (var date = startDate;
        !date.isAfter(endDate);
        date = date.add(const Duration(days: 1))) {
      final dayPlans = plans.where((p) =>
          p.date.year == date.year && p.date.month == date.month && p.date.day == date.day).toList();
      int daySubtasks = 0;
      int daySubtasksCompleted = 0;
      int dayUnits = 0;
      int dayUnitsCompleted = 0;
      for (final plan in dayPlans) {
        final subtaskStats = _collectSubtaskStats(plan);
        daySubtasks += subtaskStats.totalSubtasks;
        daySubtasksCompleted += subtaskStats.completedSubtasks;
        dayUnits += subtaskStats.totalUnits;
        dayUnitsCompleted += subtaskStats.completedUnits;
      }
      dailyStats.add(
        DailyStats(
          date: date,
          minutes: dayPlans.fold(0, (sum, p) => sum + _effectiveMinutes(p)),
          completedPlans: dayPlans.where((p) => p.isCompleted).length,
          totalPlans: dayPlans.length,
          completedSubtasks: daySubtasksCompleted,
          totalSubtasks: daySubtasks,
          completedUnits: dayUnitsCompleted,
          totalUnits: dayUnits,
        ),
      );
    }

    return StudyStatistics(
      startDate: startDate,
      endDate: endDate,
      totalMinutes: totalMinutes,
      completedPlans: completedPlans,
      totalPlans: totalPlans,
      totalSubtasks: totalSubtasks,
      completedSubtasks: completedSubtasks,
      totalUnits: totalUnits,
      completedUnits: completedUnits,
      subjectStats: subjectStats,
      dailyStats: dailyStats,
      plans: plans,
    );
  }

  Future<StudyStatistics> getWeeklyStatistics(String userId, DateTime weekStart) async {
    final end = weekStart.add(const Duration(days: 6));
    return getStatistics(userId, weekStart, end);
  }

  Future<StudyStatistics> getMonthlyStatistics(String userId, String month) async {
    final parts = month.split('-');
    final year = int.parse(parts[0]);
    final monthNum = int.parse(parts[1]);
    final start = DateTime(year, monthNum, 1);
    final end = DateTime(year, monthNum + 1, 0);
    return getStatistics(userId, start, end);
  }

  int _effectiveMinutes(DailyPlan plan) {
    final actual = plan.actualMinutes;
    if (actual > 0) return actual;
    final partsStart = plan.startTime.split(':');
    final partsEnd = plan.endTime.split(':');
    if (partsStart.length < 2 || partsEnd.length < 2) return 0;
    final startHour = int.tryParse(partsStart[0]) ?? 0;
    final startMin = int.tryParse(partsStart[1]) ?? 0;
    final endHour = int.tryParse(partsEnd[0]) ?? 0;
    final endMin = int.tryParse(partsEnd[1]) ?? 0;
    final start = startHour * 60 + startMin;
    final end = endHour * 60 + endMin;
    final diff = end - start;
    return diff > 0 ? diff : 0;
  }

  _SubtaskStats _collectSubtaskStats(DailyPlan plan) {
    int totalSubtasks = plan.subtasks.length;
    int completedSubtasks = plan.subtasks.where((s) => s.isCompleted).length;
    int totalUnits = 0;
    int completedUnits = 0;

    for (final subtask in plan.subtasks) {
      final range = _parseRange(subtask.pageRange);
      if (range == null) continue;
      final units = range.$2 - range.$1 + 1;
      if (units <= 0) continue;
      totalUnits += units;

      if (subtask.completedPage != null) {
        final completed = (subtask.completedPage! - range.$1 + 1).clamp(0, units);
        completedUnits += completed;
      } else if (subtask.isCompleted) {
        completedUnits += units;
      }
    }

    return _SubtaskStats(
      totalSubtasks: totalSubtasks,
      completedSubtasks: completedSubtasks,
      totalUnits: totalUnits,
      completedUnits: completedUnits,
    );
  }

  (int, int)? _parseRange(String? rangeText) {
    if (rangeText == null || rangeText.trim().isEmpty) return null;
    final parts = rangeText.split('-');
    if (parts.length != 2) return null;
    final start = int.tryParse(parts[0].trim());
    final end = int.tryParse(parts[1].trim());
    if (start == null || end == null) return null;
    if (end < start) return null;
    return (start, end);
  }
}

class _SubtaskStats {
  final int totalSubtasks;
  final int completedSubtasks;
  final int totalUnits;
  final int completedUnits;

  const _SubtaskStats({
    required this.totalSubtasks,
    required this.completedSubtasks,
    required this.totalUnits,
    required this.completedUnits,
  });
}
