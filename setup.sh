#!/bin/bash
set -e

echo "=== claude-memory-sync setup ==="
echo ""

# Check prerequisites
if ! command -v git &>/dev/null; then
  echo "Error: git is required"
  exit 1
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

SYNC_DIR="$HOME/claude-memory"

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
  # If repo has memory dir, use it. Otherwise copy from local.
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

echo ""
echo "=== Done! ==="
echo ""
echo "Next step: add hooks to ~/.claude/settings.json"
echo ""
cat <<'HOOKS'
Add this to your settings.json:

"hooks": {
  "SessionStart": [
    {
      "matcher": "",
      "hooks": [
        {
          "type": "command",
          "command": "cd ~/claude-memory && git pull --rebase 2>/dev/null || true"
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
          "command": "cd ~/claude-memory && git add -A && git diff --cached --quiet || (git commit -m \"sync $(date +%F-%H%M)\" && git push) 2>/dev/null || true"
        }
      ]
    }
  ]
}
HOOKS
