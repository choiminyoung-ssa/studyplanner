enum GoalPeriod { daily, weekly, monthly }

class StudyGoal {
  final String id;
  final String userId;
  final GoalPeriod period;
  final int targetMinutes;
  final DateTime? specificDate;
  final String? weekId;
  final String? month;
  final Map<String, int>? subjectTargets;
  final bool isActive;
  final DateTime createdAt;

  StudyGoal({
    required this.id,
    required this.userId,
    required this.period,
    required this.targetMinutes,
    this.specificDate,
    this.weekId,
    this.month,
    this.subjectTargets,
    this.isActive = true,
    required this.createdAt,
  });

  double calculateAchievement(int actualMinutes) {
    if (targetMinutes <= 0) return 0.0;
    return ((actualMinutes / targetMinutes * 100).clamp(0.0, 200.0)).toDouble();
  }
}

class GoalAchievement {
  final StudyGoal goal;
  final int actualMinutes;
  final double achievementRate;
  final Map<String, double>? subjectAchievement;

  GoalAchievement({
    required this.goal,
    required this.actualMinutes,
    required this.achievementRate,
    this.subjectAchievement,
  });

  bool get isAchieved => achievementRate >= 100;

  String get statusEmoji {
    if (achievementRate >= 100) return '🎉';
    if (achievementRate >= 75) return '💪';
    return '📝';
  }
}
