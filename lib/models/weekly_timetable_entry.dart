import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklyTimetableEntry {
  final String id;
  final String userId;
  final int weekday; // 1=월, 7=일 (DateTime.weekday)
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final String title;
  final String? location;
  final DateTime createdAt;
  final DateTime updatedAt;

  WeeklyTimetableEntry({
    required this.id,
    required this.userId,
    required this.weekday,
    required this.startTime,
    required this.endTime,
    required this.title,
    this.location,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WeeklyTimetableEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WeeklyTimetableEntry(
      id: doc.id,
      userId: data['userId'] ?? '',
      weekday: data['weekday'] ?? 1,
      startTime: data['startTime'] ?? '09:00',
      endTime: data['endTime'] ?? '10:00',
      title: data['title'] ?? '',
      location: data['location'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'weekday': weekday,
      'startTime': startTime,
      'endTime': endTime,
      'title': title,
      'location': location,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  WeeklyTimetableEntry copyWith({
    String? id,
    String? userId,
    int? weekday,
    String? startTime,
    String? endTime,
    String? title,
    String? location,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WeeklyTimetableEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      weekday: weekday ?? this.weekday,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      title: title ?? this.title,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int get startMinutes => _timeToMinutes(startTime);
  int get endMinutes => _timeToMinutes(endTime);

  int get durationMinutes {
    final duration = endMinutes - startMinutes;
    return duration > 0 ? duration : 0;
  }

  static int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }
}
