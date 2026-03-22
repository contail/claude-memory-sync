# claude-memory-sync

Sync your Claude Code memory across machines with Git. Zero dependencies, 2-minute setup.

## Problem

Claude Code stores memory locally at `~/.claude/projects/.../memory/`. When you switch laptops, all context — project knowledge, feedback, work history — is gone.

## Solution

Git private repo + symlink + smart hooks. That's it.

```
Machine A                    Machine B
~/.claude/.../memory/   →   ~/.claude/.../memory/
        ↓ symlink                   ↓ symlink
~/claude-memory/memory/ ←→ ~/claude-memory/memory/
              ↕ git push/pull ↕
          github.com/you/claude-memory (private)
```

## Setup

### 1. Create your private memory repo

```bash
gh repo create claude-memory --private --confirm
```

### 2. Run the setup script

```bash
curl -fsSL https://raw.githubusercontent.com/contail/claude-memory-sync/main/setup.sh | bash
```

The script will:
- Clone your repo to `~/claude-memory`
- Find your Claude memory directory and symlink it
- Create smart sync scripts with pull cooldown
- Auto-configure hooks in `settings.json` (requires `jq`)

### 3. On your other machine

Run the same script — it detects existing repo memory and sets up the symlink accordingly.

## How it works

### Smart sync (not naive)

**Pull cooldown** — `git pull` only runs if 5+ minutes have passed since the last pull. Opening 10 terminals in a row doesn't mean 10 pulls.

```
CLAUDE_MEMORY_PULL_COOLDOWN=600  # override to 10 minutes
```

**Push on change only** — `git diff --cached --quiet` skips commit/push when nothing changed. Most sessions won't push anything.

```
Session start
  └→ sync-pull.sh (skip if pulled recently)
      └→ Claude reads/writes memory via symlink
          └→ Session end
              └→ sync-push.sh (skip if no changes)
```

### What gets synced

| Synced | Not synced |
|--------|------------|
| Memory files (*.md) | `.last-pull` timestamp |
| MEMORY.md index | `bin/` scripts |
| Project/feedback/reference memories | Sensitive files you `.gitignore` |

### Sensitive files

Add files with secrets to `~/claude-memory/.gitignore`:

```bash
echo "memory/reference-sentry.md" >> ~/claude-memory/.gitignore
```

## Manual commands

```bash
~/claude-memory/bin/sync-pull.sh   # force pull now
~/claude-memory/bin/sync-push.sh   # force push now
```

## FAQ

**Q: Do I need to set this up per terminal session?**

No. The symlink is filesystem-level — every Claude Code session on the same machine uses the same synced memory.

**Q: I open 5 terminals at once. Does it pull 5 times?**

No. The pull cooldown (default 5 min) prevents redundant pulls. Only the first session triggers a pull.

**Q: What if two machines edit memory at the same time?**

Memory files are independent (one file per topic), so conflicts are rare. `git pull --rebase` handles most cases. Worst case: a merge conflict you resolve once.

**Q: Can I share memory across a team?**

Yes — use a shared private repo. Works best for project-level knowledge (architecture, conventions), not personal preferences.

**Q: What if I don't have `jq`?**

The script prints the hooks JSON for you to paste into `settings.json` manually.

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
