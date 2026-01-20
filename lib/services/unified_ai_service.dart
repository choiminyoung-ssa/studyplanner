import '../models/ai_settings.dart';
import 'gemini_ai_service.dart';
import 'local_ai_service.dart';
import 'ai_settings_storage.dart';

/// 통합 AI 서비스
/// 사용자 설정에 따라 Gemini AI 또는 Local AI를 사용합니다.
class UnifiedAIService {
  AISettings _settings = AISettings.defaultSettings();
  final AISettingsStorage _storage = AISettingsStorage();

  GeminiAIService? _geminiService;
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
      print('✅ Gemini AI 서비스 초기화 완료');
    } else {
      _geminiService = null;
      print('✅ Local AI 서비스 사용 중');
    }
  }

  /// 현재 AI 모드 가져오기
  AIMode get currentMode => _settings.mode;

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

    // Local AI 사용
    return await _localService.parseUserIntent(message);
  }

  /// 채팅 기록 초기화
  void resetChat() {
    _geminiService?.resetChat();
    // Local AI는 상태가 없으므로 초기화 불필요
  }

  /// 현재 사용 중인 AI 이름
  String get currentAIName {
    if (_settings.mode == AIMode.gemini && _settings.canUseGemini) {
      return 'Google Gemini AI';
    }
    return '로컬 AI (무료)';
  }

  /// 현재 사용 중인 AI 아이콘
  String get currentAIIcon {
    if (_settings.mode == AIMode.gemini && _settings.canUseGemini) {
      return '🤖';
    }
    return '💫';
  }

  /// API 키가 필요한지 여부
  bool get requiresApiKey {
    return _settings.mode == AIMode.gemini;
  }

  /// API 키가 설정되어 있는지 여부
  bool get hasApiKey {
    return _settings.geminiApiKey != null && _settings.geminiApiKey!.isNotEmpty;
  }
}
