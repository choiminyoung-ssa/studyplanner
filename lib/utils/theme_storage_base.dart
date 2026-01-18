abstract class ThemeStorage {
  Future<String?> readThemeMode();
  Future<void> writeThemeMode(String value);
}
