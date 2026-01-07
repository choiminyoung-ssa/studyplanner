import '../models/study_goal.dart';
import '../services/firestore_service.dart';
import '../services/statistics_service.dart';
import '../utils/date_utils.dart';

class GoalService {
  final FirestoreService _firestoreService = FirestoreService();
  final StatisticsService _statisticsService = StatisticsService();

  Future<void> createGoal(StudyGoal goal) async {
    await _firestoreService.createStudyGoal(goal);
  }

  Future<StudyGoal?> getGoalForPeriod(String userId, GoalPeriod period, DateTime date) async {
    switch (period) {
      case GoalPeriod.daily:
        return _firestoreService.getDailyGoal(userId, date);
      case GoalPeriod.weekly:
        return _firestoreService.getWeeklyGoal(userId, DateHelper.getWeekId(date));
      case GoalPeriod.monthly:
        return _firestoreService.getMonthlyGoal(userId, DateHelper.toMonthString(date));
    }
  }

  Future<GoalAchievement> calculateAchievement(String userId, StudyGoal goal) async {
    final range = _getDateRange(goal);
    final stats = await _statisticsService.getStatistics(userId, range.$1, range.$2);
    final achievementRate = goal.calculateAchievement(stats.totalMinutes);

    Map<String, double>? subjectAchievement;
    if (goal.subjectTargets != null) {
      subjectAchievement = {};
      goal.subjectTargets!.forEach((subjectId, target) {
        final actual = stats.subjectMinutes[subjectId] ?? 0;
        subjectAchievement![subjectId] = (actual / target * 100).clamp(0.0, 200.0);
      });
    }

    return GoalAchievement(
      goal: goal,
      actualMinutes: stats.totalMinutes,
      achievementRate: achievementRate,
      subjectAchievement: subjectAchievement,
    );
  }

  (DateTime, DateTime) _getDateRange(StudyGoal goal) {
    switch (goal.period) {
      case GoalPeriod.daily:
        final date = goal.specificDate ?? DateTime.now();
        return (
          DateTime(date.year, date.month, date.day),
          DateTime(date.year, date.month, date.day, 23, 59, 59),
        );
      case GoalPeriod.weekly:
        final date = DateTime.now();
        return (
          DateHelper.getWeekStartDate(date),
          DateHelper.getWeekEndDate(date),
        );
      case GoalPeriod.monthly:
        final date = DateTime.now();
        return (
          DateTime(date.year, date.month, 1),
          DateTime(date.year, date.month + 1, 0),
        );
    }
  }
}
