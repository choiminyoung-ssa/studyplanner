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
    // 일반 도서/학습
    'book': Icons.book,
    'menu_book': Icons.menu_book,
    'auto_stories': Icons.auto_stories,
    'local_library': Icons.local_library,
    'import_contacts': Icons.import_contacts,

    // 수학 (5개 이상)
    'calculate': Icons.calculate,
    'functions': Icons.functions,
    'percent': Icons.percent,
    'square_foot': Icons.square_foot,
    'architecture': Icons.architecture,
    'pie_chart': Icons.pie_chart,
    'show_chart': Icons.show_chart,

    // 과학 (6개 이상)
    'science': Icons.science,
    'biotech': Icons.biotech,
    'science_outlined': Icons.science_outlined,
    'bug_report': Icons.bug_report,
    'coronavirus': Icons.coronavirus,
    'eco': Icons.eco,
    'local_florist': Icons.local_florist,
    'water_drop': Icons.water_drop,
    'opacity': Icons.opacity,
    'bubble_chart': Icons.bubble_chart,

    // 국어 (2개 이상)
    'article': Icons.article,
    'edit_note': Icons.edit_note,
    'border_color': Icons.border_color,

    // 영어 (2개 이상)
    'translate': Icons.translate,
    'g_translate': Icons.g_translate,
    'language': Icons.language,
    'spellcheck': Icons.spellcheck,

    // 사회/역사
    'public': Icons.public,
    'history_edu': Icons.history_edu,
    'account_balance': Icons.account_balance,
    'gavel': Icons.gavel,
    'museum': Icons.museum,
    'location_city': Icons.location_city,
    'map': Icons.map,
    'terrain': Icons.terrain,

    // 컴퓨터/IT
    'computer': Icons.computer,
    'code': Icons.code,
    'terminal': Icons.terminal,
    'devices': Icons.devices,
    'memory': Icons.memory,
    'developer_board': Icons.developer_board,
    'phone_android': Icons.phone_android,

    // 음악
    'music_note': Icons.music_note,
    'piano': Icons.piano,
    'audiotrack': Icons.audiotrack,
    'headphones': Icons.headphones,
    'mic': Icons.mic,

    // 미술
    'palette': Icons.palette,
    'brush': Icons.brush,
    'color_lens': Icons.color_lens,
    'draw': Icons.draw,
    'photo_camera': Icons.photo_camera,
    'image': Icons.image,

    // 체육/운동
    'sports_soccer': Icons.sports_soccer,
    'fitness_center': Icons.fitness_center,
    'sports_basketball': Icons.sports_basketball,
    'pool': Icons.pool,
    'sports_tennis': Icons.sports_tennis,
    'sports_baseball': Icons.sports_baseball,
    'directions_run': Icons.directions_run,
    'self_improvement': Icons.self_improvement,

    // 심리/철학
    'psychology': Icons.psychology,
    'light_mode': Icons.light_mode,
    'favorite': Icons.favorite,
    'emoji_objects': Icons.emoji_objects,

    // 법/정치
    'balance': Icons.balance,
    'policy': Icons.policy,
    'how_to_vote': Icons.how_to_vote,

    // 경제/경영
    'attach_money': Icons.attach_money,
    'trending_up': Icons.trending_up,
    'business': Icons.business,
    'store': Icons.store,

    // 기타
    'school': Icons.school,
    'workspace_premium': Icons.workspace_premium,
    'star': Icons.star,
    'workspace': Icons.workspace,
    'widgets': Icons.widgets,
    'extension': Icons.extension,
  };

  static IconData getIcon(String iconName) {
    return iconMap[iconName] ?? Icons.book;
  }

  static List<MapEntry<String, IconData>> getAllIcons() {
    return iconMap.entries.toList();
  }
}
