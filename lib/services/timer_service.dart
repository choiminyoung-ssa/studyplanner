import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/study_session.dart';
import 'firestore_service.dart';

enum TimerState { idle, running, paused, completed }

class TimerService {
  final FirestoreService _firestoreService = FirestoreService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Timer? _timer;
  Timer? _pomodoroTimer;
  DateTime? _startTime;
  DateTime? _lastPauseTime;
  int _elapsedSeconds = 0;
  int _pausedSeconds = 0;
  TimerState _state = TimerState.idle;
  SessionType _sessionType = SessionType.stopwatch;
  VoidCallback? _onTick;
  int _pomodoroWorkMinutes = 25;

  int get elapsedSeconds => _elapsedSeconds;
  int get pausedSeconds => _pausedSeconds;
  TimerState get state => _state;
  SessionType get sessionType => _sessionType;

  void setOnTick(VoidCallback onTick) {
    _onTick = onTick;
  }

  void startStopwatch() {
    _reset();
    _sessionType = SessionType.stopwatch;
    _startTime = DateTime.now();
    _state = TimerState.running;
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    WakelockPlus.enable();
    _onTick?.call();
  }

  void startPomodoro({int workMinutes = 25, int breakMinutes = 5}) {
    _reset();
    _sessionType = SessionType.pomodoro;
    _pomodoroWorkMinutes = workMinutes;
    _startTime = DateTime.now();
    _state = TimerState.running;
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    _pomodoroTimer = Timer(Duration(minutes: workMinutes), _onPomodoroComplete);
    WakelockPlus.enable();
    _onTick?.call();
  }

  void pause() {
    if (_state != TimerState.running) return;
    _lastPauseTime = DateTime.now();
    _state = TimerState.paused;
    _timer?.cancel();
    _pomodoroTimer?.cancel();
    WakelockPlus.disable();
    _onTick?.call();
  }

  void resume() {
    if (_state != TimerState.paused) return;
    if (_lastPauseTime != null) {
      _pausedSeconds += DateTime.now().difference(_lastPauseTime!).inSeconds;
    }
    _state = TimerState.running;
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    if (_sessionType == SessionType.pomodoro) {
      final remaining = Duration(minutes: _pomodoroWorkMinutes) - Duration(seconds: _elapsedSeconds);
      if (!remaining.isNegative) {
        _pomodoroTimer = Timer(remaining, _onPomodoroComplete);
      }
    }
    WakelockPlus.enable();
    _onTick?.call();
  }

  Future<StudySession> stop(String userId, String? planId) async {
    _timer?.cancel();
    _pomodoroTimer?.cancel();
    WakelockPlus.disable();

    final end = DateTime.now();
    final rounds = <PomodoroRound>[];
    if (_sessionType == SessionType.pomodoro && _startTime != null) {
      rounds.add(
        PomodoroRound(
          roundNumber: 1,
          startTime: _startTime!,
          endTime: end,
          completed: _elapsedSeconds >= _pomodoroWorkMinutes * 60,
          actualSeconds: _elapsedSeconds,
        ),
      );
    }

    final session = StudySession(
      id: '',
      userId: userId,
      planId: planId,
      startTime: _startTime ?? end,
      endTime: end,
      totalSeconds: _elapsedSeconds,
      pausedSeconds: _pausedSeconds,
      type: _sessionType,
      pomodoroRounds: rounds,
    );

    final sessionId = await _firestoreService.saveStudySession(session);

    if (planId != null && planId.isNotEmpty) {
      await _firestoreService.updateDailyPlan(planId, {
        'totalStudiedSeconds': FieldValue.increment(session.actualStudySeconds),
        'sessionIds': FieldValue.arrayUnion([sessionId]),
      });
    }

    _reset();
    _onTick?.call();
    return session;
  }

  void _tick(Timer timer) {
    _elapsedSeconds++;
    _onTick?.call();
  }

  Future<void> _onPomodoroComplete() async {
    _state = TimerState.completed;
    _timer?.cancel();
    _pomodoroTimer?.cancel();
    try {
      await _audioPlayer.play(AssetSource('audio/pomodoro_end.wav'));
    } catch (_) {
      SystemSound.play(SystemSoundType.alert);
    }
    WakelockPlus.disable();
    _onTick?.call();
  }

  void _reset() {
    _timer?.cancel();
    _pomodoroTimer?.cancel();
    _startTime = null;
    _lastPauseTime = null;
    _elapsedSeconds = 0;
    _pausedSeconds = 0;
    _state = TimerState.idle;
  }
}
