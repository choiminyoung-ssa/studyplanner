/// 로컬 AI 서비스 (API 키 불필요, 완전 무료)
///
/// 패턴 매칭과 규칙 기반으로 사용자 명령을 처리합니다.
/// 클라우드 AI보다 간단하지만 API 키가 필요 없고 무료입니다.
class LocalAIService {
  // 이전 대화 컨텍스트 저장
  String _previousContext = '';
  String _previousSubject = '';

  /// 사용자 메시지를 분석하고 적절한 응답 생성
  Future<String> processMessage(String message) async {
    // 실제 AI처럼 약간의 지연 추가
    await Future.delayed(const Duration(milliseconds: 300));

    final lowerMessage = message.toLowerCase();

    // 인사말
    if (_containsAny(lowerMessage, ['안녕', '하이', 'hi', 'hello', '헬로'])) {
      return '안녕하세요! 👋\n무엇을 도와드릴까요?';
    }

    // 과목 추가
    if (_containsAny(lowerMessage, ['과목', 'subject']) &&
        _containsAny(lowerMessage, ['추가', '등록', '생성', '만들'])) {
      final subjectName = _extractSubjectName(message);
      return '✅ "$subjectName" 과목을 추가할게요!';
    }

    // 목표 설정
    if (_containsAny(lowerMessage, ['목표', 'goal']) &&
        _containsAny(lowerMessage, ['설정', '세워', '추가', '등록'])) {
      return '🎯 목표를 설정할게요! 원하는 기간과 시간을 알려주세요.';
    }

    // 주간/월간 계획
    if (_containsAny(lowerMessage, ['주간', '이번 주']) &&
        _containsAny(lowerMessage, ['계획', '목표', '플랜']) &&
        _containsAny(lowerMessage, ['추가', '설정', '등록', '짜', '세워'])) {
      return '🗓️ 주간 계획을 추가할게요!';
    }
    if (_containsAny(lowerMessage, ['월간', '이번 달']) &&
        _containsAny(lowerMessage, ['계획', '목표', '플랜']) &&
        _containsAny(lowerMessage, ['추가', '설정', '등록', '짜', '세워'])) {
      return '🗓️ 월간 계획을 추가할게요!';
    }

    // 학습 자료 추가
    if (_containsAny(lowerMessage, [
          '학습',
          '공부',
          '자료',
          'material',
          'resource',
        ]) &&
        _containsAny(lowerMessage, ['추가', '등록', '생성', '만들'])) {
      final resourceTitle = _extractResourceTitle(message);
      return '📎 "$resourceTitle" 학습 자료를 추가할게요!';
    }

    // 화면 설정 (테마)
    if (_containsAny(lowerMessage, ['화면', '테마', 'theme', '모드']) &&
        _containsAny(lowerMessage, [
          '밝',
          '어둡',
          '시스템',
          '다크',
          '라이트',
          'light',
          'dark',
          'system',
        ])) {
      final theme = _extractTheme(message);
      final themeLabel = theme == 'light'
          ? '밝은 테마'
          : theme == 'dark'
          ? '어두운 테마'
          : '시스템 테마';
      return '🎨 화면 테마를 "$themeLabel"로 설정할게요!';
    }

    // 할일 보관함 추가
    if (_containsAny(lowerMessage, ['보관함', 'backlog']) &&
        _containsAny(lowerMessage, ['추가', '등록', '넣', '저장'])) {
      final backlogTitle = _extractBacklogTitle(message);
      return '🗂️ "$backlogTitle"을(를) 할일 보관함에 추가할게요!';
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
    // 날짜 추출 로직 (더 정교함)
    final lowerMsg = message.toLowerCase();

    // 구체적인 날짜 패턴
    if (lowerMsg.contains('다음주 월요일') || lowerMsg.contains('다음주 월'))
      return '다음주 월요일';
    if (lowerMsg.contains('다음주 화요일') || lowerMsg.contains('다음주 화'))
      return '다음주 화요일';
    if (lowerMsg.contains('다음주 수요일') || lowerMsg.contains('다음주 수'))
      return '다음주 수요일';
    if (lowerMsg.contains('다음주 목요일') || lowerMsg.contains('다음주 목'))
      return '다음주 목요일';
    if (lowerMsg.contains('다음주 금요일') || lowerMsg.contains('다음주 금'))
      return '다음주 금요일';
    if (lowerMsg.contains('다음주 토요일') || lowerMsg.contains('다음주 토'))
      return '다음주 토요일';
    if (lowerMsg.contains('다음주 일요일') || lowerMsg.contains('다음주 일'))
      return '다음주 일요일';

    // 일반 날짜
    if (lowerMsg.contains('모레')) return '모레';
    if (lowerMsg.contains('내일')) return '내일';
    if (lowerMsg.contains('이번주') || lowerMsg.contains('이번 주')) return '이번 주';
    if (lowerMsg.contains('다음주') || lowerMsg.contains('다음 주')) return '다음 주';

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
    _previousSubject = subject; // 컨텍스트 저장

    return '✅ "$subject" 일정 추가 준비 완료!\n\n'
        '📅 날짜: $time\n'
        '📚 과목: $subject\n\n'
        '곧 Firestore에 저장됩니다! 🚀';
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
      if (word.length > 1 && !['찾아', '검색', '해줘', '알려', '보여'].contains(word)) {
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
        '🗓️ **주간/월간 계획**\n'
        '• "이번 주 계획 세워줘: 수학 5단원"\n'
        '• "이번 달 목표 추가: 영어 2권 완독"\n\n'
        '🎯 **학습 목표 설정**\n'
        '• "이번 주 목표 10시간으로 설정"\n'
        '• "오늘 목표 2시간"\n\n'
        '📚 **과목 관리**\n'
        '• "과목 추가: 화학"\n'
        '• "새 과목 등록: 한국사"\n\n'
        '📎 **학습 자료 추가**\n'
        '• "학습 자료 추가: 수학 문제집 1권"\n'
        '• "강의 자료 등록: 화학 인강 20강"\n\n'
        '🎨 **화면 설정**\n'
        '• "화면 테마를 다크로 바꿔줘"\n'
        '• "라이트 모드로 설정"\n\n'
        '🗂️ **할일 보관함**\n'
        '• "할일 보관함에 추가: 영어 단어 암기"\n'
        '• "보관함에 과제 저장해줘"\n\n'
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

  /// 사용자 의도 파싱 (명령어 추출) - 개선된 버전
  Future<Map<String, dynamic>> parseUserIntent(String message) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final lowerMessage = message.toLowerCase();
    print('🔍 DEBUG: parseUserIntent() - message: "$message"');

    Map<String, dynamic> result = {
      'action': 'chat',
      'parameters': {},
      'confidence': 0.5,
    };

    // 과목 추가
    if (_containsAny(lowerMessage, ['과목', 'subject']) &&
        _containsAny(lowerMessage, ['추가', '등록', '생성', '만들'])) {
      result['action'] = 'add_subject';
      result['parameters'] = {
        'name': _extractSubjectName(message),
        if (_extractHexColor(message) != null)
          'color': _extractHexColor(message),
      };
      result['confidence'] = 0.9;
      print('✅ DEBUG: Detected add_subject with confidence 0.9');
    }
    // 목표 설정
    else if (_containsAny(lowerMessage, ['목표', 'goal']) &&
        _containsAny(lowerMessage, ['설정', '세워', '추가', '등록'])) {
      result['action'] = 'set_goal';
      result['parameters'] = {
        'period': _extractGoalPeriod(message),
        'target': _extractTargetMinutes(message),
      };
      result['confidence'] = 0.88;
      print('✅ DEBUG: Detected set_goal with confidence 0.88');
    }
    // 주간 계획 설정
    else if (_containsAny(lowerMessage, ['주간', '이번 주']) &&
        _containsAny(lowerMessage, ['계획', '목표', '플랜']) &&
        _containsAny(lowerMessage, ['추가', '설정', '등록', '짜', '세워'])) {
      result['action'] = 'set_weekly_plan';
      result['parameters'] = {
        'title': _extractPlanTitle(message, '이번 주 계획'),
        'week': message,
        'subject': _extractSubject(message),
      };
      result['confidence'] = 0.86;
      print('✅ DEBUG: Detected set_weekly_plan with confidence 0.86');
    }
    // 월간 계획 설정
    else if (_containsAny(lowerMessage, ['월간', '이번 달']) &&
        _containsAny(lowerMessage, ['계획', '목표', '플랜']) &&
        _containsAny(lowerMessage, ['추가', '설정', '등록', '짜', '세워'])) {
      result['action'] = 'set_monthly_plan';
      result['parameters'] = {
        'title': _extractPlanTitle(message, '이번 달 계획'),
        'month': message,
        'subject': _extractSubject(message),
      };
      result['confidence'] = 0.86;
      print('✅ DEBUG: Detected set_monthly_plan with confidence 0.86');
    }
    // 할일 보관함 추가
    else if (_containsAny(lowerMessage, ['보관함', 'backlog']) &&
        _containsAny(lowerMessage, ['추가', '등록', '넣', '저장'])) {
      result['action'] = 'add_to_backlog';
      result['parameters'] = {
        'subject': _extractBacklogTitle(message),
        'description': _extractBacklogDescription(message),
      };
      result['confidence'] = 0.86;
      print('✅ DEBUG: Detected add_to_backlog with confidence 0.86');
    }
    // 일정 생성 (시간과 학습 자료 파라미터 포함)
    else if ((_containsAny(lowerMessage, ['일정', '스케줄', '계획']) &&
            _containsAny(lowerMessage, [
              '추가',
              '생성',
              '만들',
              '등록',
              '넣',
              '해야',
              '해야해',
              '공부',
            ])) ||
        (_containsAny(lowerMessage, ['내일', '모레', '다음주', '오후', '아침']) &&
            _containsAny(lowerMessage, [
              '수학',
              '영어',
              '과학',
              '국어',
              '공부',
              '숙제',
              '과제',
            ]))) {
      result['action'] = 'create_schedule';
      result['parameters'] = {
        'subject': _extractSubject(message),
        'time': message,
        'duration': _extractDuration(message),
        'materials': _extractMaterials(message),
      };
      result['confidence'] = 0.92;
      print('✅ DEBUG: Detected create_schedule with confidence 0.92');
    }
    // 일정 조회
    else if ((_containsAny(lowerMessage, ['일정', '스케줄']) &&
            _containsAny(lowerMessage, ['보여', '알려', '확인', '조회', '뭐', '뭐야'])) ||
        (_containsAny(lowerMessage, ['오늘', '내일', '이번주']) &&
            _containsAny(lowerMessage, ['뭐', '뭐야', '뭐하', '일정']))) {
      result['action'] = 'view_schedule';
      result['parameters'] = {'date': message};
      result['confidence'] = 0.91;
      print('✅ DEBUG: Detected view_schedule with confidence 0.91');
    }
    // 통계 조회
    else if (_containsAny(lowerMessage, ['통계', '시간', '얼마', '공부']) &&
        _containsAny(lowerMessage, ['얼마', '시간', '통계', '몇'])) {
      result['action'] = 'view_stats';
      result['parameters'] = {'period': message};
      result['confidence'] = 0.88;
      print('✅ DEBUG: Detected view_stats with confidence 0.88');
    }
    // 할일 관리
    else if (_containsAny(lowerMessage, ['할일', '할 일', '과제', '숙제', 'todo'])) {
      result['action'] = 'manage_todo';
      result['parameters'] = {'action': 'list'};
      result['confidence'] = 0.87;
      print('✅ DEBUG: Detected manage_todo with confidence 0.87');
    }
    // 검색
    else if (_containsAny(lowerMessage, ['찾', '검색', 'find', 'search'])) {
      final words = message.split(' ');
      String keyword = '';
      for (var word in words) {
        if (word.length > 1 &&
            !['찾아', '검색', '해줘', '알려', '보여', '찾다'].contains(word)) {
          keyword = word;
          break;
        }
      }
      result['action'] = 'search';
      result['parameters'] = {'keyword': keyword};
      result['confidence'] = 0.83;
      print('✅ DEBUG: Detected search with confidence 0.83');
    }
    // 학습 자료 추가
    else if (_containsAny(lowerMessage, [
          '학습',
          '공부',
          '자료',
          'material',
          'resource',
        ]) &&
        _containsAny(lowerMessage, ['추가', '등록', '생성', '만들'])) {
      result['action'] = 'add_study_resource';
      result['parameters'] = {
        'title': _extractResourceTitle(message),
        'type': _extractResourceType(message),
        'notes': _extractResourceNotes(message),
        'total_units': _extractTotalUnits(message),
      };
      result['confidence'] = 0.85;
      print('✅ DEBUG: Detected add_study_resource with confidence 0.85');
    }
    // 화면 설정 (테마)
    else if (_containsAny(lowerMessage, ['화면', '테마', 'theme', '설정', '모드']) &&
        _containsAny(lowerMessage, [
          '밝',
          '어둡',
          '시스템',
          '다크',
          '라이트',
          'light',
          'dark',
          'system',
        ])) {
      result['action'] = 'set_theme';
      result['parameters'] = {'theme': _extractTheme(message)};
      result['confidence'] = 0.87;
      print('✅ DEBUG: Detected set_theme with confidence 0.87');
    }

    print(
      '📊 DEBUG: Final result - action: ${result['action']}, confidence: ${result['confidence']}',
    );
    return result;
  }

  String _extractSubjectName(String message) {
    final quoted = _extractQuotedText(message);
    if (quoted.isNotEmpty) {
      return quoted;
    }

    final match = RegExp(
      r'(과목|subject)\s*(추가|등록|생성|만들기|만들어)?\s*([가-힣A-Za-z0-9 ]+)',
    ).firstMatch(message);
    if (match != null) {
      final value = match.group(3)?.trim();
      if (value != null && value.isNotEmpty) {
        return value.split(' ').first;
      }
    }

    return _extractSubject(message);
  }

  String _extractGoalPeriod(String message) {
    if (message.contains('일간') || message.contains('오늘')) {
      return 'daily';
    }
    if (message.contains('월간') || message.contains('이번 달')) {
      return 'monthly';
    }
    return 'weekly';
  }

  int _extractTargetMinutes(String message) {
    final hourMatch = RegExp(r'(\d+)\s*시간').firstMatch(message);
    final minuteMatch = RegExp(r'(\d+)\s*분').firstMatch(message);

    int minutes = 0;
    if (hourMatch != null) {
      minutes += int.parse(hourMatch.group(1)!) * 60;
    }
    if (minuteMatch != null) {
      minutes += int.parse(minuteMatch.group(1)!);
    }

    if (minutes > 0) {
      return minutes;
    }

    final numericMatch = RegExp(r'(\d+)').firstMatch(message);
    return numericMatch != null ? int.parse(numericMatch.group(1)!) : 60;
  }

  String _extractPlanTitle(String message, String fallback) {
    final quoted = _extractQuotedText(message);
    if (quoted.isNotEmpty) {
      return quoted;
    }

    final cleaned = message
        .replaceAll(
          RegExp(r'(주간|월간|이번 주|이번 달|계획|목표|플랜|추가|설정|등록|세워|짜줘|짜|작성|만들어|만들기|해줘)'),
          '',
        )
        .replaceAll(RegExp(r'[:：]'), '')
        .trim();

    if (cleaned.isEmpty) {
      return fallback;
    }

    return cleaned.length > 24 ? cleaned.substring(0, 24).trim() : cleaned;
  }

  String? _extractHexColor(String message) {
    final match = RegExp(r'#?[0-9a-fA-F]{6}').firstMatch(message);
    if (match == null) {
      return null;
    }
    final value = match.group(0) ?? '';
    return value.startsWith('#') ? value : '#$value';
  }

  String _extractQuotedText(String message) {
    final match =
        RegExp(r'"([^"]+)"').firstMatch(message) ??
        RegExp(r"'([^']+)'").firstMatch(message);
    return match?.group(1)?.trim() ?? '';
  }

  /// 시간 길이 추출 (로컬 AI 전용)
  String _extractDuration(String message) {
    final lowerMsg = message.toLowerCase();

    // "3시간" 형태
    final hourMatch = RegExp(r'(\d+)\s*시간').firstMatch(lowerMsg);
    if (hourMatch != null) {
      return '${hourMatch.group(1)}시간';
    }

    // "2시간 30분" 형태
    final hourMinuteMatch = RegExp(
      r'(\d+)\s*시간\s*(\d+)\s*분',
    ).firstMatch(lowerMsg);
    if (hourMinuteMatch != null) {
      return '${hourMinuteMatch.group(1)}시간 ${hourMinuteMatch.group(2)}분';
    }

    // "90분" 형태
    final minuteMatch = RegExp(r'(\d+)\s*분').firstMatch(lowerMsg);
    if (minuteMatch != null) {
      return '${minuteMatch.group(1)}분';
    }

    // 기본값
    return '1시간';
  }

  /// 학습 자료 추출 (로컬 AI 전용)
  List<String> _extractMaterials(String message) {
    final lowerMsg = message.toLowerCase();
    final materials = <String>[];

    // 일반적인 학습 자료 패턴
    final materialPatterns = {
      '문법책': ['문법책', '문법서', 'grammar book'],
      '단어장': ['단어장', '단어책', 'vocabulary book'],
      '문제집': ['문제집', '연습문제', 'practice book'],
      '교과서': ['교과서', 'textbook', '교재'],
      '노트': ['노트', 'notebook', '공책'],
      '참고서': ['참고서', 'reference book', '참고자료'],
      '온라인 강의': ['온라인 강의', '강의', 'lecture', 'video'],
      '유튜브': ['유튜브', 'youtube', '동영상'],
      '앱': ['앱', 'application', 'app'],
      '플래시카드': ['플래시카드', 'flashcard', '플래시'],
    };

    for (final entry in materialPatterns.entries) {
      if (materials.length >= 3) break; // 최대 3개까지만

      for (final pattern in entry.value) {
        if (lowerMsg.contains(pattern) && !materials.contains(entry.key)) {
          materials.add(entry.key);
          break;
        }
      }
    }

    return materials;
  }

  /// 학습 자료 제목 추출
  String _extractResourceTitle(String message) {
    final quoted = _extractQuotedText(message);
    if (quoted.isNotEmpty) {
      return quoted;
    }

    final cleaned = message
        .replaceAll(
          RegExp(r'(학습|공부|자료|material|resource|추가|등록|생성|만들어|만들기|해줘)'),
          '',
        )
        .replaceAll(RegExp(r'[:：]'), '')
        .trim();

    if (cleaned.isEmpty) {
      return '새 학습 자료';
    }

    return cleaned.length > 50 ? cleaned.substring(0, 50).trim() : cleaned;
  }

  /// 학습 자료 타입 추출
  String _extractResourceType(String message) {
    final lowerMsg = message.toLowerCase();

    if (lowerMsg.contains('강의') ||
        lowerMsg.contains('lecture') ||
        lowerMsg.contains('온라인')) {
      return 'lecture';
    }

    return 'book'; // 기본값
  }

  /// 학습 자료 노트 추출
  String _extractResourceNotes(String message) {
    final lowerMsg = message.toLowerCase();

    if (lowerMsg.contains('노트') || lowerMsg.contains('메모')) {
      final noteMatch = RegExp(
        r'(노트|메모|notes?)\s*[:：]?\s*(.+)',
        caseSensitive: false,
      ).firstMatch(message);
      if (noteMatch != null) {
        return noteMatch.group(2)?.trim() ?? '';
      }
    }

    return '';
  }

  /// 총 단위 수 추출
  String? _extractTotalUnits(String message) {
    final lowerMsg = message.toLowerCase();

    // "총 10강" 형태
    final totalMatch = RegExp(r'총\s*(\d+)\s*(강|페이지|page)').firstMatch(lowerMsg);
    if (totalMatch != null) {
      return totalMatch.group(1);
    }

    // "10강" 형태
    final unitMatch = RegExp(r'(\d+)\s*(강|페이지|page)').firstMatch(lowerMsg);
    if (unitMatch != null) {
      return unitMatch.group(1);
    }

    return null;
  }

  String _extractBacklogTitle(String message) {
    final quoted = _extractQuotedText(message);
    if (quoted.isNotEmpty) {
      return quoted;
    }

    final cleaned = message
        .replaceAll(
          RegExp(
            r'(할일|할 일|보관함|백로그|backlog|추가|등록|넣어|넣기|저장|해줘|만들어|만들기)',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'[:：]'), '')
        .trim();

    if (cleaned.isEmpty) {
      return '새 할일';
    }

    return cleaned.length > 50 ? cleaned.substring(0, 50).trim() : cleaned;
  }

  String _extractBacklogDescription(String message) {
    final match = RegExp(
      r'(설명|메모|노트|detail|description)\s*[:：]?\s*(.+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (match != null) {
      return match.group(2)?.trim() ?? '';
    }
    return '';
  }

  /// 테마 추출
  String _extractTheme(String message) {
    final lowerMsg = message.toLowerCase();

    if (lowerMsg.contains('밝') ||
        lowerMsg.contains('light') ||
        lowerMsg.contains('라이트')) {
      return 'light';
    } else if (lowerMsg.contains('어둡') ||
        lowerMsg.contains('dark') ||
        lowerMsg.contains('다크')) {
      return 'dark';
    } else if (lowerMsg.contains('시스템') ||
        lowerMsg.contains('system') ||
        lowerMsg.contains('자동')) {
      return 'system';
    }

    return 'system'; // 기본값
  }
}
