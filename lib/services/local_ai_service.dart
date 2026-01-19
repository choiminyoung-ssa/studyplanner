/// 로컬 AI 서비스 (API 키 불필요, 완전 무료)
///
/// 패턴 매칭과 규칙 기반으로 사용자 명령을 처리합니다.
/// 클라우드 AI보다 간단하지만 API 키가 필요 없고 무료입니다.
class LocalAIService {
  /// 사용자 메시지를 분석하고 적절한 응답 생성
  Future<String> processMessage(String message) async {
    // 실제 AI처럼 약간의 지연 추가
    await Future.delayed(const Duration(milliseconds: 500));

    final lowerMessage = message.toLowerCase();

    // 인사말
    if (_containsAny(lowerMessage, ['안녕', '하이', 'hi', 'hello', '헬로'])) {
      return '안녕하세요! 👋\n무엇을 도와드릴까요?';
    }

    // 일정 관련
    if (_containsAny(lowerMessage, ['일정', '스케줄', '계획'])) {
      if (_containsAny(lowerMessage, ['추가', '생성', '만들', '등록', '넣'])) {
        return _createScheduleResponse(message);
      } else if (_containsAny(lowerMessage, ['보여', '알려', '확인', '조회', '뭐'])) {
        return _viewScheduleResponse(message);
      }
      return '일정을 추가하시려면 "일정 추가"라고 말씀해주세요.\n'
          '일정을 확인하시려면 "일정 보여줘"라고 말씀해주세요.';
    }

    // 학습 통계
    if (_containsAny(lowerMessage, ['통계', '시간', '공부', '학습', '얼마'])) {
      if (_containsAny(lowerMessage, ['얼마', '시간', '통계'])) {
        return _statsResponse(message);
      }
    }

    // 할일 관리
    if (_containsAny(lowerMessage, ['할일', '할 일', '과제', '숙제', 'todo'])) {
      return _todoResponse(message);
    }

    // 검색
    if (_containsAny(lowerMessage, ['찾', '검색', 'find', 'search'])) {
      return _searchResponse(message);
    }

    // 도움말
    if (_containsAny(lowerMessage, ['도움', '도와', '뭐', '기능', '할 수', 'help'])) {
      return _helpResponse();
    }

    // 공부 팁
    if (_containsAny(lowerMessage, ['팁', '방법', '추천', '어떻게'])) {
      return _studyTipsResponse();
    }

    // 감사 인사
    if (_containsAny(lowerMessage, ['고마', '감사', '땡큐', 'thanks', 'thank'])) {
      return '천만에요! 😊\n더 필요하신 게 있으면 언제든 말씀해주세요!';
    }

    // 기본 응답
    return _defaultResponse();
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  String _extractTime(String message) {
    // 시간 추출 로직
    if (message.contains('내일')) return '내일';
    if (message.contains('모레')) return '모레';
    if (message.contains('다음주')) return '다음 주';
    return '오늘';
  }

  String _extractSubject(String message) {
    final subjects = {
      '수학': ['수학', 'math'],
      '영어': ['영어', 'english', '영'],
      '국어': ['국어', '국'],
      '과학': ['과학', 'science'],
      '사회': ['사회', 'social'],
      '역사': ['역사', 'history'],
      '물리': ['물리', 'physics'],
      '화학': ['화학', 'chemistry'],
      '생물': ['생물', 'biology'],
    };

    for (var entry in subjects.entries) {
      if (_containsAny(message.toLowerCase(), entry.value)) {
        return entry.key;
      }
    }
    return '공부';
  }

  String _createScheduleResponse(String message) {
    final time = _extractTime(message);
    final subject = _extractSubject(message);

    return '📅 일정 추가 요청을 받았습니다!\n\n'
        '• 과목: $subject\n'
        '• 시간: $time\n\n'
        '이 정보로 일정을 추가하시겠어요?\n'
        '(명령어는 자동으로 처리됩니다)';
  }

  String _viewScheduleResponse(String message) {
    String period = '오늘';
    if (message.contains('내일')) {
      period = '내일';
    } else if (message.contains('이번 주') || message.contains('이번주')) {
      period = '이번 주';
    }

    return '📅 $period 일정을 조회합니다.\n\n'
        '일정 목록은 자동으로 표시됩니다!';
  }

  String _statsResponse(String message) {
    String period = '오늘';
    if (message.contains('이번 주') || message.contains('이번주')) {
      period = '이번 주';
    } else if (message.contains('이번 달') || message.contains('이번달')) {
      period = '이번 달';
    }

    return '📊 $period 학습 통계를 확인합니다.\n\n'
        '통계 정보는 자동으로 표시됩니다!';
  }

  String _todoResponse(String message) {
    return '📝 할일 목록을 확인합니다.\n\n'
        '완료되지 않은 과제와 일정을 보여드릴게요!';
  }

  String _searchResponse(String message) {
    // 검색 키워드 추출
    final words = message.split(' ');
    String keyword = '';
    for (var word in words) {
      if (word.length > 1 &&
          !['찾아', '검색', '해줘', '알려', '보여'].contains(word)) {
        keyword = word;
        break;
      }
    }

    if (keyword.isEmpty) {
      return '🔍 무엇을 검색하시겠어요?\n\n'
          '예: "수학 관련 일정 찾아줘"';
    }

    return '🔍 "$keyword" 관련 일정을 검색합니다.\n\n'
        '검색 결과는 자동으로 표시됩니다!';
  }

  String _helpResponse() {
    return '💡 **사용 가능한 기능**\n\n'
        '📅 **일정 관리**\n'
        '• "내일 오후 3시에 수학 공부 일정 추가해줘"\n'
        '• "오늘 일정 알려줘"\n'
        '• "이번 주 일정 보여줘"\n\n'
        '📊 **학습 통계**\n'
        '• "오늘 얼마나 공부했어?"\n'
        '• "이번 주 공부 시간 알려줘"\n\n'
        '✅ **할일 관리**\n'
        '• "할일 목록 보여줘"\n'
        '• "과제 알려줘"\n\n'
        '🔍 **검색**\n'
        '• "수학 관련 일정 찾아줘"\n'
        '• "영어 과제 검색해줘"\n\n'
        '💡 **공부 팁**\n'
        '• "공부 방법 추천해줘"\n'
        '• "시간 관리 팁 알려줘"\n\n'
        '편하게 말씀하시면 이해할 수 있어요! 😊';
  }

  String _studyTipsResponse() {
    final tips = [
      '🎯 **포모도로 기법**\n25분 집중 + 5분 휴식을 반복하세요!',
      '📚 **능동적 학습**\n읽기만 하지 말고 직접 써보고 설명해보세요!',
      '⏰ **황금 시간대 활용**\n아침 일찍 일어나서 공부하면 집중력이 높아요!',
      '🎵 **환경 설정**\n조용한 곳에서 핸드폰은 멀리! 집중도가 2배로 높아집니다.',
      '✍️ **메타인지 활용**\n내가 무엇을 모르는지 파악하는 게 중요해요!',
      '🔄 **복습 시스템**\n24시간 내, 1주일 후, 1개월 후 3번 복습하면 완벽!',
    ];

    // 랜덤으로 하나 선택
    final randomTip = (tips..shuffle()).first;

    return '$randomTip\n\n'
        '더 많은 팁을 원하시면 다시 물어보세요! 😊';
  }

  String _defaultResponse() {
    return '음... 잘 이해하지 못했어요. 😅\n\n'
        '다음과 같이 말씀해주세요:\n\n'
        '• "일정 추가해줘"\n'
        '• "오늘 일정 알려줘"\n'
        '• "공부 시간 통계 보여줘"\n'
        '• "할일 목록 보여줘"\n'
        '• "도움말"\n\n'
        '더 자세한 도움이 필요하시면 "도움말"이라고 말씀해주세요!';
  }

  /// 사용자 의도 파싱 (명령어 추출)
  Future<Map<String, dynamic>> parseUserIntent(String message) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final lowerMessage = message.toLowerCase();
    Map<String, dynamic> result = {
      'action': 'chat',
      'parameters': {},
      'confidence': 0.5,
    };

    // 일정 생성
    if (_containsAny(lowerMessage, ['일정', '스케줄']) &&
        _containsAny(lowerMessage, ['추가', '생성', '만들', '등록'])) {
      result['action'] = 'create_schedule';
      result['parameters'] = {
        'subject': _extractSubject(message),
        'time': message,
      };
      result['confidence'] = 0.9;
    }
    // 일정 조회
    else if (_containsAny(lowerMessage, ['일정', '스케줄']) &&
        _containsAny(lowerMessage, ['보여', '알려', '확인', '조회'])) {
      result['action'] = 'view_schedule';
      result['parameters'] = {
        'date': message,
      };
      result['confidence'] = 0.9;
    }
    // 통계 조회
    else if (_containsAny(lowerMessage, ['통계', '시간', '얼마'])) {
      result['action'] = 'view_stats';
      result['parameters'] = {
        'period': message,
      };
      result['confidence'] = 0.85;
    }
    // 할일 관리
    else if (_containsAny(lowerMessage, ['할일', '과제', '숙제'])) {
      result['action'] = 'manage_todo';
      result['parameters'] = {
        'action': 'list',
      };
      result['confidence'] = 0.85;
    }
    // 검색
    else if (_containsAny(lowerMessage, ['찾', '검색'])) {
      final words = message.split(' ');
      String keyword = '';
      for (var word in words) {
        if (word.length > 1 &&
            !['찾아', '검색', '해줘', '알려', '보여'].contains(word)) {
          keyword = word;
          break;
        }
      }
      result['action'] = 'search';
      result['parameters'] = {
        'keyword': keyword,
      };
      result['confidence'] = 0.8;
    }

    return result;
  }
}
