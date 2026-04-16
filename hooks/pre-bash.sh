#!/bin/bash
LOG="/tmp/claude-hooks.log"
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Filter test runner output to show only essential info (start, results, failures, errors)
if echo "$COMMAND" | grep -qE '(pytest|python -m pytest|manage\.py test|npm test|npx jest|yarn test|vitest)'; then
  echo "$COMMAND" | grep -q "pre-bash.helper.filter" && exit 0
  FILTER="$SCRIPT_DIR/pre-bash.helper.filter.sh"
  LIMITED="$COMMAND 2>&1 | $FILTER"
  jq -n "{
    hookSpecificOutput: {
      hookEventName: \"PreToolUse\",
      permissionDecision: \"allow\",
      updatedInput: { command: $(echo "$LIMITED" | jq -Rs .) },
      additionalContext: \"Test output filtered (showing only: start, results, failures, errors)\"
    }
  }"
  echo "[$(date +%H:%M:%S)] pre-bash: test output filter applied" >> "$LOG"
  exit 0
fi

# Limit log output to last 100 lines to save tokens
if echo "$COMMAND" | grep -qE '(cat.*\.(log|out|err)|journalctl|docker logs)' && \
   ! echo "$COMMAND" | grep -qE '(head|tail|wc|-n |grep)'; then
  LIMITED="$COMMAND | tail -100"
  jq -n "{
    hookSpecificOutput: {
      hookEventName: \"PreToolUse\",
      permissionDecision: \"allow\",
      updatedInput: { command: $(echo "$LIMITED" | jq -Rs .) },
      additionalContext: \"Output limited to last 100 lines to save tokens\"
    }
  }"
  echo "[$(date +%H:%M:%S)] pre-bash: log output limited to tail -100" >> "$LOG"
  exit 0
fi

exit 0
