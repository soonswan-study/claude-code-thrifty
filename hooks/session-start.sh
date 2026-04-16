#!/bin/bash
set -euo pipefail
LOG="/tmp/claude-hooks.log"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")

CACHE_BASE="/tmp/claude-read-cache"
mkdir -p "$CACHE_BASE"
if [[ -n "$SESSION_ID" && -d "$CACHE_BASE/$SESSION_ID" ]]; then
  CACHED_COUNT=$(find "$CACHE_BASE/$SESSION_ID" -type f | wc -l | tr -d ' ')
  rm -rf "$CACHE_BASE/$SESSION_ID"
  CACHE_MSG="Read cache cleared (${CACHED_COUNT} entries)"
  echo "[SessionStart] ${CACHE_MSG}"
  echo "[$(date +%H:%M:%S)] session-start: ${CACHE_MSG}" >> "$LOG"
else
  CACHE_MSG="No cache to clear"
  echo "[SessionStart] ${CACHE_MSG}"
fi
osascript -e "display notification \"${CACHE_MSG}\" with title \"Claude Code\" subtitle \"Session started\"" 2>/dev/null || true
# Clean up caches older than 7 days
find "$CACHE_BASE" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
find /tmp/claude-hook-cache -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true

echo ""
echo "[Reminder] Do not re-query git status or project structure injected at session start."

echo "[$(date +%H:%M:%S)] session-start: done" >> "$LOG"
exit 0
