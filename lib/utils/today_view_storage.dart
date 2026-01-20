import 'today_view_storage_base.dart';
import 'today_view_storage_stub.dart'
    if (dart.library.html) 'today_view_storage_web.dart'
    if (dart.library.io) 'today_view_storage_io.dart';

TodayViewStorage createTodayViewStorage() => createTodayViewStorageImpl();
