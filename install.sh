#!/bin/bash
set -euo pipefail

# cache-cow installer 🐄
# Symlinks hooks into ~/.claude/hooks/ and merges settings into ~/.claude/settings.json

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_SRC="$REPO_DIR/hooks"
HOOKS_DST="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"

echo "=== 🐄 cache-cow installer ==="
echo ""

# 1. Check dependencies
if ! command -v jq &>/dev/null; then
  echo "[!] jq is required. Install it first:"
  echo "    macOS:  brew install jq"
  echo "    Linux:  apt install jq"
  exit 1
fi
echo "[ok] jq found"

# 2. Symlink hook scripts
mkdir -p "$HOOKS_DST"
LINKED=0
for script in "$HOOKS_SRC"/*.sh; do
  fname=$(basename "$script")
  ln -sf "$script" "$HOOKS_DST/$fname"
  LINKED=$((LINKED + 1))
done
echo "[ok] ${LINKED} hooks symlinked to $HOOKS_DST"

# 3. Make hooks executable
chmod +x "$HOOKS_SRC"/*.sh
echo "[ok] hooks marked executable"

# 4. Merge hook config into settings.json
HOOK_CONFIG='{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [{"type": "command", "command": "~/.claude/hooks/session-start.sh", "timeout": 10000}]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Read",
        "hooks": [{"type": "command", "command": "~/.claude/hooks/pre-read.sh", "timeout": 3000}]
      },
      {
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": "~/.claude/hooks/pre-bash.sh", "timeout": 3000}]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Read|Edit|Write",
        "hooks": [{"type": "command", "command": "~/.claude/hooks/post-file-cache.sh", "timeout": 3000}]
      }
    ],
    "PostCompact": [
      {
        "matcher": "*",
        "hooks": [{"type": "command", "command": "~/.claude/hooks/post-compact.sh", "timeout": 5000}]
      }
    ]
  }
}'

if [[ -f "$SETTINGS" ]]; then
  # Merge hooks into existing settings (preserving other keys like permissions, env)
  MERGED=$(jq -s '.[0] * .[1]' "$SETTINGS" <(echo "$HOOK_CONFIG"))
  echo "$MERGED" > "$SETTINGS"
  echo "[ok] hooks merged into existing $SETTINGS"
else
  mkdir -p "$(dirname "$SETTINGS")"
  echo "$HOOK_CONFIG" | jq '.' > "$SETTINGS"
  echo "[ok] created $SETTINGS with hook config"
fi

# 5. Append CLAUDE.md token efficiency principles (if not already present)
if [[ -f "$CLAUDE_MD" ]]; then
  if grep -q "Token Efficiency Principles" "$CLAUDE_MD" 2>/dev/null; then
    echo "[ok] CLAUDE.md already contains token efficiency principles, skipping"
  else
    echo "" >> "$CLAUDE_MD"
    cat "$REPO_DIR/examples/CLAUDE.md.example" >> "$CLAUDE_MD"
    echo "[ok] appended token efficiency principles to $CLAUDE_MD"
  fi
else
  mkdir -p "$(dirname "$CLAUDE_MD")"
  cp "$REPO_DIR/examples/CLAUDE.md.example" "$CLAUDE_MD"
  echo "[ok] created $CLAUDE_MD"
fi

# 6. Verify
echo ""
echo "=== Verification ==="
HOOK_COUNT=$(find "$HOOKS_DST" -name "*.sh" -type l | wc -l | tr -d ' ')
echo "Symlinks in $HOOKS_DST: ${HOOK_COUNT}"
echo ""
echo "🐄 Installation complete! Start a new Claude Code session to activate."
echo "Monitor hooks: tail -f /tmp/claude-hooks.log"
