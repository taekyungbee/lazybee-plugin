#!/bin/bash
# lazybee-plugin statusline (macOS/Linux)
input=$(cat)

# 필드 추출
MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')
DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
INPUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
CACHE_READ=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
CACHE_CREATE=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')

# === 주간 사용 한도 (API 호출 + 60초 캐시 + 자동 토큰 갱신) ===
USAGE_CACHE="/tmp/.claude-usage-cache.json"
USAGE_CACHE_TTL=60
FIVE_HR_PCT=0; SEVEN_DAY_PCT=0
OAUTH_CLIENT_ID="9d1c250a-e61b-44d9-88ed-5944d1962f5e"

_get_creds() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null
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

  creds=$(_get_creds) || return 1
  token=$(echo "$creds" | jq -r '.claudeAiOauth.accessToken // empty')
  [ -z "$token" ] && return 1

  # 토큰 만료 확인 + 자동 갱신
  expires_at=$(echo "$creds" | jq -r '.claudeAiOauth.expiresAt // 0')
  now_ms=$(( $(date +%s) * 1000 ))
  if [ "$now_ms" -gt "$expires_at" ]; then
    token=$(_refresh_token "$creds") || return 1
  fi

  resp=$(curl -s --max-time 3 -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "User-Agent: claude-code/2.0.32" \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" \
    "https://api.anthropic.com/api/oauth/usage" 2>/dev/null) || return 1

  # 401이면 토큰 갱신 후 재시도
  if echo "$resp" | jq -e '.error.type == "authentication_error"' >/dev/null 2>&1; then
    token=$(_refresh_token "$creds") || return 1
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

if [ -f "$USAGE_CACHE" ]; then
  FIVE_HR_PCT=$(jq -r '.five_hour.utilization // 0' "$USAGE_CACHE" | cut -d. -f1)
  SEVEN_DAY_PCT=$(jq -r '.seven_day.utilization // 0' "$USAGE_CACHE" | cut -d. -f1)
fi

# 색상
CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'
MAGENTA='\033[35m'; WHITE='\033[1;37m'; DIM='\033[2m'; RESET='\033[0m'

# 컨텍스트 프로그레스 바
if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 80 ]; then BAR_COLOR="$YELLOW"
elif [ "$PCT" -ge 50 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

BAR_WIDTH=20
FILLED=$((PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""
[ "$FILLED" -gt 0 ] && BAR=$(printf "%${FILLED}s" | tr ' ' '█')
[ "$EMPTY" -gt 0 ] && BAR="${BAR}$(printf "%${EMPTY}s" | tr ' ' '░')"

# 토큰 수 (k 단위) + 캐시 히트율 통합
TOKEN_K=$((INPUT_TOKENS / 1000))
CACHE_PCT=0
TOTAL_WITH_CACHE=$((INPUT_TOKENS + CACHE_READ + CACHE_CREATE))
if [ "$TOTAL_WITH_CACHE" -gt 0 ]; then
  CACHE_PCT=$((CACHE_READ * 100 / TOTAL_WITH_CACHE))
fi

if [ "$CACHE_PCT" -gt 0 ]; then
  TOKEN_LABEL="${DIM}${TOKEN_K}k(${CACHE_PCT}%↑)${RESET}"
else
  TOKEN_LABEL="${DIM}${TOKEN_K}k${RESET}"
fi

# 컨텍스트 임계값 라벨
CTX_LABEL=""
if [ "$PCT" -ge 90 ]; then
  CTX_LABEL=" ${RED}CRITICAL${RESET}"
elif [ "$PCT" -ge 80 ]; then
  CTX_LABEL=" ${YELLOW}COMPRESS?${RESET}"
fi

# 사용 한도 라벨
LIMIT_LABEL=""
if [ "$FIVE_HR_PCT" -gt 0 ] || [ "$SEVEN_DAY_PCT" -gt 0 ]; then
  if [ "$FIVE_HR_PCT" -ge 80 ] || [ "$SEVEN_DAY_PCT" -ge 80 ]; then
    LIMIT_COLOR="$RED"
  elif [ "$FIVE_HR_PCT" -ge 50 ] || [ "$SEVEN_DAY_PCT" -ge 50 ]; then
    LIMIT_COLOR="$YELLOW"
  else
    LIMIT_COLOR="$GREEN"
  fi
  LIMIT_LABEL=" ${DIM}|${RESET} ${LIMIT_COLOR}5h:${FIVE_HR_PCT}% 7d:${SEVEN_DAY_PCT}%${RESET}"
fi

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

# 한 줄 출력
OUT="${WHITE} ${MODEL}${RESET}"
[ -n "$DIR" ] && OUT="${OUT} ${CYAN} ${DIR##*/}${RESET}"
[ -n "$BRANCH" ] && OUT="${OUT} ${MAGENTA} ${BRANCH}${RESET}"
OUT="${OUT} ${DIM}|${RESET} ${BAR_COLOR}${BAR}${RESET} ${PCT}% ${TOKEN_LABEL}${CTX_LABEL}"
OUT="${OUT}${LIMIT_LABEL}"
OUT="${OUT} ${DIM}|${RESET} ${COST_COLOR}\$${COST_FMT}${RESET}"
OUT="${OUT} ${DIM}|${RESET} ${DIM}${MINS}m ${SECS}s${RESET}"

printf '%b' "$OUT"
