#!/bin/bash
# lazybee-plugin statusline (macOS/Linux)
input=$(cat)

# 필드 추출
MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')
DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
LINES_ADD=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_DEL=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# === 주간 사용 한도 (API 호출 + 60초 캐시 + 자동 토큰 갱신) ===
USAGE_CACHE="/tmp/.claude-usage-cache.json"
USAGE_CACHE_TTL=60
FIVE_HR_PCT=0; SEVEN_DAY_PCT=0
FIVE_HR_RESET=""; SEVEN_DAY_RESET=""
OAUTH_CLIENT_ID="9d1c250a-e61b-44d9-88ed-5944d1962f5e"

_get_creds() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    security find-generic-password -s "Claude Code-credentials" -a "$USER" -w 2>/dev/null \
      || security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null
  elif [ -f "$HOME/.claude/.credentials.json" ]; then
    cat "$HOME/.claude/.credentials.json" 2>/dev/null
  fi
}

_refresh_token() {
  local creds="$1"
  local refresh_token
  refresh_token=$(echo "$creds" | jq -r '.claudeAiOauth.refreshToken // empty')
  [ -z "$refresh_token" ] && return 1

  local resp
  resp=$(curl -s --max-time 5 -X POST \
    -H "Content-Type: application/json" \
    -H "User-Agent: claude-code/2.0.32" \
    -d "{\"grant_type\":\"refresh_token\",\"refresh_token\":\"$refresh_token\",\"client_id\":\"$OAUTH_CLIENT_ID\"}" \
    "https://console.anthropic.com/v1/oauth/token" 2>/dev/null) || return 1

  local new_token
  new_token=$(echo "$resp" | jq -r '.access_token // empty')
  [ -z "$new_token" ] && return 1

  local new_refresh
  new_refresh=$(echo "$resp" | jq -r '.refresh_token // empty')
  local expires_in
  expires_in=$(echo "$resp" | jq -r '.expires_in // 86400')
  local now_ms=$(( $(date +%s) * 1000 ))
  local expires_at=$(( now_ms + expires_in * 1000 ))

  # Keychain/credentials 업데이트
  local updated
  updated=$(echo "$creds" | jq --arg t "$new_token" --arg r "${new_refresh:-$refresh_token}" --argjson e "$expires_at" \
    '.claudeAiOauth.accessToken = $t | .claudeAiOauth.refreshToken = $r | .claudeAiOauth.expiresAt = $e')
  if [[ "$OSTYPE" == "darwin"* ]]; then
    security delete-generic-password -s "Claude Code-credentials" 2>/dev/null
    security add-generic-password -s "Claude Code-credentials" -a "claude-code" -w "$updated" 2>/dev/null
  elif [ -f "$HOME/.claude/.credentials.json" ]; then
    echo "$updated" > "$HOME/.claude/.credentials.json"
  fi

  echo "$new_token"
}

