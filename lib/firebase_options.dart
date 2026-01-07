// 이 파일은 Firebase CLI를 사용하여 자동 생성해야 합니다.
//
// Firebase 프로젝트 설정 방법:
// 1. Firebase Console (https://console.firebase.google.com/)에서 프로젝트 생성
// 2. Firebase CLI 설치: npm install -g firebase-tools
// 3. Firebase 로그인: firebase login
// 4. Flutter 앱에 Firebase 설정: flutterfire configure
//
// flutterfire configure 명령어를 실행하면 이 파일이 자동으로 생성됩니다.
//
// 임시로 아래 코드를 사용하여 앱을 실행할 수 있지만,
// 실제 Firebase 기능을 사용하려면 반드시 위 과정을 거쳐야 합니다.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA3HKD2nYtJG-_uueZZbAoJVCGuQRmbEQY',
    appId: '1:227699159450:web:5dd1db389307da1ca1ca23',
    messagingSenderId: '227699159450',
    projectId: 'study-planner-9d8c0',
    authDomain: 'study-planner-9d8c0.firebaseapp.com',
    storageBucket: 'study-planner-9d8c0.firebasestorage.app',
    measurementId: 'G-V28H389EW6',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: 'YOUR_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_STORAGE_BUCKET',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_STORAGE_BUCKET',
    iosBundleId: 'com.example.flutterApplicationStudyplanner',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_MACOS_API_KEY',
    appId: 'YOUR_MACOS_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_STORAGE_BUCKET',
    iosBundleId: 'com.example.flutterApplicationStudyplanner',
  );
}
