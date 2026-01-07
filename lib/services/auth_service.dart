import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Web용 OAuth Client ID
  final GoogleSignIn _googleSignIn = kIsWeb
      ? GoogleSignIn(clientId: '227699159450-d98oul5ujdvuao49k0jqv7s2pmkfappi.apps.googleusercontent.com')
      : GoogleSignIn();

  // 현재 사용자 가져오기
  User? get currentUser => _auth.currentUser;

  // 현재 사용자 ID 가져오기
  String? get currentUserId => _auth.currentUser?.uid;

  // 인증 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 회원가입
  Future<UserCredential?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      String errorMessage = '회원가입 실패';

      switch (e.code) {
        case 'weak-password':
          errorMessage = '비밀번호가 너무 약합니다. 6자 이상 입력해주세요.';
          break;
        case 'email-already-in-use':
          errorMessage = '이미 사용 중인 이메일입니다.';
          break;
        case 'invalid-email':
          errorMessage = '유효하지 않은 이메일 형식입니다.';
          break;
        default:
          errorMessage = '회원가입 중 오류가 발생했습니다: ${e.message}';
      }

      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('회원가입 중 예기치 않은 오류가 발생했습니다.');
    }
  }

  // 로그인
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      String errorMessage = '로그인 실패';

      switch (e.code) {
        case 'user-not-found':
          errorMessage = '존재하지 않는 사용자입니다.';
          break;
        case 'wrong-password':
          errorMessage = '비밀번호가 올바르지 않습니다.';
          break;
        case 'invalid-email':
          errorMessage = '유효하지 않은 이메일 형식입니다.';
          break;
        case 'user-disabled':
          errorMessage = '비활성화된 계정입니다.';
          break;
        default:
          errorMessage = '로그인 중 오류가 발생했습니다: ${e.message}';
      }

      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('로그인 중 예기치 않은 오류가 발생했습니다.');
    }
  }

  // 로그아웃 (Google 로그아웃도 포함)
  Future<void> signOut() async {
    try {
      // Google 로그인 상태인지 확인하고 로그아웃
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
    } catch (e) {
      throw Exception('로그아웃 중 오류가 발생했습니다.');
    }
  }

  // 비밀번호 재설정 이메일 전송
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      String errorMessage = '비밀번호 재설정 실패';

      switch (e.code) {
        case 'user-not-found':
          errorMessage = '존재하지 않는 사용자입니다.';
          break;
        case 'invalid-email':
          errorMessage = '유효하지 않은 이메일 형식입니다.';
          break;
        default:
          errorMessage = '비밀번호 재설정 중 오류가 발생했습니다: ${e.message}';
      }

      throw Exception(errorMessage);
    }
  }

  // Google 로그인
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Google 로그인 프로세스 시작
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // 사용자가 로그인 취소
        throw Exception('Google 로그인이 취소되었습니다.');
      }

      // Google 인증 정보 가져오기
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Firebase 인증 자격 증명 생성
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase로 로그인
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Google 로그인 실패';

      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage = '이미 다른 방법으로 가입된 계정입니다.';
          break;
        case 'invalid-credential':
          errorMessage = '유효하지 않은 인증 정보입니다.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Google 로그인이 활성화되지 않았습니다.';
          break;
        case 'user-disabled':
          errorMessage = '비활성화된 계정입니다.';
          break;
        default:
          errorMessage = 'Google 로그인 중 오류가 발생했습니다: ${e.message}';
      }

      throw Exception(errorMessage);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('People API') || msg.contains('SERVICE_DISABLED') || msg.contains('PERMISSION_DENIED')) {
        throw Exception('Google 로그인 오류: People API가 비활성화되어 있거나 권한이 부족합니다. Google Cloud Console에서 People API를 활성화하고 Web OAuth 클라이언트의 JavaScript origins(예: http://localhost:56819)를 확인하세요: https://console.developers.google.com/apis/api/people.googleapis.com/overview?project=227699159450');
      }
      throw Exception('Google 로그인 중 예기치 않은 오류가 발생했습니다: $e');
    }
  }

  // Google 로그아웃
  Future<void> signOutGoogle() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw Exception('Google 로그아웃 중 오류가 발생했습니다.');
    }
  }
}
