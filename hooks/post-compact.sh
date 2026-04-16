#!/bin/bash
set -euo pipefail
LOG="/tmp/claude-hooks.log"

INPUT=$(cat 2>/dev/null || echo "{}")
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")

if [[ -n "$SESSION_ID" && -d "/tmp/claude-read-cache/$SESSION_ID" ]]; then
  CACHED_COUNT=$(find "/tmp/claude-read-cache/$SESSION_ID" -type f | wc -l | tr -d ' ')
  rm -rf "/tmp/claude-read-cache/$SESSION_ID"
  if [[ "$CACHED_COUNT" -gt 0 ]]; then
    echo "[PostCompact] Read cache cleared (${CACHED_COUNT} entries removed). Re-read files as needed."
    echo "[$(date +%H:%M:%S)] post-compact: read cache cleared (${CACHED_COUNT} entries)" >> "$LOG"
  fi
fi

if [[ -n "$SESSION_ID" && -d "/tmp/claude-hook-cache/$SESSION_ID" ]]; then
  rm -rf "/tmp/claude-hook-cache/$SESSION_ID"
  echo "[PostCompact] Hook cache cleared."
  echo "[$(date +%H:%M:%S)] post-compact: hook cache cleared" >> "$LOG"
fi

exit 0
