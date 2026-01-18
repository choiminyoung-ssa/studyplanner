import 'package:cloud_firestore/cloud_firestore.dart';

enum StudyResourceType {
  lecture,
  book,
}

extension StudyResourceTypeX on StudyResourceType {
  String get label {
    switch (this) {
      case StudyResourceType.lecture:
        return '강의';
      case StudyResourceType.book:
        return '문제집';
    }
  }

  String get unitLabel {
    switch (this) {
      case StudyResourceType.lecture:
        return '강';
      case StudyResourceType.book:
        return '페이지';
    }
  }

  String get rangeLabel {
    switch (this) {
      case StudyResourceType.lecture:
        return '강의';
      case StudyResourceType.book:
        return '페이지';
    }
  }
}

StudyResourceType studyResourceTypeFromString(String? value) {
  switch (value) {
    case 'lecture':
      return StudyResourceType.lecture;
    case 'book':
    default:
      return StudyResourceType.book;
  }
}

class StudyResource {
  final String id;
  final String userId;
  final String title;
  final StudyResourceType type;
  final String notes;
  final int? totalUnits;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudyResource({
    required this.id,
    required this.userId,
    required this.title,
    required this.type,
    this.notes = '',
    this.totalUnits,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudyResource.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return StudyResource(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      type: studyResourceTypeFromString(data['type'] as String?),
      notes: data['notes'] ?? '',
      totalUnits: data['totalUnits'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'type': type.name,
      'notes': notes,
      'totalUnits': totalUnits,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  StudyResource copyWith({
    String? id,
    String? userId,
    String? title,
    StudyResourceType? type,
    String? notes,
    int? totalUnits,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudyResource(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      totalUnits: totalUnits ?? this.totalUnits,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
