# claude-memory-sync

Sync your Claude Code memory across machines with Git. Zero dependencies, 2-minute setup.

## Problem

Claude Code stores memory locally at `~/.claude/projects/.../memory/`. When you switch laptops, all context — project knowledge, feedback, work history — is gone.

## Solution

Git private repo + symlink + session hooks. That's it.

```
Machine A                    Machine B
~/.claude/.../memory/   →   ~/.claude/.../memory/
        ↓ symlink                   ↓ symlink
~/claude-memory/memory/ ←→ ~/claude-memory/memory/
              ↕ git push/pull ↕
          github.com/you/claude-memory (private)
```

- **Session start** → auto `git pull` (fetch latest memory)
- **Session end** → auto `commit + push` (sync changes)

## Setup

### 1. Create your private memory repo

```bash
gh repo create claude-memory --private --confirm
```

### 2. Run the setup script

```bash
curl -fsSL https://raw.githubusercontent.com/contail/claude-memory-sync/main/setup.sh | bash
```

Or manually:

```bash
git clone git@github.com:YOUR_USERNAME/claude-memory.git ~/claude-memory

# Find your memory path
MEMORY_PATH=$(find ~/.claude/projects -type d -name memory 2>/dev/null | head -1)

# Move memory to repo + symlink
cp -r "$MEMORY_PATH" ~/claude-memory/memory
rm -rf "$MEMORY_PATH"
ln -s ~/claude-memory/memory "$MEMORY_PATH"

# Initial push
cd ~/claude-memory && git add -A && git commit -m "Initial memory sync" && git push -u origin main
```

### 3. Add hooks to `~/.claude/settings.json`

Add the `hooks` block to your existing settings:

```json
{
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
}
```

### 4. On your other machine

```bash
git clone git@github.com:YOUR_USERNAME/claude-memory.git ~/claude-memory

MEMORY_PATH=$(find ~/.claude/projects -type d -name memory 2>/dev/null | head -1)
mv "$MEMORY_PATH" "${MEMORY_PATH}.bak" 2>/dev/null
ln -s ~/claude-memory/memory "$MEMORY_PATH"
```

Add the same hooks to that machine's `~/.claude/settings.json`.

Done.

## FAQ

**Q: Do I need to set this up per terminal session?**

No. The symlink is filesystem-level — every Claude Code session on the same machine automatically uses the same synced memory.

**Q: What if two machines edit memory at the same time?**

Memory files are independent (one file per topic), so conflicts are rare. `git pull --rebase` handles most cases automatically. Worst case: a merge conflict you resolve manually once.

**Q: What about sensitive data?**

Use a **private** repo. If you have API tokens in memory, add them to `.gitignore`:

```bash
echo "memory/reference-sentry.md" >> ~/claude-memory/.gitignore
```

**Q: Can I share memory across a team?**

Yes — use a shared private repo and each team member symlinks to it. Be aware that memories are personal context, so team-shared memory works best for project-level knowledge, not personal preferences.

## How it works

```
Claude Code session start
  └→ Hook: git pull --rebase (fetch latest)
      └→ Claude reads memory via symlink
          └→ Claude writes/updates memory
              └→ Session end
                  └→ Hook: git commit + push (sync back)
```

## Alternatives considered

| Approach | Pros | Cons |
|----------|------|------|
| **This (Git + symlink)** | Simple, no deps, version history | Manual conflict resolution (rare) |
| iCloud/Dropbox symlink | Auto sync | Sync delays, corruption risk |
| [claude-brain](https://github.com/toroleapinc/claude-brain) | Semantic merge | v0.1, unverified, extra dependency |
| [chezmoi](https://www.chezmoi.io/) | Dotfiles integration | Complex setup, no auto-pull |
| Anthropic official | Native support | [Not planned yet](https://github.com/anthropics/claude-code/issues/25739) |

## License

MIT
