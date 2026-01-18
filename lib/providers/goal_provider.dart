import 'package:flutter/material.dart';
import '../models/study_goal.dart';
import '../services/firestore_service.dart';
import '../services/goal_service.dart';

class GoalProvider with ChangeNotifier {
  final GoalService _goalService = GoalService();
  StudyGoal? _dailyGoal;
  StudyGoal? _weeklyGoal;
  StudyGoal? _monthlyGoal;
  GoalAchievement? _currentAchievement;
  String? _errorMessage;
  String? _indexUrl;

  StudyGoal? get dailyGoal => _dailyGoal;
  StudyGoal? get weeklyGoal => _weeklyGoal;
  StudyGoal? get monthlyGoal => _monthlyGoal;
  GoalAchievement? get currentAchievement => _currentAchievement;
  String? get errorMessage => _errorMessage;
  String? get indexUrl => _indexUrl;

  Future<void> loadGoals(String userId, DateTime date) async {
    try {
      _errorMessage = null;
      _indexUrl = null;
      _dailyGoal = await _goalService.getGoalForPeriod(userId, GoalPeriod.daily, date);
      _weeklyGoal = await _goalService.getGoalForPeriod(userId, GoalPeriod.weekly, date);
      _monthlyGoal = await _goalService.getGoalForPeriod(userId, GoalPeriod.monthly, date);
    } on FirestoreIndexException catch (e) {
      _dailyGoal = null;
      _weeklyGoal = null;
      _monthlyGoal = null;
      _errorMessage = e.message;
      _indexUrl = e.indexUrl;
    } catch (e) {
      _dailyGoal = null;
      _weeklyGoal = null;
      _monthlyGoal = null;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      notifyListeners();
    }
  }

  Future<void> setGoal(String userId, StudyGoal goal) async {
    await _goalService.createGoal(goal);
    await loadGoals(userId, DateTime.now());
  }

  Future<void> calculateAchievement(String userId, StudyGoal goal) async {
    try {
      _errorMessage = null;
      _indexUrl = null;
      _currentAchievement = await _goalService.calculateAchievement(userId, goal);
    } on FirestoreIndexException catch (e) {
      _currentAchievement = null;
      _errorMessage = e.message;
      _indexUrl = e.indexUrl;
    } catch (e) {
      _currentAchievement = null;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      notifyListeners();
    }
  }

  void clearAchievement() {
    _currentAchievement = null;
    notifyListeners();
  }
}
