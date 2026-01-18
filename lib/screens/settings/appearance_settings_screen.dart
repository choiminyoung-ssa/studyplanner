import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().themeMode;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('화면 설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '테마 모드',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _buildThemeOption(
            context,
            title: '시스템 설정',
            subtitle: '기기 설정을 따라 자동 적용',
            mode: ThemeMode.system,
            currentMode: themeMode,
            icon: Icons.auto_awesome_rounded,
            accent: colorScheme.primary,
          ),
          _buildThemeOption(
            context,
            title: '라이트 모드',
            subtitle: '밝은 배경 테마',
            mode: ThemeMode.light,
            currentMode: themeMode,
            icon: Icons.light_mode_rounded,
            accent: colorScheme.secondary,
          ),
          _buildThemeOption(
            context,
            title: '다크 모드',
            subtitle: '어두운 배경 테마',
            mode: ThemeMode.dark,
            currentMode: themeMode,
            icon: Icons.dark_mode_rounded,
            accent: colorScheme.tertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required ThemeMode mode,
    required ThemeMode currentMode,
    required IconData icon,
    required Color accent,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = mode == currentMode;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? accent.withAlpha(18) : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? accent : colorScheme.outlineVariant.withAlpha(80),
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: accent.withAlpha(20),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: RadioListTile<ThemeMode>(
        value: mode,
        groupValue: currentMode,
        onChanged: (value) {
          if (value == null) return;
          context.read<ThemeProvider>().updateThemeMode(value);
        },
        title: Text(title),
        subtitle: Text(subtitle),
        secondary: Icon(icon, color: accent),
        activeColor: accent,
      ),
    );
  }
}
