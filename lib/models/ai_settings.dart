/// AI 설정 모델
/// 사용자가 선택한 AI 모드(Gemini/Local)와 API 키를 저장합니다.
class AISettings {
  final AIMode mode;
  final String? geminiApiKey;
  final String? groqApiKey;

  const AISettings({required this.mode, this.geminiApiKey, this.groqApiKey});

  /// 기본 설정 (Gemini AI)
  factory AISettings.defaultSettings() {
    return AISettings(
      mode: AIMode.gemini,
      geminiApiKey:
          'AIzaSyD7Q24Q040000000000000000000000000', // 내장된 Gemini API 키
      groqApiKey:
          'gsk_0000000000000000000000000000000000000000000000000000', // 내장된 Groq API 키
    );
  }

  /// JSON으로부터 생성
  factory AISettings.fromJson(Map<String, dynamic> json) {
    return AISettings(
      mode: AIMode.values.firstWhere(
        (e) => e.name == json['mode'],
        orElse: () => AIMode.local,
      ),
      geminiApiKey: json['geminiApiKey'] as String?,
      groqApiKey: json['groqApiKey'] as String?,
    );
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'mode': mode.name,
      'geminiApiKey': geminiApiKey,
      'groqApiKey': groqApiKey,
    };
  }

  /// 복사본 생성
  AISettings copyWith({
    AIMode? mode,
    String? geminiApiKey,
    String? groqApiKey,
  }) {
    return AISettings(
      mode: mode ?? this.mode,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      groqApiKey: groqApiKey ?? this.groqApiKey,
    );
  }

  /// Gemini 모드 사용 가능 여부 확인
  bool get canUseGemini {
    return mode == AIMode.gemini &&
        geminiApiKey != null &&
        geminiApiKey!.isNotEmpty;
  }

  /// Groq 모드 사용 가능 여부 확인
  bool get canUseGroq {
    return mode == AIMode.groq && groqApiKey != null && groqApiKey!.isNotEmpty;
  }
}

/// AI 모드 열거형
enum AIMode {
  gemini, // Google Gemini API (클라우드, API 키 필요, 고품질)
  groq, // Groq API (클라우드, API 키 필요, 초고속)
  local, // 로컬 패턴 매칭 (무료, API 키 불필요, 오프라인)
}

/// AI 모드 확장 메서드
extension AIModeExtension on AIMode {
  /// 표시 이름
  String get displayName {
    switch (this) {
      case AIMode.gemini:
        return 'Google Gemini AI';
      case AIMode.groq:
        return 'Groq AI';
      case AIMode.local:
        return '로컬 AI (무료)';
    }
  }

  /// 설명
  String get description {
    switch (this) {
      case AIMode.gemini:
        return '고품질 AI 응답 (API 키 필요)';
      case AIMode.groq:
        return '초고속 AI 응답 (API 키 필요)';
      case AIMode.local:
        return '기본 패턴 매칭 (API 키 불필요, 완전 무료)';
    }
  }

  /// 아이콘
  String get icon {
    switch (this) {
      case AIMode.gemini:
        return '🤖';
      case AIMode.groq:
        return '⚡';
      case AIMode.local:
        return '💫';
    }
  }
}
