import 'package:flutter/material.dart';
import '../../models/ai_settings.dart';
import '../../services/unified_ai_service.dart';

class AISettingsScreen extends StatefulWidget {
  final UnifiedAIService aiService;

  const AISettingsScreen({super.key, required this.aiService});

  @override
  State<AISettingsScreen> createState() => _AISettingsScreenState();
}

class _AISettingsScreenState extends State<AISettingsScreen> {
  late AISettings _currentSettings;
  final TextEditingController _geminiKeyController = TextEditingController();
  final TextEditingController _groqKeyController = TextEditingController();
  bool _isSaving = false;
  bool _hasStoredGeminiKey = false;
  bool _hasStoredGroqKey = false;

  @override
  void initState() {
    super.initState();
    _currentSettings = widget.aiService.currentSettings;
    _hasStoredGeminiKey =
        _currentSettings.geminiApiKey?.trim().isNotEmpty ?? false;
    _hasStoredGroqKey =
        _currentSettings.groqApiKey?.trim().isNotEmpty ?? false;
    _geminiKeyController.clear();
    _groqKeyController.clear();
  }

  @override
  void dispose() {
    _geminiKeyController.dispose();
    _groqKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    final geminiInput = _geminiKeyController.text.trim();
    final groqInput = _groqKeyController.text.trim();

    // 사용자가 키를 입력하지 않았을 경우 내장된 기본 키 사용
    final defaultSettings = AISettings.defaultSettings();
    final resolvedGeminiKey = geminiInput.isEmpty
        ? (_currentSettings.geminiApiKey?.trim().isNotEmpty == true
            ? _currentSettings.geminiApiKey
            : defaultSettings.geminiApiKey)
        : geminiInput;

    final resolvedGroqKey = groqInput.isEmpty
        ? (_currentSettings.groqApiKey?.trim().isNotEmpty == true
            ? _currentSettings.groqApiKey
            : defaultSettings.groqApiKey)
        : groqInput;

    final newSettings = AISettings(
      mode: _currentSettings.mode,
      geminiApiKey: resolvedGeminiKey,
      groqApiKey: resolvedGroqKey,
    );

    final success = await widget.aiService.updateSettings(newSettings);

    setState(() => _isSaving = false);

    if (!mounted) return;

    if (success) {
      _currentSettings = newSettings;
      _hasStoredGeminiKey =
          _currentSettings.geminiApiKey?.trim().isNotEmpty ?? false;
      _hasStoredGroqKey =
          _currentSettings.groqApiKey?.trim().isNotEmpty ?? false;
      _geminiKeyController.clear();
      _groqKeyController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 설정이 저장되었습니다'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // 변경사항 있음을 알림
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ 설정 저장에 실패했습니다'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 설정'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_rounded),
              tooltip: '저장',
              onPressed: _saveSettings,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 현재 AI 모드 표시
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    Theme.of(context).colorScheme.secondary.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '${widget.aiService.currentAIIcon} 현재 사용 중',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.aiService.currentAIName,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // AI 모드 선택 섹션
            Text(
              'AI 모드 선택',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Google Gemini AI 옵션
            _buildAIModeCard(
              mode: AIMode.gemini,
              title: AIMode.gemini.displayName,
              description: AIMode.gemini.description,
              icon: AIMode.gemini.icon,
              isDark: isDark,
            ),
            const SizedBox(height: 12),

            // Groq AI 옵션
            _buildAIModeCard(
              mode: AIMode.groq,
              title: AIMode.groq.displayName,
              description: AIMode.groq.description,
              icon: AIMode.groq.icon,
              isDark: isDark,
            ),
            const SizedBox(height: 12),

            // Local AI 옵션
            _buildAIModeCard(
              mode: AIMode.local,
              title: AIMode.local.displayName,
              description: AIMode.local.description,
              icon: AIMode.local.icon,
              isDark: isDark,
            ),
            const SizedBox(height: 32),

            // Gemini API 키 입력 (Gemini 모드 선택 시만 표시)
            if (_currentSettings.mode == AIMode.gemini) ...[
              Text(
                'Google Gemini API 키',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _hasStoredGeminiKey
                    ? '저장된 키가 있습니다. 보안상 화면에 표시하지 않습니다.'
                    : 'Gemini API 키는 Google AI Studio에서 무료로 발급받을 수 있습니다.',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _geminiKeyController,
                obscureText: true,
                style: const TextStyle(fontSize: 15),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText:
                      _hasStoredGeminiKey ? '새 API 키 입력' : 'AIza...',
                  prefixIcon: Icon(
                    Icons.key_rounded,
                    color: isDark
                        ? Colors.blue[400]
                        : Theme.of(context).colorScheme.primary,
                  ),
                  suffixIcon: _geminiKeyController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          onPressed: () {
                            setState(() {
                              _geminiKeyController.clear();
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark
                          ? Colors.blue[400]!
                          : Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
                ),
              ),
              const SizedBox(height: 16),

              // API 키 발급 안내
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.blue[900]!.withOpacity(0.2)
                      : Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.blue[700]! : Colors.blue[200]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: isDark ? Colors.blue[300] : Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'API 키 발급 방법',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.blue[100] : Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '1. Google AI Studio 접속\n'
                      '   (aistudio.google.com)\n\n'
                      '2. "Get API Key" 클릭\n\n'
                      '3. API 키 복사 후 붙여넣기',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: isDark ? Colors.blue[100] : Colors.blue[900],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_currentSettings.mode == AIMode.groq) ...[
              Text(
                'Groq API 키',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _hasStoredGroqKey
                    ? '저장된 키가 있습니다. 보안상 화면에 표시하지 않습니다.'
                    : 'Groq API 키는 Groq Cloud에서 발급받을 수 있습니다.',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _groqKeyController,
                obscureText: true,
                style: const TextStyle(fontSize: 15),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _hasStoredGroqKey ? '새 API 키 입력' : 'gsk_...',
                  prefixIcon: Icon(
                    Icons.key_rounded,
                    color: isDark ? Colors.green[400] : Colors.green[700],
                  ),
                  suffixIcon: _groqKeyController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          onPressed: () {
                            setState(() {
                              _groqKeyController.clear();
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? Colors.green[400]! : Colors.green[700]!,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.green[900]!.withOpacity(0.2)
                      : Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.green[700]! : Colors.green[200]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: isDark ? Colors.green[300] : Colors.green[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'API 키 발급 방법',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? Colors.green[100] : Colors.green[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '1. Groq Cloud 접속\n'
                      '   (console.groq.com)\n\n'
                      '2. API Keys 메뉴 클릭\n\n'
                      '3. API 키 복사 후 붙여넣기',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: isDark ? Colors.green[100] : Colors.green[900],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),

            // 저장 버튼
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                ),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '저장하기',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIModeCard({
    required AIMode mode,
    required String title,
    required String description,
    required String icon,
    required bool isDark,
  }) {
    final isSelected = _currentSettings.mode == mode;

    return InkWell(
      onTap: () {
        setState(() {
          _currentSettings = _currentSettings.copyWith(mode: mode);
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                  : Theme.of(context).colorScheme.primary.withOpacity(0.1))
              : (isDark ? const Color(0xFF2C2C2C) : Colors.grey[50]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // 라디오 버튼
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
                  width: 2,
                ),
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.circle,
                      size: 12,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 16),

            // 아이콘
            Text(
              icon,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(width: 16),

            // 텍스트
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : (isDark ? Colors.white : Colors.black),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}