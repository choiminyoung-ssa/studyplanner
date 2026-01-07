import 'package:flutter/material.dart';
import '../models/statistics.dart';
import '../services/statistics_service.dart';
import '../utils/date_utils.dart';

enum StatsPeriod { week, month, year }

class StatisticsProvider with ChangeNotifier {
  final StatisticsService _statisticsService = StatisticsService();
  StudyStatistics? _currentStats;
  DateTime _selectedDate = DateTime.now();
  StatsPeriod _period = StatsPeriod.week;

  StudyStatistics? get currentStats => _currentStats;
  StatsPeriod get period => _period;
  DateTime get selectedDate => _selectedDate;

  Future<void> loadStatistics(String userId) async {
    final range = _getDateRange();
    _currentStats = await _statisticsService.getStatistics(userId, range.$1, range.$2);
    notifyListeners();
  }

  void changePeriod(StatsPeriod newPeriod) {
    _period = newPeriod;
    notifyListeners();
  }

  void changeDate(DateTime newDate) {
    _selectedDate = newDate;
    notifyListeners();
  }

  (DateTime, DateTime) _getDateRange() {
    switch (_period) {
      case StatsPeriod.week:
        return (
          DateHelper.getWeekStartDate(_selectedDate),
          DateHelper.getWeekEndDate(_selectedDate),
        );
      case StatsPeriod.month:
        return (
          DateTime(_selectedDate.year, _selectedDate.month, 1),
          DateTime(_selectedDate.year, _selectedDate.month + 1, 0),
        );
      case StatsPeriod.year:
        return (
          DateTime(_selectedDate.year, 1, 1),
          DateTime(_selectedDate.year, 12, 31),
        );
    }
  }
}
