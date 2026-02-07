#!/bin/bash
set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

[ -z "$file_path" ] && exit 0
[ ! -f "$file_path" ] && exit 0

issues=()
ext="${file_path##*.}"

# TypeScript/JavaScript 파일만 체크
case "$ext" in
  ts|tsx|js|jsx) ;;
  *) exit 0 ;;
esac

# === Google TypeScript Style (gts) 규칙 체크 ===

# 1. var 사용 금지
var_count=$(grep -cE '\bvar\s+\w+' "$file_path" 2>/dev/null || echo 0)
if [ "$var_count" -gt 0 ]; then
  issues+=("var 사용 ${var_count}건 (const/let 사용)")
fi

# 2. == / != 사용 체크 (=== / !== 사용)
eq_count=$(grep -cE '[^!=]==[^=]|[^!]!=[^=]' "$file_path" 2>/dev/null || echo 0)
if [ "$eq_count" -gt 0 ]; then
  issues+=("== 또는 != 사용 ${eq_count}건 (===, !== 사용)")
fi

# 3. any 타입 사용 체크 (ts/tsx만)
if [[ "$ext" == "ts" || "$ext" == "tsx" ]]; then
  any_count=$(grep -cE ':\s*any\b|as\s+any\b|<any>' "$file_path" 2>/dev/null || echo 0)
  if [ "$any_count" -gt 0 ]; then
    issues+=("any 타입 ${any_count}건")
  fi
fi

# 4. @ts-ignore 사용 체크
ts_ignore=$(grep -cE '@ts-ignore' "$file_path" 2>/dev/null || echo 0)
if [ "$ts_ignore" -gt 0 ]; then
  issues+=("@ts-ignore ${ts_ignore}건 (@ts-expect-error 사용)")
fi

# 5. 더블쿼트 체크 (import/require 문의 문자열)
dq_count=$(grep -cE "import\s+.*from\s+\"" "$file_path" 2>/dev/null || echo 0)
if [ "$dq_count" -gt 0 ]; then
  issues+=("import 더블쿼트 ${dq_count}건 (싱글쿼트 사용)")
fi

# 6. console.log 잔여 체크
log_count=$(grep -cE 'console\.(log|debug|info)\(' "$file_path" 2>/dev/null || echo 0)
if [ "$log_count" -gt 0 ]; then
  issues+=("console.log ${log_count}건 잔여")
fi

# 7. 하드코딩 색상 + inline style (tsx/jsx)
if [[ "$ext" == "tsx" || "$ext" == "jsx" ]]; then
  color_count=$(grep -cE 'color:\s*["\x27]#[0-9a-fA-F]|backgroundColor:\s*["\x27]#|style=\{' "$file_path" 2>/dev/null || echo 0)
  if [ "$color_count" -gt 0 ]; then
    issues+=("하드코딩 색상/inline style ${color_count}건")
  fi
fi

# 8. class 컴포넌트 체크
if grep -qE 'class\s+\w+\s+extends\s+(React\.)?Component' "$file_path" 2>/dev/null; then
  issues+=("class 컴포넌트 감지 (함수형 전환)")
fi

# 9. 프로젝트 gts/eslint 실행
project_dir="${CLAUDE_PROJECT_DIR:-}"
if [ -n "$project_dir" ] && [ -f "$project_dir/node_modules/.bin/eslint" ]; then
  lint_output=$(cd "$project_dir" && node_modules/.bin/eslint "$file_path" --no-warn-ignored --format compact 2>/dev/null || true)
  lint_errors=$(echo "$lint_output" | grep -c "Error" 2>/dev/null || echo 0)
  if [ "$lint_errors" -gt 0 ]; then
    issues+=("ESLint 에러 ${lint_errors}건")
  fi
fi

# 이슈 없으면 조용히 종료
if [ ${#issues[@]} -eq 0 ]; then
  exit 0
fi

# 이슈 보고
msg="[GTS] ${file_path##*/}: "
msg+=$(IFS=', '; echo "${issues[*]}")

echo "{\"continue\": true, \"suppressOutput\": false, \"systemMessage\": \"$msg\"}"
