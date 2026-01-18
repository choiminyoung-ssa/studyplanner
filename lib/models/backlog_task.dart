import 'package:cloud_firestore/cloud_firestore.dart';
import 'subtask.dart';

class BacklogTask {
  final String id;
  final String userId;
  final String title;
  final String notes;
  final String? subjectId;
  final int priority;
  final List<Subtask> subtasks;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  BacklogTask({
    required this.id,
    required this.userId,
    required this.title,
    this.notes = '',
    this.subjectId,
    this.priority = 2,
    this.subtasks = const [],
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BacklogTask.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final subtasks = (data['subtasks'] as List?)
            ?.map((item) => Subtask.fromMap(item as Map<String, dynamic>))
            .toList() ??
        [];
    return BacklogTask(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      notes: data['notes'] ?? '',
      subjectId: data['subjectId'],
      priority: data['priority'] ?? 2,
      subtasks: subtasks,
      isCompleted: data['isCompleted'] ?? false,
      completedAt: data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'notes': notes,
      'subjectId': subjectId,
      'priority': priority,
      'subtasks': subtasks.map((s) => s.toMap()).toList(),
      'isCompleted': isCompleted,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  BacklogTask copyWith({
    String? id,
    String? userId,
    String? title,
    String? notes,
    String? subjectId,
    int? priority,
    List<Subtask>? subtasks,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BacklogTask(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      subjectId: subjectId ?? this.subjectId,
      priority: priority ?? this.priority,
      subtasks: subtasks ?? this.subtasks,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  double get completionRatio {
    if (subtasks.isEmpty) return isCompleted ? 1.0 : 0.0;
    final completed = subtasks.where((s) => s.isCompleted).length;
    return completed / subtasks.length;
  }
}
