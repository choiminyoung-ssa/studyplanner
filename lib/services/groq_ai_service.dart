import 'dart:convert';
import 'package:http/http.dart' as http;

/// Groq AI 서비스
/// Groq API를 사용하여 빠른 AI 응답을 생성합니다.
class GroqAIService {
  static const String _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _defaultModel = 'llama-3.1-8b-instant';
  static const String _systemPrompt = '''
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
5. 학습 자료 추가
6. 화면 설정
7. 할일 보관함 추가
8. 학습 통계 확인
9. 할일 관리
10. 검색
11. 공부 팁 추천

**응답 스타일:**
- 짧고 명확하게 답변하세요
- 이모지를 적절히 사용하세요 (📅, 📊, ✅, 🔍, 💡 등)
- 친근하고 격려하는 톤을 유지하세요
- 사용자가 명령을 내리면 "네, ~하겠습니다!" 식으로 확인 응답 후 실행하세요
''';

  final String apiKey;
  final String model;
  final List<Map<String, String>> _messages = [];

  GroqAIService({required this.apiKey, this.model = _defaultModel}) {
    _messages.add({'role': 'system', 'content': _systemPrompt});
  }

  /// 사용자 메시지 처리 및 응답 생성
  Future<String> processMessage(String message) async {
    if (apiKey.trim().isEmpty) {
      return '❌ Groq API 키가 설정되지 않았습니다. 설정에서 키를 입력해주세요.';
    }

    _messages.add({'role': 'user', 'content': message});

    final response = await _sendChat(_messages);
    if (response == null || response.isEmpty) {
      _messages.removeLast();
      return '❌ Groq 응답을 생성할 수 없습니다. 잠시 후 다시 시도해주세요.';
    }

    _messages.add({'role': 'assistant', 'content': response});
    return response;
  }

  /// 사용자 의도 파싱 (명령어 추출)
  Future<Map<String, dynamic>> parseUserIntent(String message) async {
    if (apiKey.trim().isEmpty) {
      return {'action': 'chat', 'parameters': {}, 'confidence': 0.0};
    }

    try {
      final prompt =
          '''
사용자 메시지를 분석하여 의도를 파악하세요.

메시지: "$message"

다음 형식의 JSON으로만 응답하세요 (설명 없이):
{
  "action": "create_schedule | view_schedule | view_stats | manage_todo | search | add_to_backlog | add_subject | add_study_resource | set_goal | set_weekly_plan | set_monthly_plan | set_theme | chat",
  "parameters": {
    // action에 따라 필요한 파라미터
    // create_schedule: {"subject": "과목명", "time": "시간 정보", "duration": "시간(분)", "materials": ["자료1", "자료2"]}
    // view_schedule: {"date": "오늘|내일|이번 주"}
    // view_stats: {"period": "오늘|이번 주|이번 달"}
    // manage_todo: {"action": "list"}
    // search: {"keyword": "검색어"}
    // add_to_backlog: {"subject": "할일 내용", "description": "상세 설명"}
    // add_subject: {"name": "과목명", "color": "#2196F3", "icon": "book"}
    // add_study_resource: {"title": "자료명", "type": "lecture|book", "notes": "설명", "total_units": "24"}
    // set_goal: {"period": "daily|weekly|monthly", "target": "120", "subject_targets": {"수학": 60}}
    // set_weekly_plan: {"title": "주간 목표", "week": "이번 주", "subject": "수학", "notes": "요약"}
    // set_monthly_plan: {"title": "월간 목표", "month": "이번 달", "subject": "영어", "notes": "요약"}
    // set_theme: {"theme": "light|dark|system"}
  },
  "confidence": 0.0~1.0 (신뢰도)
}

**action 선택 기준:**
- create_schedule: 일정/스케줄/계획을 추가/생성/만들기 + (과목명 또는 날짜 포함)
- view_schedule: 일정/스케줄을 보여주기/조회/확인 + (날짜 포함)
- view_stats: 통계/시간/공부량 확인
- manage_todo: 할일/과제/숙제 관련
- search: 찾기/검색 + (키워드)
- add_to_backlog: 할일보관함에 추가 + (내용 포함)
- add_subject: 과목 추가/등록
- add_study_resource: 학습 자료 추가/등록
- set_goal: 학습 목표 설정 (일간/주간/월간)
- set_weekly_plan: 주간 계획 추가/설정
- set_monthly_plan: 월간 계획 추가/설정
- set_theme: 화면 테마 설정 (라이트/다크/시스템)
- chat: 위에 해당하지 않는 일반 대화

**추가 파라미터 추출:**
- duration: "3시간", "2시간 30분", "90분" 등 시간 길이 추출
- materials: "문법책", "수학 문제집", "영어 듣기" 등 학습 자료 추출

신뢰도는 사용자 의도가 명확할수록 높게 (0.9~1.0), 애매하면 낮게 (0.5~0.7) 설정하세요.
''';

      final response = await _sendChat(
        [
          {'role': 'system', 'content': 'JSON만 반환하세요.'},
          {'role': 'user', 'content': prompt},
        ],
        temperature: 0.2,
        maxTokens: 512,
      );

      if (response == null || response.isEmpty) {
        return {'action': 'chat', 'parameters': {}, 'confidence': 0.5};
      }

      final cleanedText = response
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final json = _parseJson(cleanedText);
      print('🎯 Groq Intent: $json');
      return json;
    } catch (e) {
      print('❌ Groq Intent 파싱 오류: $e');
      return {'action': 'chat', 'parameters': {}, 'confidence': 0.0};
    }
  }

