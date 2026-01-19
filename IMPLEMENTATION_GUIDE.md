# 개선된 AI 어시스턴트 구현 가이드

## 📋 개요

기존의 단순한 패턴 매칭 챗봇을 **실제 기능하는 AI 어시스턴트**로 업그레이드합니다.

### 주요 개선사항:
✅ 자연어 처리(NLP) 기반 유연한 대화
✅ 데이터베이스 연동 (일정 실제 저장)
✅ 더 사람같은 응답
✅ 다양한 표현 인식

---

## 🛠️ 설치 및 설정

### 1단계: 의존성 설치

```bash
cd your_flutter_project
flutter pub add sqflite path intl uuid
```

또는 `pubspec.yaml`에 수동으로 추가:

```yaml
dependencies:
  sqflite: ^2.3.0
  path: ^1.8.3
  intl: ^0.19.0
  uuid: ^4.0.0
```

### 2단계: 파일 적용

제공된 `ai_assistant_improved.dart` 파일을 프로젝트에 복사:

```
lib/
  └── ai_assistant/
      └── ai_assistant_improved.dart
```

### 3단계: main.dart에서 사용

```dart
import 'package:flutter/material.dart';
import 'ai_assistant/ai_assistant_improved.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Study Planner',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ImprovedAIAssistantUI(),
    );
  }
}
```

---

## 🧠 자연어 처리 엔진 (NLPEngine)

### 지원하는 표현들

#### 시간 표현:
- "오늘", "내일", "모레"
- "이번주", "다음주"
- "1시간 후", "2시간 후"
- "오후 3시", "아침 9시"

#### 의도 인식:
| 사용자 표현 | 인식되는 의도 | 동작 |
|-----------|-----------|-----|
| "일정 추가해줘" | add_schedule | 새 일정 생성 |
| "언제 뭐해?" | view_schedule | 일정 조회 |
| "삭제해줘" | delete_schedule | 일정 삭제 |
| "안녕" | general | 일반 응답 |

#### 카테고리 자동 분류:
- **study**: 공부, 수학, 영어, 과학 등
- **exercise**: 운동, 스포츠, 산책 등
- **meeting**: 만남, 약속, 회의 등
- **other**: 기타

### 사용 예시:

```dart
// 시간 파싱
final timeInfo = NLPEngine.parseTimeExpression("오늘 3시");
// 결과: {date: DateTime(...), hour: 3, minute: 0}

// 의도 인식
final intent = NLPEngine.recognizeIntent("일정 추가해줘");
// 결과: "add_schedule"

// 정보 추출
final info = NLPEngine.extractScheduleInfo("내일 오후 2시에 영어공부");
// 결과: {title: "영어공부", category: "study"}
```

---

## 💾 데이터베이스 (ScheduleDatabase)

### 로컬 저장소 구조:

```sql
CREATE TABLE schedules (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  startTime TEXT NOT NULL,
  endTime TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL,
  isAllDay INTEGER DEFAULT 0,
  createdAt TEXT
)
```

### 주요 메서드:

```dart
// 초기화
final db = ScheduleDatabase();

// 일정 추가 (자동으로 데이터베이스에 저장)
final schedule = ScheduleItem(
  id: DateTime.now().millisecondsSinceEpoch.toString(),
  title: "수학공부",
  startTime: DateTime(2026, 1, 21, 15, 0),
  endTime: DateTime(2026, 1, 21, 16, 0),
  category: "study",
);
await db.insertSchedule(schedule);

// 전체 일정 조회
final allSchedules = await db.getAllSchedules();

// 특정 날짜 일정 조회
final todaySchedules = await db.getSchedulesByDate(DateTime.now());

// 일정 삭제
await db.deleteSchedule(scheduleId);
```

---

## 🤖 AI 어시스턴트 엔진 (AIAssistant)

### 대화 흐름:

