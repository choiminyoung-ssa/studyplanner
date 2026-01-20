import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  String? _offlineUserId;
  String? _offlineEmail;
  String? _offlineDisplayName;
  String? _offlinePhotoUrl;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null || _offlineUserId != null;
  String? get userId => _user?.uid ?? _offlineUserId;

  AuthProvider() {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      // SharedPreferences에서 저장된 사용자 정보 로드
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString('user_id');
      final savedEmail = prefs.getString('user_email');
      final savedDisplayName = prefs.getString('user_display_name');
      final savedPhotoUrl = prefs.getString('user_photo_url');

      if (savedUserId != null) {
        _offlineUserId = savedUserId;
        _offlineEmail = savedEmail;
        _offlineDisplayName = savedDisplayName;
        _offlinePhotoUrl = savedPhotoUrl;
        _isInitialized = true;
        notifyListeners();
      } else {
        // 온라인 모드: Firebase 인증 상태 변경 리스너
        _authService.authStateChanges.listen((User? user) {
          _user = user;
          _isInitialized = true;
          notifyListeners();
        });
      }
    } catch (e) {
      print('❌ AuthProvider 초기화 오류: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  // 회원가입
  Future<bool> signUp(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signUp(email: email, password: password);
      // 회원가입 성공 시 SharedPreferences에 사용자 정보 저장
      final prefs = await SharedPreferences.getInstance();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _user = user;
        _offlineUserId = null;
        _offlineEmail = null;
        _offlineDisplayName = null;
        _offlinePhotoUrl = null;
        await prefs.setString('user_id', user.uid);
        await prefs.setString('user_email', user.email ?? '');
        await prefs.setString('user_display_name', user.displayName ?? '');
        await prefs.setString('user_photo_url', user.photoURL ?? '');
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 로그인
  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_authService.isDemoCredentials(email, password)) {
        await _authService.signInDemo();
      } else {
        await _authService.signIn(email: email, password: password);
      }
      
      // 로그인 성공 시 SharedPreferences에 사용자 정보 저장
      final prefs = await SharedPreferences.getInstance();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _user = user;
        _offlineUserId = null;
        _offlineEmail = null;
        _offlineDisplayName = null;
        _offlinePhotoUrl = null;
        await prefs.setString('user_id', user.uid);
        await prefs.setString('user_email', user.email ?? '');
        await prefs.setString('user_display_name', user.displayName ?? '');
        await prefs.setString('user_photo_url', user.photoURL ?? '');
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
      _user = null;
      _offlineUserId = null;
      _offlineEmail = null;
      _offlineDisplayName = null;
      _offlinePhotoUrl = null;
      
      // 로그아웃 시 SharedPreferences에서 사용자 정보 삭제
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('user_email');
      await prefs.remove('user_display_name');
      await prefs.remove('user_photo_url');
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Google 로그인
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signInWithGoogle();
      
      // Google 로그인 성공 시 SharedPreferences에 사용자 정보 저장
      final prefs = await SharedPreferences.getInstance();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _user = user;
        _offlineUserId = null;
        _offlineEmail = null;
        _offlineDisplayName = null;
        _offlinePhotoUrl = null;
        await prefs.setString('user_id', user.uid);
        await prefs.setString('user_email', user.email ?? '');
        await prefs.setString('user_display_name', user.displayName ?? '');
        await prefs.setString('user_photo_url', user.photoURL ?? '');
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // 인터넷 연결 시 Firebase와 동기화
  Future<void> syncWithFirebase() async {
    if (_offlineUserId != null) {
      try {
        // 인터넷 연결 확인 후 Firebase와 동기화 시도
        final prefs = await SharedPreferences.getInstance();
        final savedUserId = prefs.getString('user_id');
        
        if (savedUserId != null) {
          // Firebase 인증 상태 확인
          final firebaseUser = FirebaseAuth.instance.currentUser;
          if (firebaseUser != null && firebaseUser.uid == savedUserId) {
            // Firebase와 일치하는 사용자 확인 - 온라인 모드로 전환
            _user = firebaseUser;
            _offlineUserId = null;
            _offlineEmail = null;
            _offlineDisplayName = null;
            _offlinePhotoUrl = null;
            notifyListeners();
            print('✅ 오프라인 → 온라인 모드 전환 완료');
          } else {
            // Firebase에서 사용자 정보를 찾을 수 없음 - 로그아웃 처리
            await signOut();
            print('⚠️ Firebase 사용자 정보 불일치 - 로그아웃 처리');
          }
        }
      } catch (e) {
        print('❌ Firebase 동기화 오류: $e');
      }
    }
  }
}
