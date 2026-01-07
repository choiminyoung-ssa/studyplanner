# Firebase 설정 가이드

이 앱을 실행하려면 Firebase 프로젝트를 설정해야 합니다.

## 1. Firebase 프로젝트 생성

1. [Firebase Console](https://console.firebase.google.com/)에 접속
2. "프로젝트 추가" 클릭
3. 프로젝트 이름 입력 (예: "study-planner")
4. Google Analytics는 선택사항 (원하면 활성화)
5. 프로젝트 생성 완료

## 2. Firebase CLI 설치

터미널에서 다음 명령어를 실행하세요:

```bash
# Node.js가 설치되어 있어야 합니다
npm install -g firebase-tools

# Firebase 로그인
firebase login

# FlutterFire CLI 설치
dart pub global activate flutterfire_cli
```

## 3. Firebase 앱 등록 및 설정

프로젝트 루트 디렉토리에서 다음 명령어를 실행:

```bash
flutterfire configure
```

이 명령어는:
- Firebase 프로젝트 선택
- 지원할 플랫폼 선택 (iOS, Android, Web, macOS 등)
- `lib/firebase_options.dart` 파일 자동 생성

## 4. Firebase Authentication 활성화

1. Firebase Console에서 프로젝트 선택
2. 좌측 메뉴에서 "Authentication" 클릭
3. "시작하기" 클릭
4. "Sign-in method" 탭 선택
5. "이메일/비밀번호" 활성화
   - "이메일/비밀번호" 클릭
   - "사용 설정" 토글 ON
   - "저장" 클릭

## 4.1 Google Sign-In (웹) 설정 및 문제해결

웹에서 Google 로그인을 사용할 때 발생하는 일반적인 문제와 설정 방법입니다.

1. 웹 OAuth 클라이언트 확인
   - Firebase Console → 프로젝트 설정(톱니) → 일반 → 웹 앱(Web app)을 확인하여 "OAuth 2.0 클라이언트 ID"가 있는지 확인합니다.
   - 또는 Google Cloud Console → APIs & Services → Credentials → OAuth 2.0 Client IDs에서 확인합니다.
   - **Authorized JavaScript origins**에 개발 중인 origin(예: `http://localhost:56819` 또는 `http://localhost:xxxx`)을 반드시 추가하세요.

2. People API 활성화 (필수)
   - People API가 비활성화되어 있으면 사용자 프로필을 가져올 수 없습니다.
   - 활성화 링크: https://console.developers.google.com/apis/api/people.googleapis.com/overview?project=227699159450
   - 활성화 후 전파되기까지 몇 분이 걸릴 수 있으므로 잠시 기다렸다가 다시 시도하세요.
   - 참고: 이 프로젝트의 Web OAuth Client ID (현재 사용 중인 값) 예: `227699159450-d98oul5ujdvuao49k0jqv7s2pmkfappi.apps.googleusercontent.com`

3. 웹 클라이언트 ID 적용
   - `web/index.html`에 meta 태그로 추가하거나, 코드에서 `GoogleSignIn(clientId: '227699159450-d98oul5ujdvuao49k0jqv7s2pmkfappi.apps.googleusercontent.com')`로 전달하세요.
   - 예: `<meta name="google-signin-client_id" content="227699159450-d98oul5ujdvuao49k0jqv7s2pmkfappi.apps.googleusercontent.com">`

4. 발생 가능한 오류 및 해결
   - `SERVICE_DISABLED` 또는 `PERMISSION_DENIED` 오류: People API 비활성화 또는 권한 문제입니다 → People API 활성화 + origins 확인
   - 클라이언트 ID 불일치: `clientId` 값과 Console의 OAuth 클라이언트가 일치하는지 확인
   - 적용 후 문제가 계속되면 콘솔 로그(전체 에러 메시지)를 확인하여 안내를 따르세요.

## 5. Cloud Firestore 활성화

## 5.1 Firestore 인덱스(Composite Index) 문제 해결

일부 쿼리(예: 날짜 범위 + 정렬, 여러 where 조건 조합)는 Firestore에서 복합 인덱스가 필요합니다. 에러 화면(또는 콘솔)에서 `failed-precondition` 또는 `create_composite` 링크가 보이면 해당 링크를 열어 인덱스를 생성하세요.

- 에러 예시: `[cloud_firestore/failed-precondition] The query requires an index. You can create it here: https://console.firebase.google.com/v1/r/project/<PROJECT_ID>/firestore/indexes/create_composite?...`
- 해결 방법:
  1. 에러에 포함된 링크를 클릭해 인덱스를 생성하세요.
  2. 생성 후 전파되기까지 약간의 시간이 필요합니다(보통 1~5분).
  3. 인덱스 생성이 번거롭거나 직접 확인이 어려우면, 앱에서 발생하는 에러 메시지(전체 로그)를 복사하여 개발자 도구 콘솔에 붙여넣으면 생성 링크를 확인할 수 있습니다.

- 권장 복합 인덱스 예시(해당 프로젝트 요구에 따라 조정):
  - `daily_plans` 컬렉션: `userId (ASC)`, `date (ASC)`, `startTime (ASC)`  — 날짜 범위 + 시간 정렬용
  - `weekly_plans` 컬렉션: `userId (ASC)`, `weekStartDate (ASC)`, `weekEndDate (ASC)`, `date (ASC)` — 특정 주 조회용
  - `monthly_plans` 목록 정렬: `userId (ASC)`, `month (DESC)`

### CLI로 인덱스 배포하기 (제가 대신 실행할 수는 없습니다 — 로컬에서 아래 커맨드를 실행하세요)

저는 직접 프로젝트에 로그인/배포할 수 없으므로, 대신 필요한 파일과 정확한 명령어를 준비해 두었습니다. 다음 단계를 따라 주세요:

1) Firebase CLI가 설치되어 있고 로그인되어 있는지 확인

