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

### Windows setup

Run `setup.bat` as Administrator (symlink requires admin):

```cmd
git clone https://github.com/contail/claude-memory-sync.git %TEMP%\claude-memory-sync
%TEMP%\claude-memory-sync\setup.bat git@github.com:YOUR_USERNAME/claude-memory.git
```

Then add hooks to `%USERPROFILE%\.claude\settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -ExecutionPolicy Bypass -File %USERPROFILE%\\claude-memory\\bin\\sync-pull.ps1"
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
            "command": "powershell -ExecutionPolicy Bypass -File %USERPROFILE%\\claude-memory\\bin\\sync-push.ps1"
          }
        ]
      }
    ]
  }
}
```

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

> **Important:** The Stop hook pushes _file changes_, not conversation history. Claude must write memory files during the session for there to be anything to push. If a session ends without Claude saving any memory, nothing gets synced — this is a Claude Code limitation, not a bug.
>
> To maximize memory coverage, add this to your project's `CLAUDE.md`:
> ```
> When important information comes up during conversation (decisions, research findings,
> project context), proactively save it to memory files — don't wait for the user to ask.
> ```

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
# macOS / Linux
~/claude-memory/bin/sync-pull.sh
~/claude-memory/bin/sync-push.sh

# Windows (PowerShell)
powershell -File $env:USERPROFILE\claude-memory\bin\sync-pull.ps1
powershell -File $env:USERPROFILE\claude-memory\bin\sync-push.ps1
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

**Q: I had a conversation but nothing was pushed on session end?**

The Stop hook only pushes file changes. If Claude didn't write any memory files during the session, there's nothing to commit. Add a `CLAUDE.md` instruction to save memory proactively (see [How it works](#how-it-works)), or ask Claude to "save this to memory" before ending the session.

**Q: What if I don't have `jq`?**

The script prints the hooks JSON for you to paste into `settings.json` manually.

## Examples

See [`examples/`](examples/) for a complete reference:

```
examples/
├── memory/
│   ├── MEMORY.md                  # Index file — links to all memories
│   ├── user_profile.md            # type: user — role, expertise, preferences
│   ├── feedback_code_style.md     # type: feedback — corrections & confirmed patterns
│   ├── project_api_migration.md   # type: project — ongoing work, deadlines, decisions
│   └── reference_infra.md         # type: reference — dashboards, docs, ticket boards
├── settings.json                  # ~/.claude/settings.json with hooks pre-configured
└── .gitignore                     # Exclude sync internals + sensitive files
```

Each memory file uses frontmatter (`name`, `description`, `type`) so Claude knows when to recall it. See the files for real-world examples of how to structure each type.

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
