import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../utils/theme_storage.dart';
import '../utils/theme_storage_base.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  final ThemeStorage _storage = createThemeStorage();

  ThemeMode get themeMode => _themeMode;

  Future<void> loadTheme() async {
    try {
      final stored = await _storage.readThemeMode();
      final mode = _decodeThemeMode(stored);
      if (mode != _themeMode) {
        _themeMode = mode;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Theme load failed: $e');
    }
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      await _storage.writeThemeMode(_encodeThemeMode(mode));
    } catch (e) {
      debugPrint('Theme save failed: $e');
    }
  }

  String _encodeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
      default:
        return 'system';
    }
  }

  ThemeMode _decodeThemeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
