import 'dart:html' as html;
import 'today_view_storage_base.dart';

TodayViewStorage createTodayViewStorageImpl() => _WebTodayViewStorage();

class _WebTodayViewStorage implements TodayViewStorage {
  static const _key = 'today_view_minimal';

  @override
  Future<bool> isMinimalMode() async {
    return html.window.localStorage[_key] == 'true';
  }

  @override
  Future<void> setMinimalMode(bool value) async {
    html.window.localStorage[_key] = value ? 'true' : 'false';
  }
}
