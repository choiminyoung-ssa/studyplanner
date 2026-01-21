import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/timer_provider.dart';
import 'providers/statistics_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/calendar_sync_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/main_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'utils/web_plugin_registrar.dart'
    if (dart.library.html) 'utils/web_plugin_registrar_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerWebPlugins();

  ErrorWidget.builder = (details) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '오류가 발생했습니다.\n${details.exceptionAsString()}',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  };

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  await runZonedGuarded(() async {
    // Firebase 초기화 (이미 초기화되어 있는지 확인). 중복 초기화 오류는 무시합니다.
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      // 이미 [DEFAULT] 앱이 존재하는 경우 (예: 네이티브에서 자동 초기화) 무시
      if (e.code != 'duplicate-app') rethrow;
    }

    await _configureWebPersistence();

    // 날짜 포맷 로케일 데이터 초기화 (예: 'ko_KR')
    await initializeDateFormatting('ko_KR');

    runApp(const MyApp());
  }, (error, stack) {
    runApp(FatalErrorApp(error: error, stack: stack));
  });
}

Future<void> _configureWebPersistence() async {
  if (!kIsWeb) return;
  try {
    await fb_auth.FirebaseAuth.instance.setPersistence(fb_auth.Persistence.SESSION);
  } catch (e) {
    debugPrint('Web auth persistence 설정 실패: $e');
  }
  try {
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
  } catch (e) {
    debugPrint('Web Firestore persistence 비활성화 실패: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => TimerProvider()),
        ChangeNotifierProvider(create: (_) => StatisticsProvider()),
        ChangeNotifierProvider(create: (_) => GoalProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadTheme()),
        ChangeNotifierProvider(create: (_) => CalendarSyncProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: '공부 일정 관리',
            debugShowCheckedModeBanner: false,
            // 로케일 지원 (한국어)
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('ko', 'KR'),
            ],
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            themeMode: themeProvider.themeMode,
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    // 다크모드에서 높은 대비를 위한 커스텀 색상
    const darkBackground = Color(0xFF121212); // 매우 어두운 배경
    const darkSurface = Color(0xFF1E1E1E); // 카드/서페이스
    const darkSurfaceVariant = Color(0xFF2C2C2C); // 약간 밝은 서페이스

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: Colors.blue[400]!, // 밝은 파란색 (대비 향상)
        secondary: Colors.blueAccent[200]!,
        surface: darkSurface,
        error: Colors.red[400]!,
        onPrimary: Colors.black, // primary 위의 텍스트는 검정
        onSecondary: Colors.black,
        onSurface: Colors.white, // background 위의 텍스트는 흰색
        onError: Colors.black,
        surfaceContainerHighest: darkSurfaceVariant,
        outline: Colors.grey[700]!,
      ),
      useMaterial3: true,

      // 앱바 테마
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: darkSurface,
        foregroundColor: Colors.white, // 앱바 텍스트/아이콘 흰색
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // 카드 테마
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),

      // 입력 필드 테마
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue[400]!, width: 2),
        ),
        labelStyle: TextStyle(color: Colors.grey[400]),
        hintStyle: TextStyle(color: Colors.grey[600]),
      ),

      // 텍스트 테마 - 모든 텍스트 흰색 보장
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: Colors.white),
        displayMedium: TextStyle(color: Colors.white),
        displaySmall: TextStyle(color: Colors.white),
        headlineLarge: TextStyle(color: Colors.white),
        headlineMedium: TextStyle(color: Colors.white),
        headlineSmall: TextStyle(color: Colors.white),
        titleLarge: TextStyle(color: Colors.white),
        titleMedium: TextStyle(color: Colors.white),
        titleSmall: TextStyle(color: Colors.white),
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: Colors.grey),
        labelLarge: TextStyle(color: Colors.white),
        labelMedium: TextStyle(color: Colors.white),
        labelSmall: TextStyle(color: Colors.grey),
      ),

      // 리스트 타일 테마
      listTileTheme: ListTileThemeData(
        textColor: Colors.white,
        iconColor: Colors.white,
        tileColor: darkSurface,
      ),

      // 다이얼로그 테마
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),

      // 버튼 테마
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[400],
          foregroundColor: Colors.black, // 버튼 텍스트 검정 (대비)
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.blue[400],
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.grey[700]!),
        ),
      ),

      // 스위치 테마
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.blue[400];
          }
          return Colors.grey[600];
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.blue[200];
          }
          return Colors.grey[800];
        }),
      ),

      // 체크박스 테마
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.blue[400];
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.black),
      ),

      // Divider 테마
      dividerTheme: DividerThemeData(
        color: Colors.grey[800],
        thickness: 1,
      ),

      // 스캐폴드 배경
      scaffoldBackgroundColor: darkBackground,
    );
  }
}

// 인증 상태에 따라 화면 전환
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (!authProvider.isInitialized) {
          return const SplashScreen();
        }
        // 로그인되어 있으면 메인 화면, 아니면 로그인 화면
        if (authProvider.isAuthenticated) {
          return const MainScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 12),
            const Text('로그인 상태 확인 중입니다...'),
            const SizedBox(height: 6),
            Text(
              '잠시만 기다려주세요',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class FatalErrorApp extends StatelessWidget {
  final Object error;
  final StackTrace? stack;

  const FatalErrorApp({super.key, required this.error, this.stack});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              stack == null
                  ? '앱 시작 중 오류가 발생했습니다.\n$error'
                  : '앱 시작 중 오류가 발생했습니다.\n$error\n\n$stack',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }
}
