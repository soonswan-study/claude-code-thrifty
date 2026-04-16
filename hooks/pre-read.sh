#!/bin/bash
set -euo pipefail
LOG="/tmp/claude-hooks.log"

INPUT=$(cat)

if command -v jq &>/dev/null; then
  SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
  OFFSET=$(echo "$INPUT" | jq -r '.tool_input.offset // ""')
  LIMIT=$(echo "$INPUT" | jq -r '.tool_input.limit // ""')
else
  SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id',''))")
  FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))")
  OFFSET=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('offset',''))")
  LIMIT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('limit',''))")
fi

[[ -z "$FILE_PATH" ]] && exit 0
[[ ! -f "$FILE_PATH" ]] && exit 0
[[ -z "$SESSION_ID" ]] && exit 0
# Skip partial reads (offset/limit specified)
[[ -n "$OFFSET" && "$OFFSET" != "null" ]] && exit 0
[[ -n "$LIMIT" && "$LIMIT" != "null" ]] && exit 0

# Skip binary and generated files
case "$FILE_PATH" in
  *.png|*.jpg|*.jpeg|*.gif|*.svg|*.ico|*.pdf|*.lock|*.min.js|*.min.css|*.map) exit 0 ;;
esac

FNAME=$(basename "$FILE_PATH")
CACHE_DIR="/tmp/claude-read-cache/$SESSION_ID"
mkdir -p "$CACHE_DIR"

# Block large files (>1000 lines) - require offset/limit
LINE_COUNT=$(wc -l < "$FILE_PATH" 2>/dev/null || echo "0")
LINE_COUNT=$(echo "$LINE_COUNT" | tr -d ' ')
if [[ "$LINE_COUNT" -gt 1000 ]]; then
  echo "This file has ${LINE_COUNT} lines. Use offset/limit to read only the section you need." >&2
  echo "[$(date +%H:%M:%S)] pre-read: blocked large file ${FNAME} (${LINE_COUNT} lines)" >> "$LOG"
  exit 2
fi

if command -v md5 &>/dev/null; then
  CACHE_KEY=$(echo -n "$FILE_PATH" | md5 -q)
elif command -v md5sum &>/dev/null; then
  CACHE_KEY=$(echo -n "$FILE_PATH" | md5sum | cut -d' ' -f1)
else
  CACHE_KEY=$(echo -n "$FILE_PATH" | sed 's/[^a-zA-Z0-9]/_/g')
fi

CACHE_FILE="$CACHE_DIR/$CACHE_KEY"
[[ ! -f "$CACHE_FILE" ]] && exit 0

if diff -q "$CACHE_FILE" "$FILE_PATH" > /dev/null 2>&1; then
  echo "File unchanged (re-read unnecessary): $FILE_PATH"
  echo "No changes since last read. Work with the content you already have."
  echo "[$(date +%H:%M:%S)] pre-read: cache hit, blocked re-read (${FNAME})" >> "$LOG"
  exit 2
else
  echo "Showing only changes since last read: $FILE_PATH"
  echo "---"
  diff --unified=3 "$CACHE_FILE" "$FILE_PATH" || true
  echo "---"
  echo "Above diff shows changes since your last read."
  cp "$FILE_PATH" "$CACHE_FILE"
  echo "[$(date +%H:%M:%S)] pre-read: change detected, returning diff (${FNAME})" >> "$LOG"
  exit 2
fi
