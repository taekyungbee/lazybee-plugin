#!/bin/bash
# Edit Error Recovery Hook (PostToolUse)
# Edit/Write 실패 시 자동 복구 지시
set -euo pipefail

input=$(cat)

tool_output=$(echo "$input" | jq -r '.tool_output // empty')
[ -z "$tool_output" ] && exit 0

# Edit 실패 패턴 감지
recovery_needed=false
if echo "$tool_output" | grep -qiE 'oldString not found|old_string not found'; then
  recovery_needed=true
  reason="oldString을 찾을 수 없습니다"
elif echo "$tool_output" | grep -qiE 'oldString found multiple times|old_string found multiple times'; then
  recovery_needed=true
  reason="oldString이 여러 번 발견되었습니다. 더 구체적인 컨텍스트를 포함하세요"
elif echo "$tool_output" | grep -qiE 'oldString and newString must be different|old_string and new_string must be different'; then
  recovery_needed=true
  reason="old_string과 new_string이 동일합니다"
fi

if [ "$recovery_needed" = true ]; then
  cat <<EOF
{"continue": true, "suppressOutput": false, "systemMessage": "[EDIT ERROR] ${reason}. 파일을 다시 Read로 읽고 실제 내용을 확인한 후 정확한 문자열로 재시도하세요."}
EOF
fi
