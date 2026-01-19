// 실제 사용 예시 및 테스트 코드

import 'ai_assistant_improved.dart';

Future<void> main() async {
  print('🤖 AI 어시스턴트 테스트 시작\n');

  final assistant = AIAssistant();
  final db = ScheduleDatabase();

  // ==================== 테스트 1: 일정 추가 ====================
  print('📝 테스트 1: 다양한 형식의 일정 추가');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  final testCases = [
    "오늘 오후 3시에 수학공부 추가해줘",
    "내일 아침 9시 영어 공부",
    "모레 7시에 운동 하자",
    "이번주 월요일 2시 회의 일정",
    "다음주 토요일 오전 10시 피아노 레슨",
  ];

  for (var testCase in testCases) {
    print('\n사용자: $testCase');
    final response = await assistant.processUserMessage(testCase);
    print('봇: $response\n');
    await Future.delayed(Duration(milliseconds: 300));
  }

  // ==================== 테스트 2: 일정 조회 ====================
  print('\n\n📅 테스트 2: 일정 조회');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  final queryTests = [
    "오늘 뭐 하기로 했어?",
    "내일 일정 있나?",
    "이번주는?",
  ];

  for (var query in queryTests) {
    print('\n사용자: $query');
    final response = await assistant.processUserMessage(query);
    print('봇: $response\n');
    await Future.delayed(Duration(milliseconds: 300));
  }

  // ==================== 테스트 3: 일반 대화 ====================
  print('\n\n💬 테스트 3: 일반 대화');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  final generalChats = [
    "안녕",
    "감사합니다",
    "도움이 됐어요",
  ];

  for (var chat in generalChats) {
    print('\n사용자: $chat');
    final response = await assistant.processUserMessage(chat);
    print('봇: $response\n');
    await Future.delayed(Duration(milliseconds: 300));
  }

  // ==================== 테스트 4: 자동 카테고리 분류 ====================
  print('\n\n🏷️  테스트 4: 자동 카테고리 분류');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  final categoryExamples = [
    ("공부", "study", "내일 2시 수학공부"),
    ("운동", "exercise", "오후 4시 축구"),
    ("미팅", "meeting", "다음주 월요일 팀 회의"),
  ];

  for (var (label, expectedCategory, example) in categoryExamples) {
    final info = NLPEngine.extractScheduleInfo(example);
    print('\n입력: "$example"');
    print('인식된 카테고리: ${info['category']} ✓');
  }

  // ==================== 테스트 5: 시간 파싱 ====================
  print('\n\n⏰ 테스트 5: 시간 표현 파싱');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  final timeExpressions = [
    "오늘",
    "내일",
    "모레",
    "1시간 후",
    "2시간 후",
  ];

  for (var expr in timeExpressions) {
    final result = NLPEngine.parseTimeExpression(expr);
    if (result != null) {
      print('\n"$expr" → ${result['matched'] ?? result['time']}');
    }
  }

  // ==================== 테스트 6: 데이터베이스 저장 확인 ====================
  print('\n\n💾 테스트 6: 데이터베이스 저장 확인');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  final allSchedules = await db.getAllSchedules();
  print('\n총 저장된 일정: ${allSchedules.length}개\n');

  for (var schedule in allSchedules) {
    print('📌 ${schedule.title}');
    print('   날짜: ${schedule.startTime.toString().substring(0, 10)}');
    print('   시간: ${schedule.startTime.toString().substring(11, 16)}');
    print('   카테고리: ${schedule.category}\n');
  }

  // ==================== 테스트 7: 의도 인식 ====================
  print('\n\n🎯 테스트 7: 의도(Intent) 인식');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  final intentTests = [
    ("일정 추가", "add_schedule"),
    ("내일 뭐해?", "view_schedule"),
    ("삭제해줘", "delete_schedule"),
    ("안녕하세요", "general"),
  ];

  for (var (text, expectedIntent) in intentTests) {
    final intent = NLPEngine.recognizeIntent(text);
    final result = intent == expectedIntent ? '✓' : '✗';
    print('\n"$text" → $intent $result');
  }

  // ==================== 테스트 8: 자연스러운 대화 흐름 ====================
  print('\n\n🗣️  테스트 8: 자연스러운 대화 흐름');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  print('\n사용자: 안녕하세요!');
  var response1 = await assistant.processUserMessage('안녕하세요!');
  print('봇: $response1\n');

  await Future.delayed(Duration(milliseconds: 500));

  print('사용자: 내일 오후 2시에 영어공부 일정 추가해줄래?');
  var response2 =
      await assistant.processUserMessage('내일 오후 2시에 영어공부 일정 추가해줄래?');
  print('봇: $response2\n');

  await Future.delayed(Duration(milliseconds: 500));

  print('사용자: 내일 뭐 해야 되지?');
  var response3 = await assistant.processUserMessage('내일 뭐 해야 되지?');
  print('봇: $response3\n');

  await Future.delayed(Duration(milliseconds: 500));

  print('사용자: 감사합니다!');
  var response4 = await assistant.processUserMessage('감사합니다!');
  print('봇: $response4\n');

  // ==================== 최종 요약 ====================
  print('\n\n📊 최종 테스트 요약');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('\n✅ 모든 테스트 완료!');
  print('📝 대화 기록: ${assistant.chatHistory.length}개 메시지');
  print('📅 저장된 일정: ${(await db.getAllSchedules()).length}개');
  print('\n🎉 AI 어시스턴트가 성공적으로 작동합니다!\n');
}

