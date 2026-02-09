#!/bin/bash
# Tool Output Truncator Hook (PostToolUse)
# 도구 출력이 과도할 때 자동 잘라내기
set -euo pipefail

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty')
tool_output=$(echo "$input" | jq -r '.tool_output // empty')

[ -z "$tool_output" ] && exit 0

# 도구별 최대 출력 길이
case "$tool_name" in
  WebFetch) max_len=40000 ;;
  Bash|Grep|Glob) max_len=200000 ;;
  *) exit 0 ;;
esac

output_len=${#tool_output}

if [ "$output_len" -gt "$max_len" ]; then
  cat <<EOF
{"continue": true, "suppressOutput": false, "systemMessage": "[TRUNCATED] ${tool_name} 출력이 ${output_len}자로 제한(${max_len}자)을 초과했습니다. 더 구체적인 검색 쿼리나 필터를 사용하세요."}
EOF
fi
