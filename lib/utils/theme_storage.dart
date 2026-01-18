import 'theme_storage_base.dart';
import 'theme_storage_stub.dart' if (dart.library.html) 'theme_storage_web.dart';

ThemeStorage createThemeStorage() => createThemeStorageImpl();
