import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_studyplanner/models/ai_settings.dart';

void main() {
  group('AI Settings Test', () {
    test('Default settings should have embedded keys', () {
      final defaultSettings = AISettings.defaultSettings();

      expect(defaultSettings.geminiApiKey, isNotNull);
      expect(defaultSettings.geminiApiKey!.isNotEmpty, isTrue);
      expect(defaultSettings.groqApiKey, isNotNull);
      expect(defaultSettings.groqApiKey!.isNotEmpty, isTrue);
    });

    test('Settings with empty keys should fall back to default keys', () {
      // 사용자가 키를 입력하지 않은 경우
      final emptySettings = AISettings(
        mode: AIMode.gemini,
        geminiApiKey: null,
        groqApiKey: null,
      );

      // 저장 로직 시뮬레이션
      final defaultSettings = AISettings.defaultSettings();
      final resolvedGeminiKey = emptySettings.geminiApiKey?.trim().isNotEmpty == true
          ? emptySettings.geminiApiKey
          : defaultSettings.geminiApiKey;

      final resolvedGroqKey = emptySettings.groqApiKey?.trim().isNotEmpty == true
          ? emptySettings.groqApiKey
          : defaultSettings.groqApiKey;

      final newSettings = AISettings(
        mode: emptySettings.mode,
        geminiApiKey: resolvedGeminiKey,
        groqApiKey: resolvedGroqKey,
      );

      // 내장된 키가 사용되었는지 확인
      expect(newSettings.geminiApiKey, equals(defaultSettings.geminiApiKey));
      expect(newSettings.groqApiKey, equals(defaultSettings.groqApiKey));
    });

    test('Settings with existing keys should preserve them', () {
      // 기존에 유효한 키가 있는 경우
      final existingSettings = AISettings(
        mode: AIMode.gemini,
        geminiApiKey: 'user_gemini_key_123',
        groqApiKey: 'user_groq_key_456',
      );

      // 저장 로직 시뮬레이션 (사용자 입력 없음)
      final defaultSettings = AISettings.defaultSettings();
      final resolvedGeminiKey = existingSettings.geminiApiKey?.trim().isNotEmpty == true
          ? existingSettings.geminiApiKey
          : defaultSettings.geminiApiKey;

      final resolvedGroqKey = existingSettings.groqApiKey?.trim().isNotEmpty == true
          ? existingSettings.groqApiKey
          : defaultSettings.groqApiKey;

      final newSettings = AISettings(
        mode: existingSettings.mode,
        geminiApiKey: resolvedGeminiKey,
        groqApiKey: resolvedGroqKey,
      );

      // 기존 키가 유지되었는지 확인
      expect(newSettings.geminiApiKey, equals('user_gemini_key_123'));
      expect(newSettings.groqApiKey, equals('user_groq_key_456'));
    });
  });
}