# 🚀 빠른 시작 - 개선된 AI 챗봇 테스트

## 즉시 테스트하기

### 1️⃣ 앱 실행
```bash
cd /Users/choiminyoung/flutter_application_studyplanner
flutter run
```

### 2️⃣ 콘솔 로그 보기
```bash
# 다른 터미널에서
flutter logs
```

### 3️⃣ 테스트 메시지 입력

**시나리오 1: 기본 일정 추가**
```
입력: "내일 오후 3시에 수학 공부"

예상 결과:
✅ 메시지: ✅ "수학" 일정이 1월 21일 오후 3시에 추가되었습니다!
✅ Firestore: 데이터 저장됨
✅ 콘솔: DEBUG 로그 출력됨
```

**시나리오 2: 다양한 표현**
```
입력: "모레 영어 과제 해야해"
✅ 인식됨 (이전: 안 됨)

입력: "다음주 월요일 물리 시험 공부"
✅ 인식됨 (이전: 안 됨)

입력: "내일 아침 9시 국어"
✅ 인식됨 (이전: 안 됨)
```

**시나리오 3: 일정 조회**
```
입력: "내일 뭐 해야하지?"
✅ 응답: 📅 1월 21일 일정:
         • 오후 3시 - 수학
         • 오전 9시 - 국어
```

---

## 🔍 콘솔 로그 해석

### 성공한 경우
```
🔍 DEBUG: parseUserIntent() - message: "내일 오후 3시에 수학 공부"
✅ DEBUG: Detected create_schedule with confidence 0.92
🎯 DEBUG: intent = {action: create_schedule, confidence: 0.92, ...}
🚀 DEBUG: Executing action: create_schedule
📝 DEBUG: subject = 수학, timeStr = 내일 오후 3시에 수학 공부
📅 DEBUG: Final scheduleDate = 2026-01-21 15:00:00.000
✅ DEBUG: Saved to Firestore with ID: aBcD123456
```

### 실패한 경우
```
❌ DEBUG: Error creating schedule: PlatformException(...)
❌ DEBUG: Stack trace: ...
```

### 확인해야 할 것
```
✅ userId가 비어있지 않은가?
   🔍 DEBUG: userId = xYz789... (✅ 있음)
   
✅ confidence가 0.6 이상인가?
   📊 DEBUG: ... confidence = 0.92 (✅ 높음)
   
✅ scheduleDate가 올바른가?
   📅 DEBUG: Final scheduleDate = 2026-01-21 15:00:00 (✅ 맞음)
```

---

## 📱 앱 화면에서 확인

### 메인 화면 (오늘 화면)
```
일정을 추가하면 여기에 표시되어야 함

✅ "내일 오후 3시에 수학 공부" 입력 후
  → 메인 화면 "내일" 섹션에 "수학" 표시됨
```

### 캘린더 화면
```
Firestore에 저장된 일정이 표시됨

✅ 1월 21일(내일)을 누르면
  → "수학 15:00" 표시됨
```

---

## ✅ 체크리스트

- [ ] 앱 실행 (`flutter run`)
- [ ] 콘솔 열기 (`flutter logs`)
- [ ] "내일 오후 3시에 수학 공부" 입력
- [ ] 콘솔에서 ✅ DEBUG 로그 확인
- [ ] 앱에서 일정이 표시되는지 확인
- [ ] Firebase Console에서 Firestore 데이터 확인

---

## 🎯 성공 기준

### ✅ 이 모든 것이 작동하면 성공!

1. **콘솔 로그**
   - ✅ "✅ DEBUG: Saved to Firestore" 메시지 표시

2. **앱 화면**
   - ✅ AI 응답: "✅ '수학' 일정이 1월 21일 오후 3시에 추가되었습니다!"
   - ✅ 메인 화면의 내일 섹션에 "수학" 표시

3. **Firebase**
   - ✅ Firestore에 새 document 생성됨
   - ✅ startTime: 2026-01-21 15:00:00
   - ✅ title: "수학"

---

## 🐛 문제 해결