_fetch_usage() {
  local creds token resp expires_at now_ms

  if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
    token="$CLAUDE_CODE_OAUTH_TOKEN"
  else
    creds=$(_get_creds) || return 1
    token=$(echo "$creds" | jq -r '.claudeAiOauth.accessToken // empty')
    [ -z "$token" ] && return 1

    expires_at=$(echo "$creds" | jq -r '.claudeAiOauth.expiresAt // 0')
    now_ms=$(( $(date +%s) * 1000 ))
    if [ "$now_ms" -gt "$expires_at" ]; then
      token=$(_refresh_token "$creds") || return 1
    fi
  fi

  resp=$(curl -s --max-time 3 -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "User-Agent: claude-code/2.0.32" \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" \
    "https://api.anthropic.com/api/oauth/usage" 2>/dev/null) || return 1

  if echo "$resp" | jq -e '.error.type == "authentication_error"' >/dev/null 2>&1; then
    [ -z "$creds" ] && creds=$(_get_creds)
    [ -n "$creds" ] && token=$(_refresh_token "$creds") || return 1
    resp=$(curl -s --max-time 3 -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      -H "User-Agent: claude-code/2.0.32" \
      -H "Authorization: Bearer $token" \
      -H "anthropic-beta: oauth-2025-04-20" \
      "https://api.anthropic.com/api/oauth/usage" 2>/dev/null) || return 1
  fi

  echo "$resp" | jq -e '.five_hour' >/dev/null 2>&1 || return 1
  echo "$resp" > "$USAGE_CACHE"
}

if [ -f "$USAGE_CACHE" ]; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    cache_age=$(( $(date +%s) - $(stat -f %m "$USAGE_CACHE" 2>/dev/null || echo 0) ))
  else
    cache_age=$(( $(date +%s) - $(stat -c %Y "$USAGE_CACHE" 2>/dev/null || echo 0) ))
  fi
  [ "$cache_age" -gt "$USAGE_CACHE_TTL" ] && _fetch_usage &
else
  _fetch_usage &
fi

# 리셋 시간 계산 함수 (ISO 8601 → "Xh Ym")
_time_until() {
  local reset_at="$1"
  [ -z "$reset_at" ] || [ "$reset_at" = "null" ] && return
  local reset_epoch now_epoch diff_s hours mins
  if [[ "$OSTYPE" == "darwin"* ]]; then
    reset_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${reset_at%%.*}" "+%s" 2>/dev/null) || return
  else
    reset_epoch=$(date -d "$reset_at" "+%s" 2>/dev/null) || return
  fi
  now_epoch=$(date +%s)
  diff_s=$((reset_epoch - now_epoch))
  [ "$diff_s" -le 0 ] && echo "0m" && return
  hours=$((diff_s / 3600))
  mins=$(( (diff_s % 3600) / 60 ))
  if [ "$hours" -gt 0 ]; then
    echo "${hours}h${mins}m"
  else
    echo "${mins}m"
  fi
}

if [ -f "$USAGE_CACHE" ]; then
  FIVE_HR_PCT=$(jq -r '.five_hour.utilization // 0' "$USAGE_CACHE" | cut -d. -f1)
  SEVEN_DAY_PCT=$(jq -r '.seven_day.utilization // 0' "$USAGE_CACHE" | cut -d. -f1)
  FIVE_HR_RESET=$(_time_until "$(jq -r '.five_hour.resets_at // empty' "$USAGE_CACHE")")
  SEVEN_DAY_RESET=$(_time_until "$(jq -r '.seven_day.resets_at // empty' "$USAGE_CACHE")")
fi

# 색상
CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'
MAGENTA='\033[35m'; WHITE='\033[1;37m'; DIM='\033[2m'; RESET='\033[0m'

# 프로그레스 바 생성 함수 (인자: PCT, WIDTH)
_bar() {
  local pct=$1 width=${2:-12} color
  if [ "$pct" -ge 80 ]; then color="$RED"
  elif [ "$pct" -ge 50 ]; then color="$YELLOW"
  else color="$GREEN"; fi
  local filled=$((pct * width / 100))
  local empty=$((width - filled))
  local bar=""
  [ "$filled" -gt 0 ] && bar=$(printf "%${filled}s" | tr ' ' '█')
  [ "$empty" -gt 0 ] && bar="${bar}$(printf "%${empty}s" | tr ' ' '░')"
  printf '%b' "${color}${bar}${RESET}"
}

# 시간 포맷
MINS=$((DURATION_MS / 60000))
SECS=$(((DURATION_MS % 60000) / 1000))

# 비용 색상
COST_FMT=$(printf '%.2f' "$COST")
COST_INT=$(printf '%.0f' "$COST")
if [ "$COST_INT" -ge 10 ]; then COST_COLOR="$RED"
elif [ "$COST_INT" -ge 5 ]; then COST_COLOR="$YELLOW"
else COST_COLOR="$GREEN"; fi

# Git 브랜치
BRANCH=""
[ -n "$DIR" ] && BRANCH=$(git -C "$DIR" symbolic-ref --short HEAD 2>/dev/null)

# 한 줄 출력 조립
OUT="${WHITE}${MODEL}${RESET}"
[ -n "$DIR" ] && OUT="${OUT} ${DIM}|${RESET} ${CYAN}${DIR##*/}${RESET}"
[ -n "$BRANCH" ] && OUT="${OUT} ${MAGENTA}(${BRANCH})${RESET}"

# ctx:[bar]PCT%
OUT="${OUT} ${DIM}|${RESET} ctx:[$(_bar "$PCT" 12)]${PCT}%"

# 5h:[bar]PCT%(reset) wk:[bar]PCT%(reset)
if [ "$FIVE_HR_PCT" -gt 0 ] || [ "$SEVEN_DAY_PCT" -gt 0 ]; then
  FIVE_RESET_LABEL=""
  [ -n "$FIVE_HR_RESET" ] && FIVE_RESET_LABEL="(${FIVE_HR_RESET})"
  SEVEN_RESET_LABEL=""
  [ -n "$SEVEN_DAY_RESET" ] && SEVEN_RESET_LABEL="(${SEVEN_DAY_RESET})"

  OUT="${OUT} ${DIM}|${RESET} 5h:[$(_bar "$FIVE_HR_PCT" 12)]${FIVE_HR_PCT}%${FIVE_RESET_LABEL}"
  OUT="${OUT} wk:[$(_bar "$SEVEN_DAY_PCT" 12)]${SEVEN_DAY_PCT}%${SEVEN_RESET_LABEL}"
fi

# $cost
OUT="${OUT} ${DIM}|${RESET} ${COST_COLOR}\$${COST_FMT}${RESET}"

# +lines/-lines
OUT="${OUT} ${DIM}|${RESET} ${GREEN}+${LINES_ADD}${RESET}/${RED}-${LINES_DEL}${RESET}"

# duration
OUT="${OUT} ${DIM}|${RESET} ${DIM}${MINS}m${SECS}s${RESET}"

printf '%b' "$OUT"
