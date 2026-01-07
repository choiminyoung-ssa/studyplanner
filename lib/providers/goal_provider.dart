import 'package:flutter/material.dart';
import '../models/study_goal.dart';
import '../services/goal_service.dart';

class GoalProvider with ChangeNotifier {
  final GoalService _goalService = GoalService();
  StudyGoal? _dailyGoal;
  StudyGoal? _weeklyGoal;
  StudyGoal? _monthlyGoal;
  GoalAchievement? _currentAchievement;

  StudyGoal? get dailyGoal => _dailyGoal;
  StudyGoal? get weeklyGoal => _weeklyGoal;
  StudyGoal? get monthlyGoal => _monthlyGoal;
  GoalAchievement? get currentAchievement => _currentAchievement;

  Future<void> loadGoals(String userId, DateTime date) async {
    _dailyGoal = await _goalService.getGoalForPeriod(userId, GoalPeriod.daily, date);
    _weeklyGoal = await _goalService.getGoalForPeriod(userId, GoalPeriod.weekly, date);
    _monthlyGoal = await _goalService.getGoalForPeriod(userId, GoalPeriod.monthly, date);
    notifyListeners();
  }

  Future<void> setGoal(String userId, StudyGoal goal) async {
    await _goalService.createGoal(goal);
    await loadGoals(userId, DateTime.now());
  }

  Future<void> calculateAchievement(String userId, StudyGoal goal) async {
    _currentAchievement = await _goalService.calculateAchievement(userId, goal);
    notifyListeners();
  }
}
