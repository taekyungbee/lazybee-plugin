---
description: "lazybee-plugin statusline 자동 설치. ~/.claude/settings.json에 statusline 설정을 자동 등록합니다. macOS, Linux, Windows 크로스 플랫폼 지원."
triggers:
  - "statusline 설정"
  - "statusline 설치"
  - "상태바 설정"
  - "상태바 설치"
  - "setup statusline"
  - "install statusline"
---

# Statusline 자동 설치

lazybee-plugin의 강화된 statusline을 `~/.claude/settings.json`에 자동 등록합니다.

## 표시 정보

```
 Opus 4.6  project  main | ████████░░░░ 40% 85k(67%↑) | 5h:12% 7d:35% | $0.52 | 1m 20s
```

- 모델명, 프로젝트명, Git 브랜치
- 컨텍스트 프로그레스 바 + 사용률 + 토큰(캐시 히트율)
- 컨텍스트 80%+ `COMPRESS?`, 90%+ `CRITICAL` 경고
- 5시간/7일 API 사용 한도 (OAuth API, 60초 캐시)
- 세션 비용, 경과 시간

## 설치 절차

### Step 1: OS 확인

Bash로 OS를 확인합니다:

```bash
uname -s
```

### Step 2: 스크립트 복사

**macOS / Linux:**
```bash
cp "${CLAUDE_PLUGIN_ROOT}/scripts/statusline-command.sh" ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

**Windows (PowerShell):**
```bash
powershell -Command "Copy-Item '${CLAUDE_PLUGIN_ROOT}\scripts\statusline-command.ps1' '$env:USERPROFILE\.claude\statusline-command.ps1'"
```

### Step 3: settings.json 업데이트

`~/.claude/settings.json` 파일을 Read로 읽은 뒤, `statusLine` 항목을 수정합니다.

**macOS / Linux 설정값:**
```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

**Windows 설정값:**
```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell.exe -NoProfile -ExecutionPolicy Bypass -File %USERPROFILE%\\.claude\\statusline-command.ps1"
  }
}
```

기존 settings.json의 다른 항목은 유지하고, `statusLine` 키만 추가/수정합니다.

### Step 4: 완료 안내

설치 완료 후 사용자에게 안내합니다:

```
statusline 설치가 완료되었습니다.
Claude Code를 재시작하면 새 상태바가 적용됩니다.
```

## 의존성

- `jq` (JSON 파싱)
- `curl` (API 호출)
- `git` (브랜치 표시)
- macOS: `security` (Keychain 접근)
- Windows: PowerShell 5.1+

## 제거

`~/.claude/settings.json`에서 `statusLine` 항목을 삭제하면 기본 상태바로 복원됩니다.
