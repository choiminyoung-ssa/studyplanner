import 'package:google_generative_ai/google_generative_ai.dart';

/// Google Gemini AI 서비스
/// Gemini API를 사용하여 고품질 AI 응답을 생성합니다.
class GeminiAIService {
  static const String _primaryModel = 'gemini-1.5-flash-latest';
  static const String _fallbackModel = 'gemini-1.0-pro';
  static const RequestOptions _primaryRequestOptions = RequestOptions(
    apiVersion: 'v1',
  );
  static const RequestOptions _fallbackRequestOptions = RequestOptions(
    apiVersion: 'v1beta',
  );

  GenerativeModel? _model;
  ChatSession? _chat;
  final String apiKey;
  bool _usingFallback = false;

  GeminiAIService({required this.apiKey}) {
    _initializeModel();
  }

  void _initializeModel({bool useFallback = false}) {
    try {
      _usingFallback = useFallback;
      _model = GenerativeModel(
        model: useFallback ? _fallbackModel : _primaryModel,
        apiKey: apiKey,
        requestOptions: useFallback
            ? _fallbackRequestOptions
            : _primaryRequestOptions,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 1024,
        ),
        systemInstruction: Content.system('''
당신은 학습 플래너 앱의 AI 어시스턴트입니다.

**주요 역할:**
- 사용자의 일정 관리를 돕습니다
- 학습 통계를 분석하고 조언합니다
- 할일 관리를 지원합니다
- 친근하고 도움이 되는 톤으로 대화합니다

**사용 가능한 기능:**
1. 일정 추가/조회
2. 주간/월간 계획 추가
3. 학습 목표 설정
4. 과목 추가
5. 학습 통계 확인
6. 할일 관리
7. 검색
8. 공부 팁 추천

**응답 스타일:**
- 짧고 명확하게 답변하세요
- 이모지를 적절히 사용하세요 (📅, 📊, ✅, 🔍, 💡 등)
- 친근하고 격려하는 톤을 유지하세요
- 사용자가 명령을 내리면 "네, ~하겠습니다!" 식으로 확인 응답 후 실행하세요
'''),
      );

      _chat = _model!.startChat(
        history: [
          Content.text('안녕하세요! 👋'),
          Content.model([
            TextPart(
              '안녕하세요! 저는 학습 플래너 AI 어시스턴트입니다.\n\n'
              '다음과 같은 기능을 도와드릴 수 있어요:\n'
              '• 일정 추가/조회\n'
              '• 주간/월간 계획 추가\n'
              '• 학습 목표 설정\n'
              '• 과목 추가\n'
              '• 학습 통계 확인\n'
              '• 할일 관리\n'
              '• 검색\n'
              '• 공부 팁 추천\n\n'
              '무엇을 도와드릴까요?',
            ),
          ]),
        ],
      );
    } catch (e) {
      print('❌ Gemini 모델 초기화 실패: $e');
    }
  }

  /// 사용자 메시지 처리 및 응답 생성
  Future<String> processMessage(
    String message, {
    bool allowRetry = true,
  }) async {
    if (_chat == null || _model == null) {
      return '❌ Gemini AI가 초기화되지 않았습니다. API 키를 확인해주세요.';
    }

    try {
      final response = await _chat!.sendMessage(Content.text(message));
      final text = response.text;

      if (text == null || text.isEmpty) {
        return '죄송합니다. 응답을 생성할 수 없습니다. 다시 시도해주세요.';
      }

      return text;
    } catch (e) {
      print('❌ Gemini API 오류: $e');
      if (allowRetry && _shouldFallback(e.toString())) {
        _initializeModel(useFallback: true);
        return await processMessage(message, allowRetry: false);
      }
      if (e.toString().contains('API_KEY_INVALID')) {
        return '❌ 유효하지 않은 API 키입니다. 설정에서 API 키를 확인해주세요.';
      } else if (e.toString().contains('QUOTA_EXCEEDED')) {
        return '❌ API 사용량이 초과되었습니다. 로컬 AI를 사용해주세요.';
      } else {
        return '❌ 오류가 발생했습니다: ${e.toString()}';
      }
    }
  }

  /// 사용자 의도 파싱 (명령어 추출)
  Future<Map<String, dynamic>> parseUserIntent(
    String message, {
    bool allowRetry = true,
  }) async {
    if (_chat == null || _model == null) {
      return {'action': 'chat', 'parameters': {}, 'confidence': 0.0};
    }

    try {
      final prompt =
          '''
사용자 메시지를 분석하여 의도를 파악하세요.

메시지: "$message"

다음 형식의 JSON으로만 응답하세요 (설명 없이):
{
  "action": "create_schedule | view_schedule | view_stats | manage_todo | search | add_to_backlog | add_subject | set_goal | set_weekly_plan | set_monthly_plan | chat",
  "parameters": {
    // action에 따라 필요한 파라미터
    // create_schedule: {"subject": "과목명", "time": "시간 정보"}
    // view_schedule: {"date": "오늘|내일|이번 주"}
    // view_stats: {"period": "오늘|이번 주|이번 달"}
    // manage_todo: {"action": "list"}
    // search: {"keyword": "검색어"}
    // add_to_backlog: {"subject": "할일", "description": "설명"}
    // add_subject: {"name": "과목명", "color": "#2196F3", "icon": "book"}
    // set_goal: {"period": "daily|weekly|monthly", "target": "120", "subject_targets": {"수학": 60}}
    // set_weekly_plan: {"title": "주간 목표", "week": "이번 주", "subject": "수학", "notes": "요약"}
    // set_monthly_plan: {"title": "월간 목표", "month": "이번 달", "subject": "영어", "notes": "요약"}
  },
  "confidence": 0.0~1.0 (신뢰도)
}

**action 선택 기준:**
- create_schedule: 일정/스케줄/계획을 추가/생성/만들기 + (과목명 또는 날짜 포함)
- view_schedule: 일정/스케줄을 보여주기/조회/확인 + (날짜 포함)
- view_stats: 통계/시간/공부량 확인
- manage_todo: 할일/과제/숙제 관련
- search: 찾기/검색 + (키워드)
- add_to_backlog: 할일 보관함에 추가
- add_subject: 과목 추가/등록
- set_goal: 학습 목표 설정 (일간/주간/월간)
- set_weekly_plan: 주간 계획 추가/설정
- set_monthly_plan: 월간 계획 추가/설정
- chat: 위에 해당하지 않는 일반 대화

신뢰도는 사용자 의도가 명확할수록 높게 (0.9~1.0), 애매하면 낮게 (0.5~0.7) 설정하세요.
''';

      final response = await _model!.generateContent([Content.text(prompt)]);
      final text = response.text;

      if (text == null || text.isEmpty) {
        return {'action': 'chat', 'parameters': {}, 'confidence': 0.5};
      }

      // JSON 파싱
      final cleanedText = text
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final json = _parseJson(cleanedText);
      print('🎯 Gemini Intent: $json');

      return json;
    } catch (e) {
      print('❌ Intent 파싱 오류: $e');
      if (allowRetry && _shouldFallback(e.toString())) {
        _initializeModel(useFallback: true);
        return await parseUserIntent(message, allowRetry: false);
      }
      return {'action': 'chat', 'parameters': {}, 'confidence': 0.0};
    }
  }

  Map<String, dynamic> _parseJson(String text) {
    try {
      // 간단한 JSON 파싱 (dart:convert 사용하지 않고)
      final actionMatch = RegExp(r'"action":\s*"([^"]+)"').firstMatch(text);
      final confidenceMatch = RegExp(
        r'"confidence":\s*([0-9.]+)',
      ).firstMatch(text);

      final action = actionMatch?.group(1) ?? 'chat';
      final confidence =
          double.tryParse(confidenceMatch?.group(1) ?? '0.5') ?? 0.5;

      final parameters = <String, dynamic>{};

      // subject 추출
      final subjectMatch = RegExp(r'"subject":\s*"([^"]+)"').firstMatch(text);
      if (subjectMatch != null) {
        parameters['subject'] = subjectMatch.group(1);
      }

      // time 추출
      final timeMatch = RegExp(r'"time":\s*"([^"]+)"').firstMatch(text);
      if (timeMatch != null) {
        parameters['time'] = timeMatch.group(1);
      }

      // date 추출
      final dateMatch = RegExp(r'"date":\s*"([^"]+)"').firstMatch(text);
      if (dateMatch != null) {
        parameters['date'] = dateMatch.group(1);
      }

      // period 추출
      final periodMatch = RegExp(r'"period":\s*"([^"]+)"').firstMatch(text);
      if (periodMatch != null) {
        parameters['period'] = periodMatch.group(1);
      }

      // keyword 추출
      final keywordMatch = RegExp(r'"keyword":\s*"([^"]+)"').firstMatch(text);
      if (keywordMatch != null) {
        parameters['keyword'] = keywordMatch.group(1);
      }

      // description 추출
      final descriptionMatch = RegExp(
        r'"description":\s*"([^"]+)"',
      ).firstMatch(text);
      if (descriptionMatch != null) {
        parameters['description'] = descriptionMatch.group(1);
      }

      // name 추출 (과목명)
      final nameMatch = RegExp(r'"name":\s*"([^"]+)"').firstMatch(text);
      if (nameMatch != null) {
        parameters['name'] = nameMatch.group(1);
      }

      // color 추출
      final colorMatch = RegExp(r'"color":\s*"([^"]+)"').firstMatch(text);
      if (colorMatch != null) {
        parameters['color'] = colorMatch.group(1);
      }

      // icon 추출
      final iconMatch = RegExp(r'"icon":\s*"([^"]+)"').firstMatch(text);
      if (iconMatch != null) {
        parameters['icon'] = iconMatch.group(1);
      }

      // title 추출 (주간/월간 계획)
      final titleMatch = RegExp(r'"title":\s*"([^"]+)"').firstMatch(text);
      if (titleMatch != null) {
        parameters['title'] = titleMatch.group(1);
      }

      // notes 추출
      final notesMatch = RegExp(r'"notes":\s*"([^"]+)"').firstMatch(text);
      if (notesMatch != null) {
        parameters['notes'] = notesMatch.group(1);
      }

      // week 추출
      final weekMatch = RegExp(r'"week":\s*"([^"]+)"').firstMatch(text);
      if (weekMatch != null) {
        parameters['week'] = weekMatch.group(1);
      }

      // month 추출
      final monthMatch = RegExp(r'"month":\s*"([^"]+)"').firstMatch(text);
      if (monthMatch != null) {
        parameters['month'] = monthMatch.group(1);
      }

      // target 추출 (목표 시간)
      final targetMatch =
          RegExp(r'"target":\s*"([^"]+)"').firstMatch(text) ??
          RegExp(r'"target":\s*([0-9.]+)').firstMatch(text);
      if (targetMatch != null) {
        parameters['target'] = targetMatch.group(1);
      }

      // goal 추출 (대체 제목)
      final goalMatch = RegExp(r'"goal":\s*"([^"]+)"').firstMatch(text);
      if (goalMatch != null) {
        parameters['goal'] = goalMatch.group(1);
      }

      // plan 추출 (대체 제목)
      final planMatch = RegExp(r'"plan":\s*"([^"]+)"').firstMatch(text);
      if (planMatch != null) {
        parameters['plan'] = planMatch.group(1);
      }

      // action 추출 (manage_todo용)
      final actionParamMatch = RegExp(
        r'"action":\s*"([^"]+)"',
        multiLine: true,
      ).allMatches(text).toList();
      if (actionParamMatch.length > 1) {
        parameters['action'] = actionParamMatch[1].group(1);
      }

      return {
        'action': action,
        'parameters': parameters,
        'confidence': confidence,
      };
    } catch (e) {
      print('❌ JSON 파싱 실패: $e');
      return {'action': 'chat', 'parameters': {}, 'confidence': 0.0};
    }
  }

  /// 채팅 기록 초기화
  void resetChat() {
    _initializeModel(useFallback: _usingFallback);
  }

  bool _shouldFallback(String error) {
    if (_usingFallback) {
      return false;
    }
    final lower = error.toLowerCase();
    return lower.contains('not found') ||
        lower.contains('not supported') ||
        lower.contains('models/');
  }
}