```
사용자 입력
    ↓
메시지 저장
    ↓
의도 인식 (Intent Detection)
    ↓
정보 추출 (Information Extraction)
    ↓
데이터베이스 작업 (INSERT/SELECT/DELETE)
    ↓
응답 생성 (Response Generation)
    ↓
응답 저장 및 전송
```

### 각 의도별 처리:

#### 1. 일정 추가 (add_schedule)

```
입력: "내일 오후 2시에 영어공부 해야 해"

처리:
- 제목 추출: "영어공부"
- 날짜 추출: 내일 (2026-01-21)
- 시간 추출: 14:00 (오후 2시)
- 카테고리: "study"
- 데이터베이스에 저장
- 확인 응답 반환

응답: "✅ 일정이 추가되었습니다!
📝 제목: 영어공부
📅 날짜: 1월 21일 화요일
⏰ 시간: 14:00
✨ 일정 알림을 받으실 수 있습니다."
```

#### 2. 일정 조회 (view_schedule)

```
입력: "내일 뭐해?"

처리:
- 날짜 추출: 내일
- 데이터베이스 쿼리
- 해당 날짜의 모든 일정 반환

응답: "1월 21일 화요일의 일정:
• [14:00] 영어공부
• [18:30] 운동
• [20:00] 독서"
```

#### 3. 일반 대화 (general)

```
입력: "안녕하세요"

처리:
- 미리 정의된 응답 중 임의로 선택
- 더 자연스러운 대화 제공

응답: "좋은 질문입니다! 혹시 일정 관리와 관련해서 도움이 필요하신가요?"
```

---

## 📱 UI 컴포넌트

### ImprovedAIAssistantUI

메시지 입력/표시 위젯

**주요 기능:**
- 실시간 메시지 표시
- 사용자/봇 메시지 구분 (다른 색상)
- 자동 스크롤
- 로딩 상태 표시

### 커스터마이징 방법:

```dart
// 1. 테마 변경
AppBar(
  backgroundColor: Colors.purple.shade700,  // 색상 변경
  elevation: 0,
)

// 2. 메시지 스타일 변경
Text(
  message.content,
  style: TextStyle(
    color: message.isUser ? Colors.white : Colors.black87,
    fontSize: 16,  // 크기 조정
    fontWeight: FontWeight.w500,
  ),
)

// 3. 입력창 커스터마이징
TextField(
  decoration: InputDecoration(
    hintText: '원하는 텍스트...',
    prefixIcon: Icon(Icons.chat),  // 아이콘 추가
    suffixIcon: Icon(Icons.mic),   // 음성 입력 등
  ),
)
```

---

## 🔧 고급 확장 기능

### 1. 정규식 패턴 추가

```dart
// NLPEngine.parseTimeExpression()에 추가:
RegExp nextWeekRegex = RegExp(r'다음\s*주');
if (nextWeekRegex.hasMatch(text)) {
  return {
    'date': now.add(Duration(days: 7)),
    'matched': '다음주',
  };
}
```

### 2. 음성 인식 통합

```dart
import 'package:speech_to_text/speech_to_text.dart' as stt;

class AIAssistant {
  late stt.SpeechToText _speechToText;

  void initSpeech() {
    _speechToText.initialize(
      onError: (error) => print('Error: $error'),
      onStatus: (status) => print('Status: $status'),
    );
  }

  Future<void> startListening() async {
    await _speechToText.listen(
      onResult: (result) {
        if (result.hasResult) {
          processUserMessage(result.recognizedWords);
        }
      },
    );
  }
}
```

