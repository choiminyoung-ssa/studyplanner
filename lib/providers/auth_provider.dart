import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  String? get userId => _user?.uid;

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
        // 오프라인 모드: 저장된 정보로 사용자 객체 생성
        _user = User(
          uid: savedUserId,
          email: savedEmail,
          displayName: savedDisplayName,
          photoURL: savedPhotoUrl,
          isAnonymous: false,
          isEmailVerified: false,
          providerData: [],
          metadata: UserMetadata(
            creationTime: null,
            lastSignInTime: null,
          ),
          phoneNumber: null,
          tenantId: null,
          multiFactor: MultiFactor(
            enrolledFactors: [],
          ),
        );
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
}