```bash
# 설치 (없을 경우)
npm install -g firebase-tools

# 로그인
firebase login
```

2) 프로젝트 선택

```bash
# 프로젝트 목록 확인
firebase projects:list

# 프로젝트 선택(또는 --project 옵션으로 지정)
firebase use --add
```

3) 준비된 `firestore.indexes.json` 파일을 프로젝트 루트에 추가했습니다 (파일명: `firestore.indexes.json`). 내용은 권장 인덱스가 포함되어 있습니다.

4) 인덱스 배포

```bash
# Firestore 인덱스만 배포
firebase deploy --only firestore:indexes --project <YOUR_PROJECT_ID>
```

(참고) 실행 후 콘솔에서 인덱스 생성 상태를 확인하시고, 전파되었다면 앱을 다시 로드하세요.

---

원하시면 제가 `firestore.indexes.json` 파일을 추가해 두었으니, 지금 터미널에서 제가 안내한 명령어들을 그대로 실행해 주시면 됩니다. 실행 결과(성공/실패 로그)를 보내주시면 제가 다음 단계(필요 시 인덱스 수정 또는 추가 쿼리 변경)를 도와드리겠습니다.


1. Firebase Console에서 "Firestore Database" 클릭
2. "데이터베이스 만들기" 클릭
3. 보안 규칙 선택:
   - **테스트 모드**로 시작 (개발용)
   - 또는 **프로덕션 모드** (보안 규칙 직접 설정)
4. 위치 선택 (예: asia-northeast3 - 서울)
5. "사용 설정" 클릭

## 6. Firestore 보안 규칙 설정

Firebase Console → Firestore Database → 규칙 탭에서 다음 규칙을 설정하세요:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 사용자가 로그인되어 있는지 확인
    function isSignedIn() {
      return request.auth != null;
    }

    // 현재 사용자가 문서의 소유자인지 확인
    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }

    // 월간 계획
    match /monthly_plans/{planId} {
      allow read, write: if isSignedIn() && isOwner(resource.data.userId);
      allow create: if isSignedIn() && isOwner(request.resource.data.userId);
    }

    // 주간 계획
    match /weekly_plans/{planId} {
      allow read, write: if isSignedIn() && isOwner(resource.data.userId);
      allow create: if isSignedIn() && isOwner(request.resource.data.userId);
    }

    // 일간 계획
    match /daily_plans/{planId} {
      allow read, write: if isSignedIn() && isOwner(resource.data.userId);
      allow create: if isSignedIn() && isOwner(request.resource.data.userId);
    }
  }
}
```

## 7. 앱 실행

모든 설정이 완료되면:

```bash
flutter pub get
flutter run
```

## 문제 해결

### 오류: "Default FirebaseApp is not initialized"
- `flutterfire configure` 명령어를 실행했는지 확인
- `lib/firebase_options.dart` 파일이 생성되었는지 확인

### 오류: "MissingPluginException"
```bash
flutter clean
flutter pub get
flutter run
```

### iOS에서 실행 안 됨
```bash
cd ios
pod install
cd ..
flutter run
```

### Android에서 실행 안 됨
- `android/app/build.gradle`의 minSdkVersion이 21 이상인지 확인

## 추가 참고 자료

- [FlutterFire 공식 문서](https://firebase.flutter.dev/)
- [Firebase Console](https://console.firebase.google.com/)
- [Flutter 공식 문서](https://flutter.dev/docs)
