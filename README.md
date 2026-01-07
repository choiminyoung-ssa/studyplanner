# 공부 일정 관리 앱 (Study Planner)

Flutter와 Firebase를 사용한 풀스택 공부 일정 관리 애플리케이션입니다.

## 주요 기능

### ✅ 인증 (Authentication)
- 이메일/비밀번호 기반 회원가입 및 로그인
- Firebase Authentication을 통한 안전한 비밀번호 해시 처리
- 로그아웃 기능
- 사용자별 데이터 격리 (다른 사용자 데이터 접근 불가)

### 📅 월간 계획 (Monthly Plans)
- 월별 목표 생성, 수정, 삭제
- 과목/태그, 우선순위 설정
- 완료 상태 추적
- 주간 계획과 연결 가능

### 📆 주간 계획 (Weekly Plans)
- **1주 캘린더 뷰 (월~일)**
- 날짜별 계획 배치 및 시각화
- 월간 목표와 연결
- 일간 타임블록 생성 가능

### ⏰ 일간 계획 (Daily Plans)
- **타임라인 형식의 시간 블록**
- 시작/종료 시간 설정
- 시간대별 일정 표시
- 주간 계획과 연결

### 🏠 오늘 대시보드 (Today Dashboard)
- 오늘의 일정 한눈에 보기
- 이번 주 계획 요약
- 이번 달 목표 진행률 표시
- 완료율 시각화

## 📱 화면 구성

1. **로그인/회원가입**: 사용자 인증
2. **오늘**: 오늘의 모든 계획 대시보드
3. **월간**: 월별 목표 관리
4. **주간**: 1주 캘린더 (월~일)
5. **일간**: 타임라인 기반 시간 관리

## 🔧 기술 스택

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase
  - Firebase Authentication (사용자 인증)
  - Cloud Firestore (데이터베이스)
- **상태 관리**: Provider
- **날짜 처리**: intl
- **UI 컴포넌트**: Material Design 3

## 🚀 시작하기

### 필수 요구사항

- Flutter SDK (3.10.4 이상)
- Dart SDK (3.10.4 이상)
- Firebase 계정
- Node.js (Firebase CLI 설치용)

### 설치 및 실행

1. **저장소 클론 또는 프로젝트 다운로드**

2. **의존성 설치**
```bash
flutter pub get
```

3. **Firebase 설정**

   자세한 설정 방법은 [FIREBASE_SETUP.md](FIREBASE_SETUP.md)를 참조하세요.

   간단 요약:
   ```bash
   # Firebase CLI 설치
   npm install -g firebase-tools
   firebase login

   # FlutterFire CLI 설치 및 설정
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

4. **앱 실행**
```bash
flutter run
```

## 📂 프로젝트 구조

```
lib/
├── main.dart                 # 앱 진입점
├── firebase_options.dart     # Firebase 설정 (자동 생성)
├── models/                   # 데이터 모델
│   ├── monthly_plan.dart
│   ├── weekly_plan.dart
│   └── daily_plan.dart
├── services/                 # 비즈니스 로직
│   ├── auth_service.dart
│   └── firestore_service.dart
├── providers/                # 상태 관리
│   └── auth_provider.dart
├── screens/                  # UI 화면
│   ├── auth/                 # 인증 화면
│   ├── home/                 # 메인 및 대시보드
│   ├── monthly/              # 월간 계획
│   ├── weekly/               # 주간 계획
│   └── daily/                # 일간 계획
├── widgets/                  # 재사용 위젯
└── utils/                    # 유틸리티 함수
    └── date_utils.dart
```

## 🗄️ 데이터 모델

### Monthly Plan (월간 계획)
- 월별 목표
- 연결된 주간 계획 ID 목록
- 과목, 태그, 우선순위, 완료 상태

### Weekly Plan (주간 계획)
- 주간 범위 (시작일-종료일)
- 특정 날짜에 배치
- 부모 월간 계획 ID (연결)
- 연결된 일간 타임블록 ID 목록

### Daily Plan (일간 계획)
- 날짜 및 시간 (시작/종료)
- 타임블록 형식
- 부모 주간 계획 ID (연결)

## 🔐 보안

- Firebase Authentication을 통한 안전한 비밀번호 관리
- Firestore 보안 규칙을 통한 데이터 접근 제어
- userId 기반 권한 검증
- 각 사용자는 자신의 데이터만 조회/수정 가능

## 📝 사용 방법

1. **회원가입/로그인**
   - 이메일과 비밀번호로 계정 생성
   - 로그인하여 앱 시작

2. **월간 목표 설정**
   - "월간" 탭에서 이번 달 목표 추가
   - 과목, 우선순위 설정

3. **주간 계획 작성**
   - "주간" 탭에서 1주 캘린더 확인
   - 원하는 날짜에 계획 추가
   - 월간 목표와 연결 가능

4. **일간 타임블록 생성**
   - "일간" 탭에서 시간대별 일정 추가
   - 시작/종료 시간 설정
   - 주간 계획과 연결 가능

5. **진행 상황 확인**
   - "오늘" 탭에서 전체 진행률 확인
   - 완료된 항목 체크
   - 이번 달 목표 달성률 확인

## 🛠️ 개발 중 주의사항

- Firebase 설정이 완료되어야 앱이 정상 작동합니다
- `lib/firebase_options.dart` 파일은 절대 Git에 커밋하지 마세요 (이미 .gitignore에 포함)
- Firestore 보안 규칙을 반드시 설정하세요

## 📄 라이선스

이 프로젝트는 개인 학습 및 사용 목적으로 제작되었습니다.

## 🤝 기여

버그 리포트나 기능 제안은 이슈로 등록해주세요.

## 📧 문의

질문이나 도움이 필요하시면 이슈를 생성해주세요.
