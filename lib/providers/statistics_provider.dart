import 'package:flutter/material.dart';
import '../models/statistics.dart';
import '../services/firestore_service.dart';
import '../services/statistics_service.dart';
import '../utils/date_utils.dart';

enum StatsPeriod { day, week, month, custom }

class StatisticsProvider with ChangeNotifier {
  final StatisticsService _statisticsService = StatisticsService();
  StudyStatistics? _currentStats;
  DateTime _selectedDate = DateTime.now();
  StatsPeriod _period = StatsPeriod.week;
  DateTime? _customStart;
  DateTime? _customEnd;
  String? _subjectId;
  bool _completedOnly = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _indexUrl;

  StudyStatistics? get currentStats => _currentStats;
  StatsPeriod get period => _period;
  DateTime get selectedDate => _selectedDate;
  DateTime? get customStart => _customStart;
  DateTime? get customEnd => _customEnd;
  String? get subjectId => _subjectId;
  bool get completedOnly => _completedOnly;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get indexUrl => _indexUrl;

  Future<void> loadStatistics(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    _indexUrl = null;
    notifyListeners();
    final range = _getDateRange();
    try {
      _currentStats = await _statisticsService.getStatistics(
        userId,
        range.$1,
        range.$2,
        subjectId: _subjectId,
        completedOnly: _completedOnly,
      );
    } on FirestoreIndexException catch (e) {
      _currentStats = null;
      _errorMessage = e.message;
      _indexUrl = e.indexUrl;
    } catch (e) {
      _currentStats = null;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void changePeriod(StatsPeriod newPeriod) {
    _period = newPeriod;
    if (newPeriod != StatsPeriod.custom) {
      _customStart = null;
      _customEnd = null;
    }
    notifyListeners();
  }

  void changeDate(DateTime newDate) {
    _selectedDate = newDate;
    notifyListeners();
  }

  void setCustomRange(DateTime start, DateTime end) {
    _customStart = start;
    _customEnd = end;
    _period = StatsPeriod.custom;
    notifyListeners();
  }

  void setSubjectFilter(String? subjectId) {
    _subjectId = subjectId;
    notifyListeners();
  }

  void setCompletedOnly(bool value) {
    _completedOnly = value;
    notifyListeners();
  }

  void resetFilters() {
    _period = StatsPeriod.week;
    _selectedDate = DateTime.now();
    _customStart = null;
    _customEnd = null;
    _subjectId = null;
    _completedOnly = false;
    notifyListeners();
  }

  (DateTime, DateTime) _getDateRange() {
    switch (_period) {
      case StatsPeriod.day:
        return (
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
        );
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
      case StatsPeriod.custom:
        if (_customStart != null && _customEnd != null) {
          return (_customStart!, _customEnd!);
        }
        return (
          DateHelper.getWeekStartDate(_selectedDate),
          DateHelper.getWeekEndDate(_selectedDate),
        );
    }
  }
}