  Future<String?> _sendChat(
    List<Map<String, String>> messages, {
    double temperature = 0.7,
    double topP = 0.95,
    int maxTokens = 1024,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': messages,
          'temperature': temperature,
          'top_p': topP,
          'max_tokens': maxTokens,
        }),
      );

      if (response.statusCode != 200) {
        print('❌ Groq API 오류 (${response.statusCode}): ${response.body}');
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>? ?? [];
      if (choices.isEmpty) {
        return null;
      }

      final message = choices.first as Map<String, dynamic>;
      final content = (message['message'] as Map<String, dynamic>?)?['content'];
      return content?.toString().trim();
    } catch (e) {
      print('❌ Groq 요청 실패: $e');
      return null;
    }
  }

  Map<String, dynamic> _parseJson(String text) {
    try {
      final actionMatch = RegExp(r'"action":\s*"([^"]+)"').firstMatch(text);
      final confidenceMatch = RegExp(
        r'"confidence":\s*([0-9.]+)',
      ).firstMatch(text);

      final action = actionMatch?.group(1) ?? 'chat';
      final confidence =
          double.tryParse(confidenceMatch?.group(1) ?? '0.5') ?? 0.5;

      final parameters = <String, dynamic>{};

      final subjectMatch = RegExp(r'"subject":\s*"([^"]+)"').firstMatch(text);
      if (subjectMatch != null) {
        parameters['subject'] = subjectMatch.group(1);
      }

      final timeMatch = RegExp(r'"time":\s*"([^"]+)"').firstMatch(text);
      if (timeMatch != null) {
        parameters['time'] = timeMatch.group(1);
      }

      final durationMatch = RegExp(r'"duration":\s*"([^"]+)"').firstMatch(text);
      if (durationMatch != null) {
        parameters['duration'] = durationMatch.group(1);
      }

      final materialsMatch = RegExp(
        r'"materials":\s*\[([^\]]+)\]',
      ).firstMatch(text);
      if (materialsMatch != null) {
        final materialsText = materialsMatch.group(1) ?? '';
        final materials = materialsText
            .split(',')
            .map((m) => m.trim().replaceAll('"', ''))
            .where((m) => m.isNotEmpty)
            .toList();
        if (materials.isNotEmpty) {
          parameters['materials'] = materials;
        }
      }

      final dateMatch = RegExp(r'"date":\s*"([^"]+)"').firstMatch(text);
      if (dateMatch != null) {
        parameters['date'] = dateMatch.group(1);
      }

      final periodMatch = RegExp(r'"period":\s*"([^"]+)"').firstMatch(text);
      if (periodMatch != null) {
        parameters['period'] = periodMatch.group(1);
      }

      final keywordMatch = RegExp(r'"keyword":\s*"([^"]+)"').firstMatch(text);
      if (keywordMatch != null) {
        parameters['keyword'] = keywordMatch.group(1);
      }

      final descriptionMatch = RegExp(
        r'"description":\s*"([^"]+)"',
      ).firstMatch(text);
      if (descriptionMatch != null) {
        parameters['description'] = descriptionMatch.group(1);
      }

      final nameMatch = RegExp(r'"name":\s*"([^"]+)"').firstMatch(text);
      if (nameMatch != null) {
        parameters['name'] = nameMatch.group(1);
      }

      final colorMatch = RegExp(r'"color":\s*"([^"]+)"').firstMatch(text);
      if (colorMatch != null) {
        parameters['color'] = colorMatch.group(1);
      }

      final iconMatch = RegExp(r'"icon":\s*"([^"]+)"').firstMatch(text);
      if (iconMatch != null) {
        parameters['icon'] = iconMatch.group(1);
      }

      final titleMatch = RegExp(r'"title":\s*"([^"]+)"').firstMatch(text);
      if (titleMatch != null) {
        parameters['title'] = titleMatch.group(1);
      }

      final notesMatch = RegExp(r'"notes":\s*"([^"]+)"').firstMatch(text);
      if (notesMatch != null) {
        parameters['notes'] = notesMatch.group(1);
      }

      final typeMatch = RegExp(r'"type":\s*"([^"]+)"').firstMatch(text);
      if (typeMatch != null) {
        parameters['type'] = typeMatch.group(1);
      }

      final totalUnitsMatch =
          RegExp(r'"total_units":\s*"([^"]+)"').firstMatch(text) ??
          RegExp(r'"total_units":\s*([0-9.]+)').firstMatch(text);
      if (totalUnitsMatch != null) {
        parameters['total_units'] = totalUnitsMatch.group(1);
      }

      final weekMatch = RegExp(r'"week":\s*"([^"]+)"').firstMatch(text);
      if (weekMatch != null) {
        parameters['week'] = weekMatch.group(1);
      }

      final monthMatch = RegExp(r'"month":\s*"([^"]+)"').firstMatch(text);
      if (monthMatch != null) {
        parameters['month'] = monthMatch.group(1);
      }

      final targetMatch =
          RegExp(r'"target":\s*"([^"]+)"').firstMatch(text) ??
          RegExp(r'"target":\s*([0-9.]+)').firstMatch(text);
      if (targetMatch != null) {
        parameters['target'] = targetMatch.group(1);
      }

      final goalMatch = RegExp(r'"goal":\s*"([^"]+)"').firstMatch(text);
      if (goalMatch != null) {
        parameters['goal'] = goalMatch.group(1);
      }

      final planMatch = RegExp(r'"plan":\s*"([^"]+)"').firstMatch(text);
      if (planMatch != null) {
        parameters['plan'] = planMatch.group(1);
      }

      final themeMatch = RegExp(r'"theme":\s*"([^"]+)"').firstMatch(text);
      if (themeMatch != null) {
        parameters['theme'] = themeMatch.group(1);
      }

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
      print('❌ Groq JSON 파싱 실패: $e');
      return {'action': 'chat', 'parameters': {}, 'confidence': 0.0};
    }
  }

  /// 채팅 기록 초기화
  void resetChat() {
    _messages
      ..clear()
      ..add({'role': 'system', 'content': _systemPrompt});
  }
}
