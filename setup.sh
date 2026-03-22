#!/bin/bash
set -e

SYNC_DIR="$HOME/claude-memory"
SETTINGS_FILE="$HOME/.claude/settings.json"
PULL_COOLDOWN=300  # seconds

echo "=== claude-memory-sync setup ==="
echo ""

# Check prerequisites
if ! command -v git &>/dev/null; then
  echo "Error: git is required"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Warning: jq not found. Hooks will need to be added manually to settings.json"
  HAS_JQ=false
else
  HAS_JQ=true
fi

# Get repo URL
if [ -n "$1" ]; then
  REPO_URL="$1"
else
  read -p "Your claude-memory repo URL (e.g. git@github.com:you/claude-memory.git): " REPO_URL
fi

if [ -z "$REPO_URL" ]; then
  echo "Error: repo URL is required"
  exit 1
fi

# Clone or pull
if [ -d "$SYNC_DIR/.git" ]; then
  echo "Repo already exists at $SYNC_DIR, pulling latest..."
  cd "$SYNC_DIR" && git pull --rebase
else
  echo "Cloning repo..."
  git clone "$REPO_URL" "$SYNC_DIR"
fi

# Find memory path
MEMORY_PATH=$(find "$HOME/.claude/projects" -type d -name memory 2>/dev/null | head -1)

if [ -z "$MEMORY_PATH" ]; then
  echo "No existing Claude Code memory directory found."
  echo "Run Claude Code at least once to generate memory, then re-run this script."
  exit 1
fi

# Check if already symlinked
if [ -L "$MEMORY_PATH" ]; then
  echo "Already symlinked: $MEMORY_PATH -> $(readlink "$MEMORY_PATH")"
  echo "Skipping symlink setup."
else
  if [ -d "$SYNC_DIR/memory" ] && [ "$(ls -A "$SYNC_DIR/memory" 2>/dev/null)" ]; then
    echo "Memory found in repo. Backing up local memory..."
    mv "$MEMORY_PATH" "${MEMORY_PATH}.bak"
    echo "Backed up to ${MEMORY_PATH}.bak"
  else
    echo "Moving local memory to repo..."
    cp -r "$MEMORY_PATH" "$SYNC_DIR/memory"
    rm -rf "$MEMORY_PATH"
    cd "$SYNC_DIR" && git add -A && git commit -m "Initial memory sync" && git push -u origin main
  fi

  ln -s "$SYNC_DIR/memory" "$MEMORY_PATH"
  echo "Symlinked: $MEMORY_PATH -> $SYNC_DIR/memory"
fi

# Create sync script (smart pull with cooldown)
mkdir -p "$SYNC_DIR/bin"
cat > "$SYNC_DIR/bin/sync-pull.sh" << 'PULLEOF'
#!/bin/bash
SYNC_DIR="$HOME/claude-memory"
STAMP="$SYNC_DIR/.last-pull"
COOLDOWN=${CLAUDE_MEMORY_PULL_COOLDOWN:-300}

if [ -f "$STAMP" ]; then
  LAST=$(cat "$STAMP")
  NOW=$(date +%s)
  DIFF=$((NOW - LAST))
  if [ "$DIFF" -lt "$COOLDOWN" ]; then
    exit 0
  fi
fi

cd "$SYNC_DIR" && git pull --rebase 2>/dev/null && date +%s > "$STAMP"
PULLEOF

cat > "$SYNC_DIR/bin/sync-push.sh" << 'PUSHEOF'
#!/bin/bash
SYNC_DIR="$HOME/claude-memory"
cd "$SYNC_DIR" || exit 0
git add -A
git diff --cached --quiet && exit 0
git commit -m "sync $(date +%F-%H%M)" 2>/dev/null
git push 2>/dev/null
date +%s > "$SYNC_DIR/.last-pull"
PUSHEOF

chmod +x "$SYNC_DIR/bin/sync-pull.sh" "$SYNC_DIR/bin/sync-push.sh"
echo "Created sync scripts at $SYNC_DIR/bin/"

# Add .gitignore for sync internals
cat > "$SYNC_DIR/.gitignore" << 'IGNEOF'
.last-pull
bin/
IGNEOF

# Auto-configure hooks in settings.json
if [ "$HAS_JQ" = true ] && [ -f "$SETTINGS_FILE" ]; then
  # Check if hooks already exist
  if jq -e '.hooks.SessionStart' "$SETTINGS_FILE" &>/dev/null; then
    echo ""
    echo "Hooks already exist in settings.json. Skipping auto-config."
    echo "Verify your hooks point to: ~/claude-memory/bin/sync-pull.sh and sync-push.sh"
  else
    echo ""
    echo "Adding hooks to $SETTINGS_FILE..."
    UPDATED=$(jq '. + {
      "hooks": {
        "SessionStart": [
          {
            "matcher": "",
            "hooks": [
              {
                "type": "command",
                "command": "~/claude-memory/bin/sync-pull.sh"
              }
            ]
          }
        ],
        "Stop": [
          {
            "matcher": "",
            "hooks": [
              {
                "type": "command",
                "command": "~/claude-memory/bin/sync-push.sh"
              }
            ]
          }
        ]
      }
    }' "$SETTINGS_FILE")
    echo "$UPDATED" > "$SETTINGS_FILE"
    echo "Hooks added successfully."
  fi
else
  echo ""
  echo "Add these hooks to $SETTINGS_FILE manually:"
  echo ""
  cat <<'HOOKS'
"hooks": {
  "SessionStart": [
    { "matcher": "", "hooks": [{ "type": "command", "command": "~/claude-memory/bin/sync-pull.sh" }] }
  ],
  "Stop": [
    { "matcher": "", "hooks": [{ "type": "command", "command": "~/claude-memory/bin/sync-push.sh" }] }
  ]
}
HOOKS
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "Config:"
echo "  Pull cooldown: ${PULL_COOLDOWN}s (set CLAUDE_MEMORY_PULL_COOLDOWN to override)"
echo "  Sync dir:      $SYNC_DIR"
echo "  Memory link:   $MEMORY_PATH -> $SYNC_DIR/memory"
echo ""
echo "Commands:"
echo "  Manual pull:   ~/claude-memory/bin/sync-pull.sh"
echo "  Manual push:   ~/claude-memory/bin/sync-push.sh"
