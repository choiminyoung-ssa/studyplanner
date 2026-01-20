/// 중요도/긴급도 매트릭스 (아이젠하워 매트릭스)
///
/// 4사분면:
/// - Q1 (긴급하고 중요): 즉시 처리
/// - Q2 (중요하지만 긴급하지 않음): 계획 수립
/// - Q3 (긴급하지만 중요하지 않음): 위임 고려
/// - Q4 (긴급하지도 중요하지도 않음): 제거 고려

enum Importance {
  high,    // 중요함
  low,     // 중요하지 않음
}

enum Urgency {
  high,    // 긴급함
  low,     // 긴급하지 않음
}

/// 4사분면
enum Quadrant {
  q1,  // 긴급하고 중요 (빨강)
  q2,  // 중요하지만 긴급하지 않음 (초록)
  q3,  // 긴급하지만 중요하지 않음 (주황)
  q4,  // 긴급하지도 중요하지도 않음 (회색)
}

extension ImportanceExtension on Importance {
  String get displayName {
    switch (this) {
      case Importance.high:
        return '중요함';
      case Importance.low:
        return '중요하지 않음';
    }
  }

  String get icon {
    switch (this) {
      case Importance.high:
        return '⭐';
      case Importance.low:
        return '○';
    }
  }
}

extension UrgencyExtension on Urgency {
  String get displayName {
    switch (this) {
      case Urgency.high:
        return '긴급함';
      case Urgency.low:
        return '긴급하지 않음';
    }
  }

  String get icon {
    switch (this) {
      case Urgency.high:
        return '🔥';
      case Urgency.low:
        return '⏱️';
    }
  }
}

extension QuadrantExtension on Quadrant {
  String get displayName {
    switch (this) {
      case Quadrant.q1:
        return 'Q1: 긴급하고 중요';
      case Quadrant.q2:
        return 'Q2: 중요하지만 여유있음';
      case Quadrant.q3:
        return 'Q3: 긴급하지만 덜 중요';
      case Quadrant.q4:
        return 'Q4: 여유있고 덜 중요';
    }
  }

  String get shortName {
    switch (this) {
      case Quadrant.q1:
        return '즉시 처리';
      case Quadrant.q2:
        return '계획 수립';
      case Quadrant.q3:
        return '위임 고려';
      case Quadrant.q4:
        return '제거 고려';
    }
  }

  String get description {
    switch (this) {
      case Quadrant.q1:
        return '위기, 긴급한 문제, 마감일이 임박한 프로젝트';
      case Quadrant.q2:
        return '장기 개발, 전략적 계획, 관계 구축, 새로운 기회';
      case Quadrant.q3:
        return '일부 전화/이메일, 일부 회의, 긴급한 일';
      case Quadrant.q4:
        return '시간 낭비, 즐거운 활동, 바쁜 일';
    }
  }

  int get colorValue {
    switch (this) {
      case Quadrant.q1:
        return 0xFFEF4444; // 빨강 (긴급하고 중요)
      case Quadrant.q2:
        return 0xFF22C55E; // 초록 (중요하지만 여유)
      case Quadrant.q3:
        return 0xFFF59E0B; // 주황 (긴급하지만 덜 중요)
      case Quadrant.q4:
        return 0xFF9CA3AF; // 회색 (여유있고 덜 중요)
    }
  }

  String get emoji {
    switch (this) {
      case Quadrant.q1:
        return '🔴';
      case Quadrant.q2:
        return '🟢';
      case Quadrant.q3:
        return '🟡';
      case Quadrant.q4:
        return '⚪';
    }
  }

  /// 중요도와 긴급도로부터 사분면 계산
  static Quadrant fromPriority(Importance importance, Urgency urgency) {
    if (importance == Importance.high && urgency == Urgency.high) {
      return Quadrant.q1;
    } else if (importance == Importance.high && urgency == Urgency.low) {
      return Quadrant.q2;
    } else if (importance == Importance.low && urgency == Urgency.high) {
      return Quadrant.q3;
    } else {
      return Quadrant.q4;
    }
  }
}

/// 우선순위 매트릭스 데이터
class PriorityMatrix {
  final Importance importance;
  final Urgency urgency;

  const PriorityMatrix({
    required this.importance,
    required this.urgency,
  });

  /// 기본값 (중요하고 긴급함)
  factory PriorityMatrix.defaultPriority() {
    return const PriorityMatrix(
      importance: Importance.high,
      urgency: Urgency.high,
    );
  }

  /// JSON으로부터 생성
  factory PriorityMatrix.fromJson(Map<String, dynamic> json) {
    return PriorityMatrix(
      importance: Importance.values.firstWhere(
        (e) => e.name == json['importance'],
        orElse: () => Importance.high,
      ),
      urgency: Urgency.values.firstWhere(
        (e) => e.name == json['urgency'],
        orElse: () => Urgency.high,
      ),
    );
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'importance': importance.name,
      'urgency': urgency.name,
    };
  }

  /// 사분면 계산
  Quadrant get quadrant {
    return QuadrantExtension.fromPriority(importance, urgency);
  }

  /// 복사본 생성
  PriorityMatrix copyWith({
    Importance? importance,
    Urgency? urgency,
  }) {
    return PriorityMatrix(
      importance: importance ?? this.importance,
      urgency: urgency ?? this.urgency,
    );
  }
}
