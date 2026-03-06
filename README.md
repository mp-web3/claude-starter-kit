# Claude Code Starter Kit

Turn Claude Code into a personal AI assistant that remembers you across sessions.

Out of the box, Claude Code forgets everything when a session ends. This kit gives it persistent memory, security guardrails, and a self-improvement loop — so every session builds on the last.

## What You Get

| Component | What It Does |
|---|---|
| **Guided onboarding** | `/onboard` skill walks you through defining your profile, 12 Favorite Problems, goals, subgoals, and tasks — step by step. |
| **Session persistence** | Pre-compact hook saves state before context compression. Custom compaction prompt tells Claude what to preserve. Session notes protocol ensures nothing is lost. |
| **Security guard** | Blocks secrets access, force-push, writes outside `$HOME`, and destructive `rm -rf`. |
| **Knowledge system** | Structured `knowledge/` directory where Claude accumulates what it learns about you and your projects. |
| **Agent handoff protocol** | Structured format for chaining subagents without losing context between them. |
| **Session reminders** | After 10 minutes, Claude gets reminded to save state before ending. |
| **Self-improvement loop** | Corrections and preferences are externalized to files, not forgotten. |

## Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and working
- Git
- Python 3.10+ (for the security guard script)
- jq (for the status line — `brew install jq` on macOS)

## Setup (5 minutes)

```bash
# 1. Clone this repo
git clone https://github.com/mp-web3/claude-starter-kit.git
cd claude-starter-kit

# 2. Run setup
./setup.sh

# 3. Start your first session
cd ~/.claude
claude
```

The setup script copies files to `~/.claude/`, asks for your name and a short bio, and initializes a git repo for your config.

## First Session: /onboard (20-30 min)

After setup, start Claude Code and type:

```
/onboard
```

Claude will guide you through 5 steps:

1. **User profile** — conversational interview about who you are, what you do, your tools and preferences
2. **12 Favorite Problems** — the Feynman method: define the deep questions that drive everything you do
3. **End goal and subgoals** — where you're heading in the next 6-12 months, broken into milestones
4. **Initial tasks** — what to work on this week, connected to your goals
5. **AI self-knowledge** — how your assistant should behave and what it knows about itself

Progress is saved after every step. If you disconnect or close the terminal, just run `/onboard` again — it picks up where you left off automatically.

By the end, your `~/.claude/knowledge/` directory will contain your assistant's understanding of you. Every future session builds on this foundation.

## What Goes Where

```
~/.claude/
├── CLAUDE.md                  # Global instructions (loads every session)
├── settings.json              # Hooks, permissions, security config
├── .gitignore
├── rules/
│   ├── sessions.md            # Session logging protocol
│   ├── workflow.md            # Git discipline, self-improvement loop
│   └── handoff.md             # Agent handoff format for subagent chains
├── scripts/
│   ├── global-guard.py        # Security: path boundaries, secrets blocking
│   ├── pre-compact.sh         # Saves state before context compression
│   └── session-save-reminder.sh
├── skills/
│   └── onboard/SKILL.md       # Guided first-session setup
├── knowledge/                 # Claude reads these on demand
│   ├── self/identity.md       # AI self-knowledge (created by /onboard)
│   ├── user/profile.md        # Your profile (created by /onboard)
│   ├── user/goals.md          # Goals and subgoals (created by /onboard)
│   ├── problems/              # Your 12 problems (created by /onboard)
│   └── sessions/              # Session logs (accumulate over time)
└── statusline.sh              # Context %, cost, branch info
```

## How It Works

### The Memory Problem

Claude Code has no memory between sessions. It reads certain files at startup (`CLAUDE.md`, `rules/*.md`, `MEMORY.md`) — everything else is gone. This kit uses those loading points to maintain continuity:

1. **MEMORY.md** (auto-memory) — first 200 lines load automatically. Claude uses it as a cross-session index.
2. **Rules** — always-loaded behavioral instructions. Session protocol, git discipline, handoff format.
3. **Knowledge files** — read on demand. Claude accumulates project knowledge, user preferences, session history here.
4. **Hooks** — shell scripts that fire on events. Pre-compact saves state. Custom compaction prompt tells the summarizer what to preserve. Session reminders ensure nothing is forgotten.

### The Self-Improvement Loop

```
Session work → Claude notices correction/preference → Writes to knowledge file → Commits
Next session → Claude reads the file → Doesn't repeat the mistake
```

Same correction twice → gets promoted to a rule (always-loaded, every session).

### The 12 Favorite Problems

Your problems are a permanent filter for everything: tasks, reading, opportunities, conversations. If something doesn't connect to at least one problem, it's probably noise. Claude scores content and tasks against your problems automatically.

### Security

The guard script (`scripts/global-guard.py`) runs on every tool call and blocks:
- Reading/writing outside `$HOME` and `/tmp`
- Accessing `.env`, `.key`, `.pem`, `.secret` files
- `git push --force`
- `git add` on secrets files
- `rm -rf` (use `trash` instead)

## Growing the System

The starter kit is minimal on purpose. As you use it, the system grows naturally:

- **Claude creates knowledge files** as it learns about your projects, preferences, tools
- **Session notes accumulate** in `knowledge/sessions/`, creating searchable history
- **Rules evolve** — corrections become rules, rules become habits
- **New skills** can be added to `skills/` for workflows worth repeating

The `knowledge/` directory is your assistant's brain. Commit and push it regularly.

## Customization

**Project-specific rules:** create `.claude/rules/my-rule.md` in any project directory. Loads only for that project.

**Deny rules:** edit `~/.claude/settings.json` → `permissions.deny` to block specific tools/commands globally.

**Session reminder timing:** edit `scripts/session-save-reminder.sh` — change `600` (seconds) to adjust threshold.

**Compaction prompt:** edit the PreCompact prompt hook in `settings.json` to customize what Claude preserves during context compression.

## Credits

Built from patterns developed by [Mattia Papa](https://mattiapapa.dev) over months of daily Claude Code usage. The compaction prompt and handoff protocol are inspired by patterns from the Claude Code community.
