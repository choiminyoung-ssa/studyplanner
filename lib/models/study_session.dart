import 'package:cloud_firestore/cloud_firestore.dart';

enum SessionType { pomodoro, stopwatch }

class PomodoroRound {
  final int roundNumber;
  final DateTime startTime;
  final DateTime endTime;
  final bool completed;
  final int actualSeconds;

  PomodoroRound({
    required this.roundNumber,
    required this.startTime,
    required this.endTime,
    required this.completed,
    required this.actualSeconds,
  });

  factory PomodoroRound.fromMap(Map<String, dynamic> map) {
    return PomodoroRound(
      roundNumber: map['roundNumber'] ?? 0,
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: (map['endTime'] as Timestamp).toDate(),
      completed: map['completed'] ?? false,
      actualSeconds: map['actualSeconds'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roundNumber': roundNumber,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'completed': completed,
      'actualSeconds': actualSeconds,
    };
  }
}

class StudySession {
  final String id;
  final String userId;
  final String? planId;
  final DateTime startTime;
  final DateTime? endTime;
  final int totalSeconds;
  final int pausedSeconds;
  final SessionType type;
  final List<PomodoroRound> pomodoroRounds;

  StudySession({
    required this.id,
    required this.userId,
    this.planId,
    required this.startTime,
    this.endTime,
    required this.totalSeconds,
    required this.pausedSeconds,
    required this.type,
    this.pomodoroRounds = const [],
  });

  int get actualStudySeconds => totalSeconds - pausedSeconds;

  String get formattedDuration {
    final seconds = actualStudySeconds;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours > 0) {
      return '${hours}시간 ${remainingMinutes}분';
    }
    return '${remainingMinutes}분 ${remainingSeconds}초';
  }

  factory StudySession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rounds = (data['pomodoroRounds'] as List<dynamic>?)
            ?.map((e) => PomodoroRound.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    return StudySession(
      id: doc.id,
      userId: data['userId'] ?? '',
      planId: data['planId'],
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: data['endTime'] != null ? (data['endTime'] as Timestamp).toDate() : null,
      totalSeconds: data['totalSeconds'] ?? 0,
      pausedSeconds: data['pausedSeconds'] ?? 0,
      type: (data['type'] == 'pomodoro') ? SessionType.pomodoro : SessionType.stopwatch,
      pomodoroRounds: rounds,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'planId': planId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'totalSeconds': totalSeconds,
      'pausedSeconds': pausedSeconds,
      'type': type.name,
      'pomodoroRounds': pomodoroRounds.map((round) => round.toMap()).toList(),
      'createdAt': Timestamp.fromDate(DateTime.now()),
    };
  }
}