### 3. 알림 기능

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void scheduleNotification(ScheduleItem schedule) {
  final flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  flutterLocalNotificationsPlugin.zonedSchedule(
    0,
    schedule.title,
    '이제 시작합니다!',
    tz.TZDateTime.from(schedule.startTime, tz.local),
    const NotificationDetails(
      android: AndroidNotificationDetails('channel_id', 'channel_name'),
    ),
    androidAllowWhileIdle: true,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
}
```

### 4. 더 정확한 시간 파싱

```dart
// 추가 패턴들
final advancedTimePatterns = {
  '아침 9시': () => DateTime.now().copyWith(hour: 9),
  '오후 3시': () => DateTime.now().copyWith(hour: 15),
  '저녁 7시': () => DateTime.now().copyWith(hour: 19),
  '밤 11시': () => DateTime.now().copyWith(hour: 23),
  '자정': () => DateTime.now().add(Duration(days: 1)).copyWith(hour: 0),
};
```

---

## 🧪 테스트 방법

### 단위 테스트 예시:

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('시간 표현 파싱 테스트', () {
    final result = NLPEngine.parseTimeExpression('오늘 3시');
    expect(result, isNotNull);
    expect(result!['hour'], equals(3));
  });

  test('의도 인식 테스트', () {
    final intent = NLPEngine.recognizeIntent('일정 추가해줘');
    expect(intent, equals('add_schedule'));
  });

  test('정보 추출 테스트', () {
    final info = NLPEngine.extractScheduleInfo('내일 영어공부');
    expect(info['title'], contains('영어'));
    expect(info['category'], equals('study'));
  });
}
```

---

## 📊 성능 최적화

### 1. 데이터베이스 쿼리 최적화

```dart
// ❌ 비효율적: 모든 일정 로드
final allSchedules = await db.getAllSchedules();

// ✅ 효율적: 특정 날짜만 로드
final todaySchedules = await db.getSchedulesByDate(DateTime.now());
```

### 2. 대화 캐싱

```dart
class AIAssistant {
  final Map<String, String> _responseCache = {};

  Future<String> processUserMessage(String userMessage) async {
    if (_responseCache.containsKey(userMessage)) {
      return _responseCache[userMessage]!;
    }

    final response = await _generateResponse(userMessage);
    _responseCache[userMessage] = response;
    return response;
  }
}
```

### 3. 메시지 페이지네이션

```dart
// 최근 50개 메시지만 메모리에 유지
if (_messages.length > 50) {
  _messages = _messages.sublist(_messages.length - 50);
}
```

---

## 🚀 배포 체크리스트

- [ ] 의존성 설치 완료
- [ ] 데이터베이스 초기화 테스트
- [ ] 기본 대화 테스트 (5개 이상 시나리오)
- [ ] 일정 추가 기능 테스트
- [ ] 일정 조회 기능 테스트
- [ ] UI 반응성 테스트
- [ ] 오류 처리 테스트
- [ ] 한국어 날짜 포맷 검증

---

## ❓ 자주 묻는 질문 (FAQ)

**Q: 데이터가 실제로 저장되나요?**
A: 네! `sqflite`를 사용하여 로컬 SQLite 데이터베이스에 저장됩니다. 앱을 종료해도 데이터가 유지됩니다.

**Q: 클라우드 동기화는 가능한가요?**
A: Firebase Realtime Database나 Google Cloud Storage를 추가하여 동기화 가능합니다.

**Q: 더 많은 표현을 추가할 수 있나요?**
A: 물론입니다! `NLPEngine.parseTimeExpression()`과 정규식을 수정하면 됩니다.

**Q: AI 응답이 더 똑똑해질 수 있나요?**
A: 더 정교한 NLP를 위해 `google_ml_kit` 패키지나 외부 API를 사용할 수 있습니다.

---

## 📞 문제 해결

### 데이터베이스 오류
```dart
// 데이터베이스 초기화 재설정
await deleteDatabase(join(await getDatabasesPath(), 'schedules.db'));
```

### UI 응답 지연
```dart
// 비동기 작업을 별도 스레드에서 처리
Future.microtask(() async {
  await _assistant.processUserMessage(userMessage);
});
```

---

**이제 훨씬 더 똑똑하고 기능이 풍부한 AI 어시스턴트를 사용할 수 있습니다! 🎉**
