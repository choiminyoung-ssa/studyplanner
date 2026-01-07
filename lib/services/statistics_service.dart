import '../models/statistics.dart';
import '../services/firestore_service.dart';

class StatisticsService {
  final FirestoreService _firestoreService = FirestoreService();

  Future<StudyStatistics> getStatistics(String userId, DateTime startDate, DateTime endDate) async {
    final plans = await _firestoreService.getDailyPlansByDateRange(userId, startDate, endDate);

    int totalMinutes = 0;
    for (final plan in plans) {
      totalMinutes += plan.actualMinutes;
    }

    final completedPlans = plans.where((p) => p.isCompleted).length;
    final totalPlans = plans.length;

    final Map<String, int> subjectMinutes = {};
    for (final plan in plans) {
      if (plan.subjectId != null) {
        subjectMinutes[plan.subjectId!] =
            (subjectMinutes[plan.subjectId!] ?? 0) + plan.actualMinutes;
      }
    }

    final List<DailyStats> dailyStats = [];
    for (var date = startDate;
        !date.isAfter(endDate);
        date = date.add(const Duration(days: 1))) {
      final dayPlans = plans.where((p) =>
          p.date.year == date.year && p.date.month == date.month && p.date.day == date.day).toList();
      dailyStats.add(
        DailyStats(
          date: date,
          minutes: dayPlans.fold(0, (sum, p) => sum + p.actualMinutes),
          completedPlans: dayPlans.where((p) => p.isCompleted).length,
          totalPlans: dayPlans.length,
        ),
      );
    }

    return StudyStatistics(
      startDate: startDate,
      endDate: endDate,
      totalMinutes: totalMinutes,
      completedPlans: completedPlans,
      totalPlans: totalPlans,
      subjectMinutes: subjectMinutes,
      dailyStats: dailyStats,
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
}
