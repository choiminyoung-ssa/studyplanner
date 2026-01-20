import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences';
import '../services/auth_service.dart';

/// 오프라인 모드를 위한 Mock User 클래스
class MockUser implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final String? photoURL;
  @override
  final bool isAnonymous;
  @override
  final bool isEmailVerified;

  @override
  String? get refreshToken => null;
  @override
  final List<UserInfo> providerData;
  @override
  final UserMetadata metadata;
  @override
  final String? phoneNumber;
  @override
  final String? tenantId;
  @override
  final MultiFactor multiFactor;

  MockUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.isAnonymous = false,
    this.isEmailVerified = false,
    this.providerData = const [],
    this.metadata = const UserMetadata(),
    this.phoneNumber,
    this.tenantId,
    this.multiFactor = const MultiFactor(),
  });

  @override
  bool get emailVerified => isEmailVerified;

  @override
  Future<void> delete() async {}

  @override
  Future<String> getIdToken([bool? forceRefresh]) async => '';

  @override
  Future<IdTokenResult> getIdTokenResult([bool? forceRefresh]) async {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    throw UnimplementedError();
  }

  @override
  Future<ConfirmationResult> linkWithPhoneNumber(
    String phoneNumber, [
    RecaptchaVerifier? recaptchaVerifier,
  ]) async {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> linkWithProvider(AuthProvider provider) async {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> linkWithPopup(AuthProvider provider) async {
    throw UnimplementedError();
  }

  @override
  Future<void> linkWithRedirect(AuthProvider provider) async {}

  @override
  Future<UserCredential> reauthenticateWithCredential(
      AuthCredential credential) async {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> reauthenticateWithProvider(
      AuthProvider provider) async {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> reauthenticateWithPopup(AuthProvider provider) async {
    throw UnimplementedError();
  }

  @override
  Future<void> reauthenticateWithRedirect(AuthProvider provider) async {}

  @override
  Future<void> reload() async {}

  @override
  Future<bool> reauthenticateWithCustomToken(String token) async {
    throw UnimplementedError();
  }

  @override
  Future<void> sendEmailVerification(
      [ActionCodeSettings? actionCodeSettings]) async {}

  @override
  Future<User> unlink(String providerId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateEmail(String newEmail) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> updatePhoneNumber(PhoneAuthCredential credential) async {}

  @override
  Future<void> updatePhoneNumberCredential(
      PhoneAuthCredential credential) async {}

  @override
  Future<void> updateDisplayName(String? displayName) async {}

  @override
  Future<void> updatePhotoURL(String? photoURL) async {}

  @override
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {}

  @override
  Future<void> verifyBeforeUpdateEmail(
    String newEmail, [
    ActionCodeSettings? actionCodeSettings,
  ]) async {}

  @override
  Stream<User?> get userChanges => Stream.empty();
}

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
        _user = MockUser(
          uid: savedUserId,
          email: savedEmail,
          displayName: savedDisplayName,
          photoURL: savedPhotoUrl,
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
      // 회원가입 성공 시 SharedPreferences에 사용자 정보 저장
      final prefs = await SharedPreferences.getInstance();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
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
}
