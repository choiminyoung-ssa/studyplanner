import 'package:cloud_firestore/cloud_firestore.dart';
import 'subtask.dart';

class WeeklyPlan {
  final String id;
  final String userId;
  final DateTime weekStartDate; // 주의 시작일(월요일)
  final DateTime weekEndDate; // 주의 종료일(일요일)
  final DateTime date; // 이 주간 항목이 배치된 날짜
  final String title;
  final String notes;
  final String subject;
  final String? subjectId; // 과목 ID
  final List<String> pageRanges; // 페이지 범위 (예: "45-67")
  final List<Subtask> subtasks; // 세부 목표 목록
  final String tag;
  final int priority;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? parentMonthlyId; // 연결된 월간 계획 ID
  final List<String> relatedDailyIds; // 연결된 일간 타임블록 ID 목록
  final DateTime createdAt;
  final DateTime updatedAt;

  WeeklyPlan({
    required this.id,
    required this.userId,
    required this.weekStartDate,
    required this.weekEndDate,
    required this.date,
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
    this.parentMonthlyId,
    this.relatedDailyIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory WeeklyPlan.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Parse subtasks from Firestore
    List<Subtask> subtasks = [];
    if (data['subtasks'] != null) {
      subtasks = (data['subtasks'] as List)
          .map((item) => Subtask.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    return WeeklyPlan(
      id: doc.id,
      userId: data['userId'] ?? '',
      weekStartDate: (data['weekStartDate'] as Timestamp).toDate(),
      weekEndDate: (data['weekEndDate'] as Timestamp).toDate(),
      date: (data['date'] as Timestamp).toDate(),
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
      parentMonthlyId: data['parentMonthlyId'],
      relatedDailyIds: List<String>.from(data['relatedDailyIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'weekStartDate': Timestamp.fromDate(weekStartDate),
      'weekEndDate': Timestamp.fromDate(weekEndDate),
      'date': Timestamp.fromDate(date),
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
      'parentMonthlyId': parentMonthlyId,
      'relatedDailyIds': relatedDailyIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  WeeklyPlan copyWith({
    String? id,
    String? userId,
    DateTime? weekStartDate,
    DateTime? weekEndDate,
    DateTime? date,
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
    String? parentMonthlyId,
    List<String>? relatedDailyIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WeeklyPlan(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      weekStartDate: weekStartDate ?? this.weekStartDate,
      weekEndDate: weekEndDate ?? this.weekEndDate,
      date: date ?? this.date,
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
      parentMonthlyId: parentMonthlyId ?? this.parentMonthlyId,
      relatedDailyIds: relatedDailyIds ?? this.relatedDailyIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
