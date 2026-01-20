import 'package:shared_preferences/shared_preferences.dart';
import 'today_view_storage_base.dart';

TodayViewStorage createTodayViewStorageImpl() => _IoTodayViewStorage();

class _IoTodayViewStorage implements TodayViewStorage {
  static const _key = 'today_view_minimal';

  @override
  Future<bool> isMinimalMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  @override
  Future<void> setMinimalMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
