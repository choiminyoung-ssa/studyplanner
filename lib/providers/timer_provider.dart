import 'package:flutter/material.dart';
import '../services/timer_service.dart';

class TimerProvider with ChangeNotifier {
  final TimerService _timerService = TimerService();

  TimerProvider() {
    _timerService.setOnTick(notifyListeners);
  }

  TimerState get state => _timerService.state;
  int get elapsedSeconds => _timerService.elapsedSeconds;

  String get formattedTime => _formatTime(elapsedSeconds);

  void startStopwatch() {
    _timerService.startStopwatch();
    notifyListeners();
  }

  void startPomodoro() {
    _timerService.startPomodoro();
    notifyListeners();
  }

  void pause() {
    _timerService.pause();
    notifyListeners();
  }

  void resume() {
    _timerService.resume();
    notifyListeners();
  }

  Future<void> stop(String userId, String? planId) async {
    await _timerService.stop(userId, planId);
    notifyListeners();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${remainingMinutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
    return '${remainingMinutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
