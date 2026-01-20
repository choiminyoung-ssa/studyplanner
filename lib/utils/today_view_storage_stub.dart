import 'today_view_storage_base.dart';

TodayViewStorage createTodayViewStorageImpl() => _StubTodayViewStorage();

class _StubTodayViewStorage implements TodayViewStorage {
  bool _minimalMode = false;

  @override
  Future<bool> isMinimalMode() async => _minimalMode;

  @override
  Future<void> setMinimalMode(bool value) async {
    _minimalMode = value;
  }
}
