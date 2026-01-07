import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Subject {
  final String id;
  final String userId;
  final String name;
  final String color; // Hex color code (예: '#FF5722')
  final String icon; // Icon name (예: 'book', 'science', 'calculate')
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Subject({
    required this.id,
    required this.userId,
    required this.name,
    required this.color,
    required this.icon,
    this.displayOrder = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Subject.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Subject(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      color: data['color'] ?? '#2196F3',
      icon: data['icon'] ?? 'book',
      displayOrder: data['displayOrder'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'color': color,
      'icon': icon,
      'displayOrder': displayOrder,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Subject copyWith({
    String? id,
    String? userId,
    String? name,
    String? color,
    String? icon,
    int? displayOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Subject(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SubjectIconHelper {
  static const Map<String, IconData> iconMap = {
    'book': Icons.book,
    'calculate': Icons.calculate,
    'science': Icons.science,
    'language': Icons.translate,
    'computer': Icons.computer,
    'psychology': Icons.psychology,
    'balance': Icons.balance,
    'biotech': Icons.biotech,
    'public': Icons.public,
    'history_edu': Icons.history_edu,
    'music_note': Icons.music_note,
    'palette': Icons.palette,
    'sports_soccer': Icons.sports_soccer,
    'fitness_center': Icons.fitness_center,
  };

  static IconData getIcon(String iconName) {
    return iconMap[iconName] ?? Icons.book;
  }

  static List<MapEntry<String, IconData>> getAllIcons() {
    return iconMap.entries.toList();
  }
}
