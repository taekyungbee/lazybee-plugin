#!/bin/bash
# Comment Checker Hook (PostToolUse)
# Write/Edit 후 AI 슬로프 주석 감지
set -euo pipefail

input=$(cat)

file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
[ -z "$file_path" ] && exit 0
[ ! -f "$file_path" ] && exit 0

ext="${file_path##*.}"
case "$ext" in
  ts|tsx|js|jsx) ;;
  *) exit 0 ;;
esac

# 슬로프 주석 패턴 감지 (유용한 주석은 제외)
slop_comments=$(grep -nE '^\s*//' "$file_path" 2>/dev/null | \
  grep -viE 'TODO|FIXME|HACK|NOTE|XXX|WARN|@ts-expect-error|eslint-disable|@license|@copyright|Copyright|\*\*/' | \
  grep -iE \
    -e '//\s*(Set|Sets)\s+\w+\s+to\s+' \
    -e '//\s*(Import|Importing)\s+\w+' \
    -e '//\s*This\s+(function|method|class|component)\s+(does|is|will|returns|handles)' \
    -e '//\s*(Handle|Handles|Handling)\s+\w+' \
    -e '//\s*(Get|Gets|Getting)\s+(the\s+)?\w+' \
    -e '//\s*(Create|Creates|Creating)\s+(a\s+|the\s+)?\w+' \
    -e '//\s*(Return|Returns|Returning)\s+(the\s+)?\w+' \
    -e '//\s*(Check|Checks|Checking)\s+(if\s+|the\s+)?\w+' \
    -e '//\s*(Initialize|Init)\s+\w+' \
    -e '//\s*(Define|Defining)\s+(the\s+|a\s+)?\w+' \
    -e '//\s*(Update|Updating)\s+(the\s+)?\w+' \
    -e '//\s*(Delete|Deleting|Remove|Removing)\s+(the\s+)?\w+' \
    -e '//\s*(Add|Adding)\s+(the\s+|a\s+)?\w+' \
    -e '//\s*(Loop|Iterate|Iterating)\s+(through|over)\s+' \
    -e '//\s*(Export|Exporting)\s+(the\s+|default\s+)?\w+' \
  2>/dev/null || true)

slop_count=$(echo "$slop_comments" | grep -c . 2>/dev/null || echo 0)

if [ "$slop_count" -gt 0 ]; then
  # 최대 5개까지만 예시 표시
  examples=$(echo "$slop_comments" | head -5 | sed 's/"/\\"/g' | tr '\n' '; ')
  cat <<EOF
{"continue": true, "suppressOutput": false, "systemMessage": "[COMMENT] ${file_path##*/}: 불필요한 슬로프 주석 ${slop_count}건 감지. 코드가 자명한 경우 주석을 제거하세요. 예: ${examples}"}
EOF
fi
