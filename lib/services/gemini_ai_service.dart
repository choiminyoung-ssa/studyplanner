import 'package:google_generative_ai/google_generative_ai.dart';

/// Google Gemini AI 서비스
/// Gemini API를 사용하여 고품질 AI 응답을 생성합니다.
class GeminiAIService {
  GenerativeModel? _model;
  ChatSession? _chat;
  final String apiKey;

  GeminiAIService({required this.apiKey}) {
    _initializeModel();
  }

  void _initializeModel() {
    try {
      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
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
2. 학습 통계 확인
3. 할일 관리
4. 검색
5. 공부 팁 추천

**응답 스타일:**
- 짧고 명확하게 답변하세요
- 이모지를 적절히 사용하세요 (📅, 📊, ✅, 🔍, 💡 등)
- 친근하고 격려하는 톤을 유지하세요
- 사용자가 명령을 내리면 "네, ~하겠습니다!" 식으로 확인 응답 후 실행하세요
'''),
      );

      _chat = _model!.startChat(history: [
        Content.text('안녕하세요! 👋'),
        Content.model([
          TextPart(
              '안녕하세요! 저는 학습 플래너 AI 어시스턴트입니다.\n\n'
              '다음과 같은 기능을 도와드릴 수 있어요:\n'
              '• 일정 추가/조회\n'
              '• 학습 통계 확인\n'
              '• 할일 관리\n'
              '• 검색\n'
              '• 공부 팁 추천\n\n'
              '무엇을 도와드릴까요?')
        ]),
      ]);
    } catch (e) {
      print('❌ Gemini 모델 초기화 실패: $e');
    }
  }

  /// 사용자 메시지 처리 및 응답 생성
  Future<String> processMessage(String message) async {
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
  Future<Map<String, dynamic>> parseUserIntent(String message) async {
    if (_chat == null || _model == null) {
      return {
        'action': 'chat',
        'parameters': {},
        'confidence': 0.0,
      };
    }

    try {
      final prompt = '''
사용자 메시지를 분석하여 의도를 파악하세요.

메시지: "$message"

다음 형식의 JSON으로만 응답하세요 (설명 없이):
{
  "action": "create_schedule | view_schedule | view_stats | manage_todo | search | chat",
  "parameters": {
    // action에 따라 필요한 파라미터
    // create_schedule: {"subject": "과목명", "time": "시간 정보"}
    // view_schedule: {"date": "오늘|내일|이번 주"}
    // view_stats: {"period": "오늘|이번 주|이번 달"}
    // manage_todo: {"action": "list"}
    // search: {"keyword": "검색어"}
  },
  "confidence": 0.0~1.0 (신뢰도)
}

**action 선택 기준:**
- create_schedule: 일정/스케줄/계획을 추가/생성/만들기 + (과목명 또는 날짜 포함)
- view_schedule: 일정/스케줄을 보여주기/조회/확인 + (날짜 포함)
- view_stats: 통계/시간/공부량 확인
- manage_todo: 할일/과제/숙제 관련
- search: 찾기/검색 + (키워드)
- chat: 위에 해당하지 않는 일반 대화

신뢰도는 사용자 의도가 명확할수록 높게 (0.9~1.0), 애매하면 낮게 (0.5~0.7) 설정하세요.
''';

      final response = await _model!.generateContent([Content.text(prompt)]);
      final text = response.text;

      if (text == null || text.isEmpty) {
        return {
          'action': 'chat',
          'parameters': {},
          'confidence': 0.5,
        };
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
      return {
        'action': 'chat',
        'parameters': {},
        'confidence': 0.0,
      };
    }
  }

  Map<String, dynamic> _parseJson(String text) {
    try {
      // 간단한 JSON 파싱 (dart:convert 사용하지 않고)
      final actionMatch = RegExp(r'"action":\s*"([^"]+)"').firstMatch(text);
      final confidenceMatch =
          RegExp(r'"confidence":\s*([0-9.]+)').firstMatch(text);

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

      // action 추출 (manage_todo용)
      final actionParamMatch =
          RegExp(r'"action":\s*"([^"]+)"', multiLine: true)
              .allMatches(text)
              .toList();
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
      return {
        'action': 'chat',
        'parameters': {},
        'confidence': 0.0,
      };
    }
  }

  /// 채팅 기록 초기화
  void resetChat() {
    _initializeModel();
  }
}