### 문제 1: "음... 잘 이해하지 못했어요" 응답
```
원인: confidence가 0.6 이하
해결: 콘솔의 confidence 값 확인 후 패턴 추가
```

### 문제 2: 일정이 저장되지 않음
```
원인: Firestore 권한 문제 또는 userId 없음
해결: 
  1. Firebase Console에서 Rules 확인
  2. 콘솔의 userId 확인
```

### 문제 3: 시간이 잘못 저장됨
```
원인: 시간 파싱 로직 문제
해결: 콘솔의 scheduleDate 확인
     "오후 3시" → 2026-01-21 15:00:00 (맞음)
     "3시" → 2026-01-21 03:00:00 (잘못됨)
```

---

## 💾 Firebase에서 직접 확인

### Firebase Console
1. https://console.firebase.google.com 열기
2. Study Planner 프로젝트 선택
3. Firestore Database 클릭
4. users → [userID] → schedules 폴더 확인
5. 새로 추가된 document 확인

```
예상되는 데이터:
{
  category: "공부"
  createdAt: 2026-01-20 ...
  description: "AI 챗봇으로 생성된 일정"
  endTime: 2026-01-21 16:00:00
  isCompleted: false
  startTime: 2026-01-21 15:00:00
  title: "수학"
}
```

---

## 🎬 시나리오별 테스트

### Scenario A: 완전한 테스트 플로우
```
1. 앱 실행
2. "내일 오후 3시에 수학 공부" 입력
3. 콘솔에서 SUCCESS 로그 확인
4. 앱에서 응답 확인
5. 메인 화면에서 일정 표시 확인
6. Firebase Console에서 Firestore 데이터 확인
```

### Scenario B: 다양한 표현 테스트
```
"내일 3시에 수학해야해" ✅
"모레 영어 과제" ✅
"다음주 월요일 물리" ✅
"내일 아침 9시 국어" ✅
"오후 2시 화학" ✅
```

### Scenario C: 일정 조회 테스트
```
"오늘 일정 뭐야?" ✅
"내일 뭐 해야하지?" ✅
"이번 주 일정 보여줘" ✅
```

---

## 📊 개선 전후 비교

### Before
```
입력: "내일 오후 3시에 수학 공부"
응답: "음... 잘 이해하지 못했어요"
결과: ❌ 아무것도 없음
```

### After
```
입력: "내일 오후 3시에 수학 공부"
응답: "✅ 수학 일정이 1월 21일 오후 3시에 추가되었습니다!"
콘솔: ✅ DEBUG: Saved to Firestore with ID: aBcD123456
결과: ✅ Firestore 저장 + 화면 표시
```

---

## 🚀 빠른 디버깅 팁

### 1. 콘솔에서 특정 메시지 찾기
```bash
flutter logs | grep "DEBUG"
```

### 2. userId 확인
```bash
flutter logs | grep "userId"
# 출력: 🔍 DEBUG: userId = xYz789abc123...
```

### 3. 시간 파싱 확인
```bash
flutter logs | grep "scheduleDate"
# 출력: 📅 DEBUG: Final scheduleDate = 2026-01-21 15:00:00.000
```

### 4. Intent confidence 확인
```bash
flutter logs | grep "confidence"
# 출력: 📊 DEBUG: ... confidence = 0.92
```

---

## ✨ 예상되는 결과

### 콘솔 출력
```
✅ ✅ ✅ ✅ ✅ ✅ (모두 성공)
```

### 앱 응답
```
✅ 수학 일정이 1월 21일 오후 3시에 추가되었습니다!
```

### 메인 화면
```
📅 내일
  ├─ 수학 - 15:00
  └─ (다른 일정들...)
```

### Firestore
```
Document: auto_generated_id
├─ title: "수학"
├─ startTime: 2026-01-21 15:00:00
├─ endTime: 2026-01-21 16:00:00
└─ category: "공부"
```

---

**이제 테스트를 시작하세요! 🎉**

문제가 발생하면 콘솔의 DEBUG 로그를 확인하세요.
