#!/bin/bash
set -euo pipefail
LOG="/tmp/claude-hooks.log"

INPUT=$(cat)

if command -v jq &>/dev/null; then
  SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
  OFFSET=$(echo "$INPUT" | jq -r '.tool_input.offset // ""')
  LIMIT=$(echo "$INPUT" | jq -r '.tool_input.limit // ""')
  IS_WRITE=$(echo "$INPUT" | jq -r 'if .tool_input.content != null or .tool_input.new_string != null then "true" else "false" end')
else
  SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id',''))")
  FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))")
  OFFSET=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('offset',''))")
  LIMIT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('limit',''))")
  IS_WRITE=$(echo "$INPUT" | python3 -c "
import sys,json; d=json.load(sys.stdin); ti=d.get('tool_input',{})
print('true' if ti.get('content') is not None or ti.get('new_string') is not None else 'false')")
fi

[[ -z "$FILE_PATH" ]] && exit 0
[[ ! -f "$FILE_PATH" ]] && exit 0
[[ -z "$SESSION_ID" ]] && exit 0

# Skip binary and generated files
case "$FILE_PATH" in
  *.png|*.jpg|*.jpeg|*.gif|*.svg|*.ico|*.pdf|*.lock|*.min.js|*.min.css|*.map) exit 0 ;;
esac

FNAME=$(basename "$FILE_PATH")
CACHE_DIR="/tmp/claude-read-cache/$SESSION_ID"
mkdir -p "$CACHE_DIR"

if command -v md5 &>/dev/null; then
  CACHE_KEY=$(echo -n "$FILE_PATH" | md5 -q)
elif command -v md5sum &>/dev/null; then
  CACHE_KEY=$(echo -n "$FILE_PATH" | md5sum | cut -d' ' -f1)
else
  CACHE_KEY=$(echo -n "$FILE_PATH" | sed 's/[^a-zA-Z0-9]/_/g')
fi

CACHE_FILE="$CACHE_DIR/$CACHE_KEY"

if [[ "$IS_WRITE" == "true" ]]; then
  # On write/edit: update existing cache entry so pre-read stays in sync
  if [[ -f "$CACHE_FILE" ]]; then
    cp "$FILE_PATH" "$CACHE_FILE"
    echo "[$(date +%H:%M:%S)] post-file-cache: cache updated (${FNAME})" >> "$LOG"
  fi
else
  # On read: skip partial reads, cache full reads
  [[ -n "$OFFSET" && "$OFFSET" != "null" ]] && exit 0
  [[ -n "$LIMIT" && "$LIMIT" != "null" ]] && exit 0
  cp "$FILE_PATH" "$CACHE_FILE"
  echo "[$(date +%H:%M:%S)] post-file-cache: cached (${FNAME})" >> "$LOG"
fi

exit 0
