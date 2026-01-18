import 'package:cloud_firestore/cloud_firestore.dart';
import 'subtask.dart';

class MonthlyPlan {
  final String id;
  final String userId;
  final String month; // YYYY-MM 형식
  final String title;
  final String notes;
  final String subject;
  final String? subjectId; // 과목 ID
  final List<String> pageRanges; // 페이지 범위 (예: "45-67")
  final DateTime? startDate; // 목표 시작일 (선택사항)
  final DateTime? endDate; // 목표 종료일 (선택사항)
  final List<Subtask> subtasks; // 세부 목표 목록
  final String tag;
  final int priority; // 1: 높음, 2: 중간, 3: 낮음
  final bool isCompleted;
  final DateTime? completedAt;
  final List<String> relatedWeeklyIds; // 연결된 주간 계획 ID 목록
  final DateTime createdAt;
  final DateTime updatedAt;

  MonthlyPlan({
    required this.id,
    required this.userId,
    required this.month,
    required this.title,
    this.notes = '',
    this.subject = '',
    this.subjectId,
    this.pageRanges = const [],
    this.startDate,
    this.endDate,
    this.subtasks = const [],
    this.tag = '',
    this.priority = 2,
    this.isCompleted = false,
    this.completedAt,
    this.relatedWeeklyIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  // Firestore 문서로부터 MonthlyPlan 객체 생성
  factory MonthlyPlan.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Parse subtasks from Firestore
    List<Subtask> subtasks = [];
    if (data['subtasks'] != null) {
      subtasks = (data['subtasks'] as List)
          .map((item) => Subtask.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    return MonthlyPlan(
      id: doc.id,
      userId: data['userId'] ?? '',
      month: data['month'] ?? '',
      title: data['title'] ?? '',
      notes: data['notes'] ?? '',
      subject: data['subject'] ?? '',
      subjectId: data['subjectId'],
      pageRanges: List<String>.from(data['pageRanges'] ?? []),
      subtasks: subtasks,
      tag: data['tag'] ?? '',
      startDate: data['startDate'] != null ? (data['startDate'] as Timestamp).toDate() : null,
      endDate: data['endDate'] != null ? (data['endDate'] as Timestamp).toDate() : null,
      priority: data['priority'] ?? 2,
      isCompleted: data['isCompleted'] ?? false,
      completedAt: data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null,
      relatedWeeklyIds: List<String>.from(data['relatedWeeklyIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Firestore에 저장할 맵으로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'month': month,
      'title': title,
      'notes': notes,
      'subject': subject,
      'subjectId': subjectId,
      'pageRanges': pageRanges,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'subtasks': subtasks.map((s) => s.toMap()).toList(),
      'tag': tag,
      'priority': priority,
      'isCompleted': isCompleted,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'relatedWeeklyIds': relatedWeeklyIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // 복사 메서드
  MonthlyPlan copyWith({
    String? id,
    String? userId,
    String? month,
    String? title,
    String? notes,
    String? subject,
    String? subjectId,
    List<String>? pageRanges,
    DateTime? startDate,
    DateTime? endDate,
    List<Subtask>? subtasks,
    String? tag,
    int? priority,
    bool? isCompleted,
    DateTime? completedAt,
    List<String>? relatedWeeklyIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MonthlyPlan(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      month: month ?? this.month,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      subject: subject ?? this.subject,
      subjectId: subjectId ?? this.subjectId,
      pageRanges: pageRanges ?? this.pageRanges,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      subtasks: subtasks ?? this.subtasks,
      tag: tag ?? this.tag,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      relatedWeeklyIds: relatedWeeklyIds ?? this.relatedWeeklyIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
