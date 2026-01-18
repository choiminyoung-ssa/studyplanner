# 스터디 플래너 MCP 서버

ChatGPT Desktop에서 스터디 플래너 앱의 일정을 관리할 수 있게 해주는 MCP 서버입니다.

## 기능

- ✅ 일일 계획 추가/조회
- ✅ 주간 계획 추가/조회
- ✅ 월간 목표 추가/조회
- ✅ 계획 완료 처리
- ✅ 계획 삭제

## 설정 방법

### 1. Firebase 서비스 계정 키 다운로드

1. [Firebase Console](https://console.firebase.google.com/) 접속
2. 프로젝트 선택
3. ⚙️ (설정) → 프로젝트 설정 → 서비스 계정
4. "새 비공개 키 생성" 버튼 클릭
5. 다운로드한 JSON 파일을 `mcp-server/firebase-service-account.json`으로 저장

### 2. 빌드

```bash
cd mcp-server
npm run build
```

### 3. ChatGPT Desktop에 연결

#### macOS/Linux:

`~/.config/claude/claude_desktop_config.json` 파일 생성:

```json
{
  "mcpServers": {
    "studyplanner": {
      "command": "node",
      "args": [
        "/Users/choiminyoung/flutter_application_studyplanner/mcp-server/dist/index.js"
      ]
    }
  }
}
```

#### Windows:

`%APPDATA%\Claude\claude_desktop_config.json` 파일 생성:

```json
{
  "mcpServers": {
    "studyplanner": {
      "command": "node",
      "args": [
        "C:\\Users\\YourUsername\\flutter_application_studyplanner\\mcp-server\\dist\\index.js"
      ]
    }
  }
}
```

### 4. ChatGPT Desktop 재시작

설정 후 ChatGPT Desktop을 완전히 종료하고 다시 시작하세요.

## 사용 예시

ChatGPT와 대화하면서 일정을 관리할 수 있습니다:

### 일정 추가
```
오늘 수학 문제집 50페이지부터 70페이지까지 풀기 계획을 추가해줘
```

### 주간 계획 추가
```
이번 주 금요일에 영어 단어 100개 외우기 계획을 추가해줘
```

### 월간 목표 추가
```
이번 달 목표로 토익 800점 달성을 추가해줘. 우선순위는 높음으로 설정하고, 마감일은 1월 31일로 해줘
```

### 일정 조회
```
오늘 일정을 보여줘
```

```
이번 주 계획을 보여줘
```

```
이번 달 목표를 보여줘
```

### 일정 완료 처리
```
ID가 abc123인 일일 계획을 완료 처리해줘
```

### 일정 삭제
```
ID가 xyz789인 주간 계획을 삭제해줘
```

## 제공되는 도구

1. `add_daily_plan` - 일일 계획 추가
2. `add_weekly_plan` - 주간 계획 추가
3. `add_monthly_goal` - 월간 목표 추가
4. `get_daily_plans` - 일일 계획 조회
5. `get_weekly_plans` - 주간 계획 조회
6. `get_monthly_goals` - 월간 목표 조회
7. `complete_plan` - 계획 완료 처리
8. `delete_plan` - 계획 삭제

## 참고사항

- 사용자 ID는 Firebase Authentication의 사용자 ID를 사용합니다
- 날짜는 `YYYY-MM-DD` 형식으로 입력합니다
- 월은 `YYYY-MM` 형식으로 입력합니다
- 우선순위는 1(높음), 2(중간), 3(낮음)으로 설정합니다
