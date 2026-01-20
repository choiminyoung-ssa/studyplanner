import 'package:cloud_firestore/cloud_firestore.dart';
import 'subtask.dart';
import 'priority_matrix.dart';

class DailyPlan {
  final String id;
  final String userId;
  final DateTime date; // YYYY-MM-DD
  final String startTime; // HH:mm 형식 (예: "14:00")
  final String endTime; // HH:mm 형식 (예: "16:00")
  final String title;
  final String notes;
  final String subject;
  final String? subjectId; // 과목 ID
  final List<String> pageRanges; // 페이지 범위 목록 (예: ["45-67", "100-120"])
  final List<Subtask> subtasks; // 세부 목표 목록
  final String tag;
  final int priority;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? parentWeeklyId; // 연결된 주간 계획 ID
  final List<String> sessionIds; // 연결된 학습 세션 ID 목록
  final int totalStudiedSeconds; // 총 학습 시간 (초)
  final String? googleEventId; // Google Calendar 이벤트 ID
  final Importance importance; // 중요도 (아이젠하워 매트릭스)
  final Urgency urgency; // 긴급도 (아이젠하워 매트릭스)
  final String? timetableVersionId; // 시간표 버전 ID
  final DateTime createdAt;
  final DateTime updatedAt;

  DailyPlan({
    required this.id,
    required this.userId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.title,
    this.notes = '',
    this.subject = '',
    this.subjectId,
    this.pageRanges = const [],
    this.subtasks = const [],
    this.tag = '',
    this.priority = 2,
    this.isCompleted = false,
    this.completedAt,
    this.parentWeeklyId,
    this.sessionIds = const [],
    this.totalStudiedSeconds = 0,
    this.googleEventId,
    this.importance = Importance.high,
    this.urgency = Urgency.high,
    this.timetableVersionId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DailyPlan.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Parse subtasks from Firestore
    List<Subtask> subtasks = [];
    if (data['subtasks'] != null) {
      subtasks = (data['subtasks'] as List)
          .map((item) => Subtask.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    return DailyPlan(
      id: doc.id,
      userId: data['userId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      title: data['title'] ?? '',
      notes: data['notes'] ?? '',
      subject: data['subject'] ?? '',
      subjectId: data['subjectId'],
      pageRanges: List<String>.from(data['pageRanges'] ?? []),
      subtasks: subtasks,
      tag: data['tag'] ?? '',
      priority: data['priority'] ?? 2,
      isCompleted: data['isCompleted'] ?? false,
      completedAt: data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null,
      parentWeeklyId: data['parentWeeklyId'],
      sessionIds: List<String>.from(data['sessionIds'] ?? []),
      totalStudiedSeconds: data['totalStudiedSeconds'] ?? 0,
      googleEventId: data['googleEventId'],
      importance: data['importance'] != null
          ? Importance.values.firstWhere(
              (e) => e.name == data['importance'],
              orElse: () => Importance.high,
            )
          : Importance.high,
      urgency: data['urgency'] != null
          ? Urgency.values.firstWhere(
              (e) => e.name == data['urgency'],
              orElse: () => Urgency.high,
            )
          : Urgency.high,
      timetableVersionId: data['timetableVersionId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'startTime': startTime,
      'endTime': endTime,
      'title': title,
      'notes': notes,
      'subject': subject,
      'subjectId': subjectId,
      'pageRanges': pageRanges,
      'subtasks': subtasks.map((s) => s.toMap()).toList(),
      'tag': tag,
      'priority': priority,
      'isCompleted': isCompleted,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'parentWeeklyId': parentWeeklyId,
      'sessionIds': sessionIds,
      'totalStudiedSeconds': totalStudiedSeconds,
      'googleEventId': googleEventId,
      'importance': importance.name,
      'urgency': urgency.name,
      'timetableVersionId': timetableVersionId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// 아이젠하워 매트릭스 사분면 계산
  Quadrant get quadrant {
    return QuadrantExtension.fromPriority(importance, urgency);
  }

  DailyPlan copyWith({
    String? id,
    String? userId,
    DateTime? date,
    String? startTime,
    String? endTime,
    String? title,
    String? notes,
    String? subject,
    String? subjectId,
    List<String>? pageRanges,
    List<Subtask>? subtasks,
    String? tag,
    int? priority,
    bool? isCompleted,
    DateTime? completedAt,
    String? parentWeeklyId,
    List<String>? sessionIds,
    int? totalStudiedSeconds,
    String? googleEventId,
    Importance? importance,
    Urgency? urgency,
    String? timetableVersionId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailyPlan(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      subject: subject ?? this.subject,
      subjectId: subjectId ?? this.subjectId,
      pageRanges: pageRanges ?? this.pageRanges,
      subtasks: subtasks ?? this.subtasks,
      tag: tag ?? this.tag,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      parentWeeklyId: parentWeeklyId ?? this.parentWeeklyId,
      sessionIds: sessionIds ?? this.sessionIds,
      totalStudiedSeconds: totalStudiedSeconds ?? this.totalStudiedSeconds,
      googleEventId: googleEventId ?? this.googleEventId,
      importance: importance ?? this.importance,
      urgency: urgency ?? this.urgency,
      timetableVersionId: timetableVersionId ?? this.timetableVersionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int get estimatedMinutes => subtasks.fold(0, (total, s) => total + s.estimatedMinutes);

  int get actualMinutes => totalStudiedSeconds ~/ 60;

  double get timeAccuracy {
    if (estimatedMinutes <= 0) return 0.0;
    return ((actualMinutes / estimatedMinutes * 100).clamp(0.0, 200.0)).toDouble();
  }

  // 시간 블록의 시작 시간을 DateTime으로 변환
  DateTime get startDateTime {
    final parts = startTime.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  // 시간 블록의 종료 시간을 DateTime으로 변환
  DateTime get endDateTime {
    final parts = endTime.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }
}
