import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_settings.dart';

/// AI 설정 저장소 서비스
/// SharedPreferences를 사용하여 AI 설정을 로컬에 저장합니다.
class AISettingsStorage {
  static const String _keyAISettings = 'ai_settings';

  AISettings _mergeWithDefaults(AISettings settings) {
    final defaults = AISettings.defaultSettings();
    return settings.copyWith(
      geminiApiKey: _resolveKey(settings.geminiApiKey, defaults.geminiApiKey),
      groqApiKey: _resolveKey(settings.groqApiKey, defaults.groqApiKey),
    );
  }

  String? _resolveKey(String? value, String? fallback) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return fallback;
    }
    return value;
  }

  /// AI 설정 불러오기
  Future<AISettings> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyAISettings);

      if (jsonString == null || jsonString.isEmpty) {
        return AISettings.defaultSettings();
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return _mergeWithDefaults(AISettings.fromJson(json));
    } catch (e) {
      print('❌ AI 설정 불러오기 실패: $e');
      return AISettings.defaultSettings();
    }
  }

  /// AI 설정 저장하기
  Future<bool> saveSettings(AISettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final resolved = _mergeWithDefaults(settings);
      final jsonString = jsonEncode(resolved.toJson());
      return await prefs.setString(_keyAISettings, jsonString);
    } catch (e) {
      print('❌ AI 설정 저장 실패: $e');
      return false;
    }
  }

  /// AI 설정 초기화 (기본값으로 리셋)
  Future<bool> clearSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_keyAISettings);
    } catch (e) {
      print('❌ AI 설정 초기화 실패: $e');
      return false;
    }
  }
}