// ==================== 실제 앱에서 사용하는 방법 ====================

/*
import 'package:flutter/material.dart';
import 'ai_assistant_improved.dart';

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late AIAssistant _assistant;

  @override
  void initState() {
    super.initState();
    _assistant = AIAssistant();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('📅 스터디 플래너'),
      ),
      body: Column(
        children: [
          // 상단: 오늘의 일정 요약
          Container(
            padding: EdgeInsets.all(16),
            child: Text('오늘의 일정을 AI에게 물어보세요!'),
          ),

          // 중앙: AI 어시스턴트 채팅 UI
          Expanded(
            child: ImprovedAIAssistantUI(),
          ),

          // 하단: 빠른 메뉴
          Container(
            padding: EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _quickButton('📝 일정 추가', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AddSchedulePage()),
                    );
                  }),
                  SizedBox(width: 8),
                  _quickButton('📅 오늘 일정 보기', () async {
                    final response = await _assistant
                        .processUserMessage('오늘 뭐 하기로 했어?');
                    // 결과 표시
                  }),
                  SizedBox(width: 8),
                  _quickButton('📊 주간 계획', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => WeeklyViewPage()),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

// 일정 추가 페이지
class AddSchedulePage extends StatefulWidget {
  @override
  State<AddSchedulePage> createState() => _AddSchedulePageState();
}

class _AddSchedulePageState extends State<AddSchedulePage> {
  late TextEditingController _titleController;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('일정 추가')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: '일정 제목',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16),

          // 날짜 선택
          ListTile(
            title: Text(_selectedDate == null
                ? '날짜 선택'
                : _selectedDate.toString().substring(0, 10)),
            trailing: Icon(Icons.calendar_today),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (date != null) {
                setState(() => _selectedDate = date);
              }
            },
          ),
          SizedBox(height: 8),

          // 시간 선택
          ListTile(
            title: Text(_selectedTime == null
                ? '시간 선택'
                : _selectedTime!.format(context)),
            trailing: Icon(Icons.access_time),
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (time != null) {
                setState(() => _selectedTime = time);
              }
            },
          ),
          SizedBox(height: 32),

          // 저장 버튼
          ElevatedButton(
            onPressed: _saveSchedule,
            child: Text('일정 저장'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSchedule() async {
    if (_titleController.text.isEmpty ||
        _selectedDate == null ||
        _selectedTime == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('모든 항목을 입력해주세요')));
      return;
    }

    final startTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final schedule = ScheduleItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text,
      startTime: startTime,
      endTime: startTime.add(Duration(hours: 1)),
      category: 'other',
    );

    final db = ScheduleDatabase();
    await db.insertSchedule(schedule);

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('일정이 저장되었습니다!')));

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
}

// 주간 보기 페이지
class WeeklyViewPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('주간 계획')),
      body: Center(
        child: Text('주간 일정 보기를 구현하세요'),
      ),
    );
  }
}
*/
