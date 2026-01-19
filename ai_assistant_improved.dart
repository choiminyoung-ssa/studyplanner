import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// ==================== 데이터 모델 ====================
class ScheduleItem {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? description;
  final String category;
  final bool isAllDay;

  ScheduleItem({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.description,
    required this.category,
    this.isAllDay = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'description': description,
      'category': category,
      'isAllDay': isAllDay ? 1 : 0,
    };
  }

  static ScheduleItem fromMap(Map<String, dynamic> map) {
    return ScheduleItem(
      id: map['id'],
      title: map['title'],
      startTime: DateTime.parse(map['startTime']),
      endTime: DateTime.parse(map['endTime']),
      description: map['description'],
      category: map['category'],
      isAllDay: map['isAllDay'] == 1,
    );
  }
}

class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
  });
}

// ==================== 일정 데이터베이스 관리 ====================
class ScheduleDatabase {
  static final ScheduleDatabase _instance = ScheduleDatabase._internal();
  static Database? _database;

  ScheduleDatabase._internal();

  factory ScheduleDatabase() {
    return _instance;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'schedules.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          '''CREATE TABLE schedules(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            startTime TEXT NOT NULL,
            endTime TEXT NOT NULL,
            description TEXT,
            category TEXT NOT NULL,
            isAllDay INTEGER DEFAULT 0,
            createdAt TEXT
          )''',
        );
      },
    );
  }

  Future<void> insertSchedule(ScheduleItem schedule) async {
    final db = await database;
    await db.insert(
      'schedules',
      {
        ...schedule.toMap(),
        'createdAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ScheduleItem>> getAllSchedules() async {
    final db = await database;
    final maps = await db.query('schedules');
    return List.generate(maps.length, (i) => ScheduleItem.fromMap(maps[i]));
  }

  Future<List<ScheduleItem>> getSchedulesByDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(Duration(days: 1));

    final maps = await db.query(
      'schedules',
      where:
          'startTime >= ? AND startTime < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );
    return List.generate(maps.length, (i) => ScheduleItem.fromMap(maps[i]));
  }

  Future<void> deleteSchedule(String id) async {
    final db = await database;
    await db.delete('schedules', where: 'id = ?', whereArgs: [id]);
  }
}

// ==================== 자연어 처리 (NLP) 엔진 ====================
class NLPEngine {
  // 시간 표현 파싱
  static Map<String, dynamic>? parseTimeExpression(String text) {
    final now = DateTime.now();

    // 패턴 정의
    final patterns = {
      '오늘': () => DateTime(now.year, now.month, now.day),
      '내일': () => DateTime(now.year, now.month, now.day + 1),
      '모레': () => DateTime(now.year, now.month, now.day + 2),
      '이번주': () => now,
      '다음주': () => now.add(Duration(days: 7)),
      '1시간 후': () => now.add(Duration(hours: 1)),
      '2시간 후': () => now.add(Duration(hours: 2)),
    };

    for (var pattern in patterns.entries) {
      if (text.contains(pattern.key)) {
        return {
          'date': pattern.value(),
          'matched': pattern.key,
        };
      }
    }

    // 정규식으로 시간 형식 파싱
    RegExp timeRegex = RegExp(r'(\d{1,2}):(\d{2})');
    final match = timeRegex.firstMatch(text);
    if (match != null) {
      final hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      return {
        'hour': hour,
        'minute': minute,
        'time': '${hour}:${minute.toString().padLeft(2, '0')}',
      };
    }

    return null;
  }

  // 의도(Intent) 인식
  static String recognizeIntent(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();

    if (lowerMessage.contains('일정') ||
        lowerMessage.contains('추가') ||
        lowerMessage.contains('등록') ||
        lowerMessage.contains('일정잡') ||
        lowerMessage.contains('약속')) {
      return 'add_schedule';
    }

    if (lowerMessage.contains('일정') && lowerMessage.contains('보') ||
        lowerMessage.contains('언제') ||
        lowerMessage.contains('뭐')) {
      return 'view_schedule';
    }

    if (lowerMessage.contains('삭제') || lowerMessage.contains('취소')) {
      return 'delete_schedule';
    }

    if (lowerMessage.contains('수정') || lowerMessage.contains('변경')) {
      return 'edit_schedule';
    }

    return 'general';
  }

  // 일정 정보 추출
  static Map<String, String> extractScheduleInfo(String userMessage) {
    final info = <String, String>{};

    // 제목/활동 추출
    final titlePatterns = [
      RegExp(r'(공부|수학|영어|과학|한국어|미술|체육|음악|역사|지리)'),
      RegExp(r'(운동|산책|독서|영화|쇼핑|식사|만남|회의)'),
    ];

    for (var pattern in titlePatterns) {
      final match = pattern.firstMatch(userMessage);
      if (match != null) {
        info['title'] = match.group(0) ?? '';
        break;
      }
    }

    // 카테고리 분류
    if (userMessage.contains('공부') || userMessage.contains('수학')) {
      info['category'] = 'study';
    } else if (userMessage.contains('운동') || userMessage.contains('스포츠')) {
      info['category'] = 'exercise';
    } else if (userMessage.contains('만남') || userMessage.contains('약속')) {
      info['category'] = 'meeting';
    } else {
      info['category'] = 'other';
    }

    return info;
  }
}

// ==================== AI 챗봇 엔진 ====================
class AIAssistant {
  final ScheduleDatabase _db = ScheduleDatabase();
  List<ChatMessage> chatHistory = [];

  Future<String> processUserMessage(String userMessage) async {
    // 사용자 메시지 저장
    chatHistory.add(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: userMessage,
      isUser: true,
      timestamp: DateTime.now(),
    ));

    // 의도 인식
    final intent = NLPEngine.recognizeIntent(userMessage);
    String response = '';

    switch (intent) {
      case 'add_schedule':
        response = await _handleAddSchedule(userMessage);
        break;
      case 'view_schedule':
        response = await _handleViewSchedule(userMessage);
        break;
      case 'delete_schedule':
        response = await _handleDeleteSchedule(userMessage);
        break;
      case 'general':
        response = _generateGeneralResponse(userMessage);
        break;
      default:
        response = '죄송합니다. 다시 말씀해주실 수 있을까요?';
    }

    // 응답 저장
    chatHistory.add(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: response,
      isUser: false,
      timestamp: DateTime.now(),
    ));

    return response;
  }

  Future<String> _handleAddSchedule(String userMessage) async {
    try {
      final scheduleInfo = NLPEngine.extractScheduleInfo(userMessage);
      final timeInfo = NLPEngine.parseTimeExpression(userMessage);

      if (scheduleInfo.isEmpty || timeInfo == null) {
        return '일정을 추가하려면 다음 정보가 필요합니다:\n'
            '• 무엇을 할 예정인가요? (예: 수학공부, 운동)\n'
            '• 언제인가요? (예: 오늘 3시, 내일 오후 2시)';
      }

      final title = scheduleInfo['title'] ?? '일정';
      final category = scheduleInfo['category'] ?? 'other';
      final date = timeInfo['date'] ?? DateTime.now();

      // 시간 설정
      DateTime startTime = date;
      if (timeInfo['hour'] != null) {
        startTime = DateTime(date.year, date.month, date.day,
            timeInfo['hour'], timeInfo['minute'] ?? 0);
      }

      DateTime endTime = startTime.add(Duration(hours: 1));

      // 데이터베이스에 저장
      final schedule = ScheduleItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        startTime: startTime,
        endTime: endTime,
        category: category,
      );

      await _db.insertSchedule(schedule);

      final dateStr = DateFormat('M월 d일 E요일', 'ko_KR').format(startTime);
      final timeStr = DateFormat('H:mm').format(startTime);

      return '✅ 일정이 추가되었습니다!\n'
          '📝 제목: $title\n'
          '📅 날짜: $dateStr\n'
          '⏰ 시간: $timeStr\n'
          '✨ 일정 알림을 받으실 수 있습니다.';
    } catch (e) {
      return '죄송합니다. 일정 추가 중 오류가 발생했습니다: $e';
    }
  }

  Future<String> _handleViewSchedule(String userMessage) async {
    try {
      final timeInfo = NLPEngine.parseTimeExpression(userMessage);
      final date = timeInfo?['date'] ?? DateTime.now();

      final schedules = await _db.getSchedulesByDate(date);

      if (schedules.isEmpty) {
        return '${DateFormat('M월 d일').format(date)}에 예정된 일정이 없습니다.\n'
            '새 일정을 추가하시겠어요?';
      }

      String response =
          '${DateFormat('M월 d일 EEEE', 'ko_KR').format(date)}의 일정:\n\n';
      for (var schedule in schedules) {
        final timeStr = DateFormat('H:mm').format(schedule.startTime);
        response += '• [$timeStr] ${schedule.title}\n';
      }

      return response;
    } catch (e) {
      return '일정 조회 중 오류가 발생했습니다: $e';
    }
  }

  Future<String> _handleDeleteSchedule(String userMessage) async {
    return '삭제하려는 일정을 선택해주세요.\n'
        '현재는 앱에서 직접 삭제해주시기 바랍니다.';
  }

  String _generateGeneralResponse(String userMessage) {
    final responses = [
      '좋은 질문입니다! 혹시 일정 관리와 관련해서 도움이 필요하신가요?',
      '네, 알겠습니다. 무엇을 도와드릴까요?',
      '흥미로운 이야기네요! 일정을 추가하시거나 보고 싶으신 것이 있으신가요?',
      '감사합니다! 더 필요한 것이 있으신가요?',
    ];

    return responses[userMessage.hashCode % responses.length];
  }
}

// ==================== 개선된 UI 위젯 ====================
class ImprovedAIAssistantUI extends StatefulWidget {
  @override
  State<ImprovedAIAssistantUI> createState() => _ImprovedAIAssistantUIState();
}

class _ImprovedAIAssistantUIState extends State<ImprovedAIAssistantUI> {
  late AIAssistant _assistant;
  late TextEditingController _messageController;
  late ScrollController _scrollController;
  List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _assistant = AIAssistant();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    _loadInitialMessage();
  }

  void _loadInitialMessage() {
    setState(() {
      _messages = [
        ChatMessage(
          id: '0',
          content: '안녕하세요! 📚 저는 당신의 개인 일정 도우미입니다.\n'
              '다음과 같이 도와드릴 수 있습니다:\n\n'
              '✨ "오늘 3시에 수학공부 추가해줘"\n'
              '✨ "내일 일정 뭐가 있어?"\n'
              '✨ "다음주 약속 있나?"\n\n'
              '자연스러운 대화로 일정을 관리해보세요!',
          isUser: false,
          timestamp: DateTime.now(),
        )
      ];
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final userMessage = _messageController.text;
    _messageController.clear();

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _assistant.processUserMessage(userMessage);

      setState(() {
        _messages = _assistant.chatHistory;
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('오류: $e')));
    }
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('📅 AI 일정 관리 어시스턴트'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: CircularProgressIndicator(),
                  );
                }

                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.blue.shade600 : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: message.isUser ? Colors.white : Colors.black87,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: '일정을 자연스럽게 말씀해주세요...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          SizedBox(width: 8),
          FloatingActionButton(
            mini: true,
            onPressed: _isLoading ? null : _sendMessage,
            child: Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
