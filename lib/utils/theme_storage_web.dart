import 'dart:html' as html;
import 'theme_storage_base.dart';

ThemeStorage createThemeStorageImpl() => _WebThemeStorage();

class _WebThemeStorage implements ThemeStorage {
  static const _prefKey = 'theme_mode';

  @override
  Future<String?> readThemeMode() async {
    return html.window.localStorage[_prefKey];
  }

  @override
  Future<void> writeThemeMode(String value) async {
    html.window.localStorage[_prefKey] = value;
  }
}
