#!/bin/bash
# SessionStart 훅: statusline 자동 설치
# 스크립트가 없으면 복사, settings.json에 statusLine 설정 없으면 추가

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")/..}"
SRC="${PLUGIN_ROOT}/scripts/statusline-command.sh"
DST="$HOME/.claude/statusline-command.sh"
SETTINGS="$HOME/.claude/settings.json"

# 스크립트 복사 (없거나 플러그인 버전이 더 새로우면)
if [ -f "$SRC" ]; then
  if [ ! -f "$DST" ] || [ "$SRC" -nt "$DST" ]; then
    cp "$SRC" "$DST"
    chmod +x "$DST"
  fi
fi

# settings.json에 statusLine 설정 추가
if [ -f "$SETTINGS" ]; then
  if ! jq -e '.statusLine' "$SETTINGS" >/dev/null 2>&1; then
    jq '. + {"statusLine": {"command": "bash ~/.claude/statusline-command.sh", "refreshInterval": 5}}' "$SETTINGS" > "${SETTINGS}.tmp" \
      && mv "${SETTINGS}.tmp" "$SETTINGS"
  fi
else
  cat > "$SETTINGS" <<'EOJSON'
{
  "statusLine": {
    "command": "bash ~/.claude/statusline-command.sh",
    "refreshInterval": 5
  }
}
EOJSON
fi
