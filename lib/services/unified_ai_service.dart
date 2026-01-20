import '../models/ai_settings.dart';
import 'gemini_ai_service.dart';
import 'groq_ai_service.dart';
import 'local_ai_service.dart';
import 'ai_settings_storage.dart';
import 'command_handler_service.dart';

/// 통합 AI 서비스
/// 사용자 설정에 따라 Gemini AI 또는 Local AI를 사용합니다.
class UnifiedAIService {
  AISettings _settings = AISettings.defaultSettings();
  final AISettingsStorage _storage = AISettingsStorage();

  GeminiAIService? _geminiService;
  GroqAIService? _groqService;
  final LocalAIService _localService = LocalAIService();

  UnifiedAIService() {
    _loadSettings();
  }

  /// 설정 불러오기
  Future<void> _loadSettings() async {
    _settings = await _storage.loadSettings();
    _initializeServices();
  }

  /// 서비스 초기화
  void _initializeServices() {
    if (_settings.mode == AIMode.gemini && _settings.canUseGemini) {
      _geminiService = GeminiAIService(apiKey: _settings.geminiApiKey!);
      _groqService = null;
      print('✅ Gemini AI 서비스 초기화 완료');
    } else if (_settings.mode == AIMode.groq && _settings.canUseGroq) {
      _groqService = GroqAIService(apiKey: _settings.groqApiKey!);
      _geminiService = null;
      print('✅ Groq AI 서비스 초기화 완료');
    } else {
      _geminiService = null;
      _groqService = null;
      print('✅ Local AI 서비스 사용 중');
    }
  }

  /// 현재 AI 모드 가져오기
  AIMode get currentMode => _settings.mode;
  AIMode get effectiveMode {
    if (_settings.mode == AIMode.gemini && _settings.canUseGemini) {
      return AIMode.gemini;
    }
    if (_settings.mode == AIMode.groq && _settings.canUseGroq) {
      return AIMode.groq;
    }
    return AIMode.local;
  }

  /// 현재 설정 가져오기
  AISettings get currentSettings => _settings;

  /// AI 모드 변경
  Future<bool> updateSettings(AISettings newSettings) async {
    _settings = newSettings;
    _initializeServices();
    return await _storage.saveSettings(newSettings);
  }

  /// 사용자 메시지 처리
  Future<String> processMessage(String message) async {
    // Gemini 모드이고 API 키가 있는 경우
    if (_settings.mode == AIMode.gemini && _settings.canUseGemini) {
      if (_geminiService == null) {
        _initializeServices();
      }

      if (_geminiService != null) {
        try {
          return await _geminiService!.processMessage(message);
        } catch (e) {
          print('❌ Gemini 오류, Local AI로 폴백: $e');
          // Gemini 실패 시 Local AI로 폴백
          return await _localService.processMessage(message);
        }
      }
    }

    // Groq 모드이고 API 키가 있는 경우
    if (_settings.mode == AIMode.groq && _settings.canUseGroq) {
      if (_groqService == null) {
        _initializeServices();
      }

      if (_groqService != null) {
        try {
          return await _groqService!.processMessage(message);
        } catch (e) {
          print('❌ Groq 오류, Local AI로 폴백: $e');
          return await _localService.processMessage(message);
        }
      }
    }

    // Local AI 사용
    return await _localService.processMessage(message);
  }

  /// 사용자 의도 파싱
  Future<Map<String, dynamic>> parseUserIntent(String message) async {
    // Gemini 모드이고 API 키가 있는 경우
    if (_settings.mode == AIMode.gemini && _settings.canUseGemini) {
      if (_geminiService == null) {
        _initializeServices();
      }

      if (_geminiService != null) {
        try {
          final intent = await _geminiService!.parseUserIntent(message);
          // Gemini가 낮은 신뢰도를 반환하면 Local AI로 폴백
          if (intent['confidence'] < 0.5) {
            print('⚠️ Gemini 신뢰도 낮음, Local AI로 폴백');
            return await _localService.parseUserIntent(message);
          }
          return intent;
        } catch (e) {
          print('❌ Gemini 의도 파싱 오류, Local AI로 폴백: $e');
          return await _localService.parseUserIntent(message);
        }
      }
    }

    // Groq 모드이고 API 키가 있는 경우
    if (_settings.mode == AIMode.groq && _settings.canUseGroq) {
      if (_groqService == null) {
        _initializeServices();
      }

      if (_groqService != null) {
        try {
          final intent = await _groqService!.parseUserIntent(message);
          if (intent['confidence'] < 0.5) {
            print('⚠️ Groq 신뢰도 낮음, Local AI로 폴백');
            return await _localService.parseUserIntent(message);
          }
          return intent;
        } catch (e) {
          print('❌ Groq 의도 파싱 오류, Local AI로 폴백: $e');
          return await _localService.parseUserIntent(message);
        }
      }
    }

    // Local AI 사용
    return await _localService.parseUserIntent(message);
  }

  /// 채팅 기록 초기화
  void resetChat() {
    _geminiService?.resetChat();
    _groqService?.resetChat();
    // Local AI는 상태가 없으므로 초기화 불필요
  }

  /// 현재 사용 중인 AI 이름
  String get currentAIName {
    if (effectiveMode == AIMode.gemini) {
      return 'Google Gemini AI';
    }
    if (effectiveMode == AIMode.groq) {
      return 'Groq AI';
    }
    return '로컬 AI (무료)';
  }

  /// 현재 사용 중인 AI 아이콘
  String get currentAIIcon {
    if (effectiveMode == AIMode.gemini) {
      return '🤖';
    }
    if (effectiveMode == AIMode.groq) {
      return '⚡';
    }
    return '💫';
  }

  /// 할일보관함에 추가 명령 처리
  Future<String> handleAddToBacklog(String message, String userId) async {
    try {
      // 명령어 인식
      final intent = await parseUserIntent(message);
      final action = intent['action'] ?? 'chat';
      final parameters = intent['parameters'] ?? {};

      if (action == 'add_to_backlog') {
        final commandHandler = CommandHandlerService(userId: userId);
        return await commandHandler.addToBacklog(parameters);
      }

      return '❌ 할일보관함 추가 명령을 인식할 수 없습니다.';
    } catch (e) {
      return '❌ 할일보관함 추가 중 오류가 발생했습니다: ${e.toString()}';
    }
  }

  /// API 키가 필요한지 여부
  bool get requiresApiKey {
    return _settings.mode == AIMode.gemini || _settings.mode == AIMode.groq;
  }

  /// API 키가 설정되어 있는지 여부
  bool get hasApiKey {
    if (_settings.mode == AIMode.gemini) {
      return _settings.geminiApiKey != null &&
          _settings.geminiApiKey!.isNotEmpty;
    }
    if (_settings.mode == AIMode.groq) {
      return _settings.groqApiKey != null &&
          _settings.groqApiKey!.isNotEmpty;
    }
    return false;
  }

  String get currentBannerMessage {
    if (effectiveMode == AIMode.gemini) {
      return '🤖 Gemini AI 사용 중 (고품질 응답)';
    }
    if (effectiveMode == AIMode.groq) {
      return '⚡ Groq AI 사용 중 (초고속 응답)';
    }
    return '💡 완전 무료! API 키나 계정이 필요 없습니다';
  }
}
