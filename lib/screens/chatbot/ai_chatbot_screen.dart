import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/unified_ai_service.dart';
import '../../services/command_handler_service.dart';
import '../settings/ai_settings_screen.dart';

class AIChatbotScreen extends StatefulWidget {
  const AIChatbotScreen({super.key});

  @override
  State<AIChatbotScreen> createState() => _AIChatbotScreenState();
}

class _AIChatbotScreenState extends State<AIChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  late UnifiedAIService _aiService;
  late CommandHandlerService _commandHandler;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    _aiService = UnifiedAIService();
    final userId = context.read<AuthProvider>().user?.uid ?? '';
    _commandHandler = CommandHandlerService(userId: userId);

    // 환영 메시지
    _messages.add(
      ChatMessage(
        text: '안녕하세요! 👋\n\n'
            '저는 학습 플래너 AI 어시스턴트입니다.\n\n'
            '다음과 같은 기능을 도와드릴 수 있어요:\n'
            '• 일정 추가/조회\n'
            '• 학습 통계 확인\n'
            '• 할일 관리\n'
            '• 검색\n'
            '• 공부 팁 추천\n\n'
            '무엇을 도와드릴까요?',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _messages.add(
        ChatMessage(
          text: userMessage,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      // 1. 로컬 AI에게 메시지 전송
      final aiResponse = await _aiService.processMessage(userMessage);

      // 2. 명령어 감지 및 처리
      final intent = await _aiService.parseUserIntent(userMessage);
      String finalResponse = aiResponse;

      // 더 낮은 신뢰도의 명령어도 실행 (0.6 이상)
      print('🎯 DEBUG: intent = $intent');
      print('📊 DEBUG: action = ${intent['action']}, confidence = ${intent['confidence']}');
      
      if (intent['confidence'] > 0.6) {
        String? commandResult;

        print('🚀 DEBUG: Executing action: ${intent['action']}');

        try {
          switch (intent['action']) {
            case 'create_schedule':
              print('📅 DEBUG: Creating schedule...');
              commandResult = await _commandHandler.createSchedule(
                intent['parameters'],
              );
              print('✅ DEBUG: Schedule created: $commandResult');
              break;
            case 'view_schedule':
              print('👁️ DEBUG: Viewing schedule...');
              commandResult = await _commandHandler.viewSchedule(
                intent['parameters'],
              );
              print('✅ DEBUG: Schedule viewed: $commandResult');
              break;
            case 'view_stats':
              print('📊 DEBUG: Viewing stats...');
              commandResult = await _commandHandler.viewStats(
                intent['parameters'],
              );
              print('✅ DEBUG: Stats viewed: $commandResult');
              break;
            case 'manage_todo':
              print('✅ DEBUG: Managing todo...');
              commandResult = await _commandHandler.manageTodo(
                intent['parameters'],
              );
              print('✅ DEBUG: Todo managed: $commandResult');
              break;
            case 'search':
              print('🔍 DEBUG: Searching...');
              commandResult = await _commandHandler.search(
                intent['parameters'],
              );
              print('✅ DEBUG: Search done: $commandResult');
              break;
            default:
              print('⚠️ DEBUG: Unknown action: ${intent['action']}');
          }

          // 명령어 실행 결과가 있으면 추가
          if (commandResult != null && commandResult.isNotEmpty) {
            finalResponse = '$aiResponse\n\n━━━━━━━━━━━━━━\n\n$commandResult';
            print('✅ DEBUG: Final response prepared');
          } else {
            print('⚠️ DEBUG: Command result is empty or null');
          }
        } catch (e) {
          print('❌ DEBUG: Error during command execution: $e');
          finalResponse = '$aiResponse\n\n⚠️ 명령어 실행 중 오류: ${e.toString()}';
        }
      } else {
        print('⚠️ DEBUG: Confidence too low (${intent['confidence']}), skipping command execution');
      }

      setState(() {
        _messages.add(
          ChatMessage(
            text: finalResponse,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: '죄송합니다. 오류가 발생했습니다.\n${e.toString()}',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ),
        );
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.smart_toy_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI 어시스턴트',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_aiService.currentAIIcon} ${_aiService.currentAIName}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'AI 설정',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AISettingsScreen(aiService: _aiService),
                ),
              );
              // 설정이 변경되었으면 화면 새로고침
              if (result == true) {
                setState(() {
                  _aiService.resetChat();
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: '도움말',
            onPressed: () {
              _messageController.text = '도움말';
              _sendMessage();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '새 대화 시작',
            onPressed: () {
              setState(() {
                _messages.clear();
                _initializeServices();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 안내 배너
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.blue[900]!.withOpacity(0.3)
                  : Colors.blue[50],
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.blue[700]! : Colors.blue[100]!,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: isDark ? Colors.blue[300] : Colors.blue[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _aiService.currentMode.name == 'gemini'
                        ? '🤖 Gemini AI 사용 중 (고품질 응답)'
                        : '💡 완전 무료! API 키나 계정이 필요 없습니다',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.blue[100] : Colors.blue[900],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 메시지 리스트
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // 로딩 인디케이터
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('생각 중...'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // 빠른 명령어 버튼
          if (!_isLoading && _messages.length <= 2)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickButton('📅 일정 추가', '일정 추가해줘'),
                    const SizedBox(width: 8),
                    _buildQuickButton('📊 통계 보기', '이번 주 공부 시간'),
                    const SizedBox(width: 8),
                    _buildQuickButton('✅ 할일 목록', '할일 목록'),
                    const SizedBox(width: 8),
                    _buildQuickButton('💡 공부 팁', '공부 방법 추천'),
                  ],
                ),
              ),
            ),

          // 입력 필드
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              border: isDark
                  ? Border(top: BorderSide(color: Colors.grey[800]!))
                  : null,
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: '메시지를 입력하세요...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF2C2C2C)
                            : Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickButton(String label, String message) {
    return OutlinedButton(
      onPressed: () {
        _messageController.text = message;
        _sendMessage();
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        side: BorderSide(color: Theme.of(context).colorScheme.primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: message.isError
                    ? Colors.red[100]
                    : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                message.isError ? Icons.error_outline : Icons.smart_toy_rounded,
                color: message.isError
                    ? Colors.red[700]
                    : Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Theme.of(context).colorScheme.primary
                    : message.isError
                        ? Colors.red[50]
                        : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : Colors.black87,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}
