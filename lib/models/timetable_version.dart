import 'package:cloud_firestore/cloud_firestore.dart';

/// 시간표 버전
/// 여러 개의 시간표를 만들고 관리할 수 있습니다.
class TimetableVersion {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive; // 현재 활성화된 시간표인지
  final String? color; // 시간표 테마 색상

  TimetableVersion({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.createdAt,
    this.updatedAt,
    this.isActive = false,
    this.color,
  });

  /// Firestore 문서로부터 생성
  factory TimetableVersion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TimetableVersion(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '새 시간표',
      description: data['description'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? false,
      color: data['color'],
    );
  }

  /// Firestore에 저장할 형태로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isActive': isActive,
      'color': color,
    };
  }

  /// 복사본 생성
  TimetableVersion copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? color,
  }) {
    return TimetableVersion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      color: color ?? this.color,
    );
  }

  /// 기본 시간표인지 확인
  bool get isDefault {
    return name == '기본 시간표' || id == 'default';
  }
}

/// 시간표 버전 테마 색상
class TimetableColors {
  static const String blue = '#2563EB';
  static const String green = '#22C55E';
  static const String purple = '#9333EA';
  static const String orange = '#F59E0B';
  static const String pink = '#EC4899';
  static const String red = '#EF4444';
  static const String teal = '#14B8A6';
  static const String indigo = '#6366F1';

  static const List<String> allColors = [
    blue,
    green,
    purple,
    orange,
    pink,
    red,
    teal,
    indigo,
  ];

  static const Map<String, String> colorNames = {
    blue: '파란색',
    green: '초록색',
    purple: '보라색',
    orange: '주황색',
    pink: '핑크색',
    red: '빨간색',
    teal: '청록색',
    indigo: '남색',
  };
}
