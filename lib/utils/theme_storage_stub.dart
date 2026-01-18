import 'package:shared_preferences/shared_preferences.dart';
import 'theme_storage_base.dart';

ThemeStorage createThemeStorageImpl() => _SharedPrefsThemeStorage();

class _SharedPrefsThemeStorage implements ThemeStorage {
  static const _prefKey = 'theme_mode';

  @override
  Future<String?> readThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey);
  }

  @override
  Future<void> writeThemeMode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, value);
  }
}
