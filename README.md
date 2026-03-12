# Claude Code Starter Kit

Turn Claude Code into a personal AI assistant that remembers you across sessions.

Out of the box, Claude Code forgets everything when a session ends. This kit gives it persistent memory, security guardrails, a self-improvement loop, and structured workflows for planning and delegation — so every session builds on the last.

## What You Get

| Component | What It Does |
|---|---|
| **Guided onboarding** | `/onboard` walks you through defining your profile, 12 Favorite Problems, goals, subgoals, and tasks. |
| **Session persistence** | Pre-compact hook saves state before context compression. Custom compaction prompt tells Claude what to preserve. Session notes protocol ensures nothing is lost. |
| **Security guard** | Blocks secrets access, force-push, direct push to main, writes outside `$HOME`, and destructive `rm -rf`. |
| **Task system** | SQLite-backed task management with `/tasks`. Tasks connect to your goals and 12 problems. |
| **Knowledge system** | Structured `knowledge/` directory where Claude accumulates what it learns about you and your projects. |
| **Plan & implement** | `/plan` enforces a 6-phase workflow: explore, tool discovery, design, approve, implement, verify. No coding before approval. |
| **Reflection loop** | `/reflect` extracts corrections, preferences, and patterns from your sessions and routes them to the right files. Tracks rule health over time. |
| **Delegation rules** | Subagent orchestration: authority boundaries, knowledge flow (dual-write pattern), quality control, error handling. |
| **Development standards** | Code quality limits, testing philosophy, commit conventions. |
| **Agent handoff protocol** | Structured format for chaining subagents without losing context between them. |
| **Session reminders** | After 10 minutes, Claude gets reminded to save state before ending. |

## Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and working
- Git
- Python 3.10+ (for the security guard and learning extraction)
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
│   ├── tasks.md               # Task alignment rules
│   ├── delegation.md          # Subagent orchestration patterns
│   ├── development.md         # Code quality, testing, commits
│   └── handoff.md             # Agent handoff format for subagent chains
├── scripts/
│   ├── global-guard.py        # Security: path boundaries, secrets blocking
│   ├── db.py                  # SQLite task database
│   ├── extract-learnings.py   # Session JSONL parser for /reflect
│   ├── pre-compact.sh         # Saves state before context compression
│   └── session-save-reminder.sh
├── skills/
│   ├── onboard/SKILL.md       # Guided first-session setup
│   ├── tasks/SKILL.md         # Task management (/tasks)
│   ├── plan-and-implement/    # Structured build workflow (/plan)
│   │   ├── SKILL.md
│   │   └── LEARNINGS.md       # Skill-specific learnings (grows over time)
│   └── reflect/               # Session learning extraction (/reflect)
│       ├── SKILL.md
│       └── LEARNINGS.md
├── knowledge/                 # Claude reads these on demand
│   ├── self/identity.md       # AI self-knowledge (created by /onboard)
│   ├── user/profile.md        # Your profile (created by /onboard)
│   ├── user/goals.md          # Goals and subgoals (created by /onboard)
│   ├── problems/              # Your 12 problems (created by /onboard)
│   └── projects/              # Project-specific knowledge (grows over time)
├── state/
│   ├── sessions/              # Session logs (accumulate over time)
│   ├── backlog.md             # Task backlog (auto-exported from SQLite)
│   └── rule-feedback.json     # Rule health counters (created by /reflect)
└── statusline.sh              # Context %, cost, branch info
```

## How It Works

### The Memory Problem

Claude Code has no memory between sessions. It reads certain files at startup (`CLAUDE.md`, `rules/*.md`, `MEMORY.md`) — everything else is gone. This kit uses those loading points to maintain continuity:

1. **MEMORY.md** (auto-memory) — first 200 lines load automatically. Claude uses it as a cross-session index.
2. **Rules** — always-loaded behavioral instructions. Session protocol, git discipline, delegation patterns, development standards.
3. **Knowledge files** — read on demand. Claude accumulates project knowledge, user preferences, session history here.
4. **Hooks** — shell scripts that fire on events. Pre-compact saves state. Custom compaction prompt tells the summarizer what to preserve. Session reminders ensure nothing is forgotten.

### How Knowledge Routing Works

This is the part that surprises people: **knowledge files are NOT loaded at startup.** They are read on demand.

Your `CLAUDE.md` contains a plain markdown table — a map of file paths and one-line descriptions:

```markdown
## Knowledge Files — Read On Demand

| Path | Content |
|---|---|
| `knowledge/user/profile.md` | Background, career, personality, preferences |
| `knowledge/user/goals.md` | End goal, subgoals, metrics |
| `knowledge/problems/00-overview.md` | 12 Favorite Problems — overview and how to use |
| `knowledge/projects/my-app.md` | Architecture, decisions, current state |
```

Claude reads this table at session start (it's part of `CLAUDE.md`), sees what exists, and then uses the `Read` tool to open specific files when it needs them during the conversation. If you ask about your goals, it reads `goals.md`. If you ask about a project, it reads that project's file. The context cost is just the index table (~20-30 lines) plus whatever Claude pulls in for the current task.

A typical session loads 3-5 files out of however many you have. This is different from the `@import` syntax in `CLAUDE.md`, which loads files at startup into every session. Use `@import` for things you always want (rules). Use the table for everything else.

The `/onboard` skill creates the initial knowledge files and the table. As you work, Claude adds new entries to the table when it creates new knowledge files.

### How the Security Guard Works

The guard script (`scripts/global-guard.py`) hooks into Claude Code's `PreToolUse` event — it runs before every tool call and can block dangerous operations.

**What it blocks:**

| Category | Examples | Why |
|---|---|---|
| Path boundaries | Reads/writes outside `$HOME` and `/tmp` | Prevents system file modification |
| Secrets | `.env`, `.key`, `.pem`, `.secret` files | Prevents accidental exposure |
| Git safety | `git push --force`, `git add` on secret files | Prevents data loss and secret commits |
| Destructive ops | `rm -rf` (Bash guard) | Use `trash` instead (recoverable) |
| Branch protection | Direct push to `main`/`master` | Forces feature branch workflow |

**How it works technically:**

The guard is configured in `settings.json` as a `PreToolUse` hook. Claude Code sends the tool name and input to the script. The script checks against its rules and returns either `{"allow": true}` or `{"blocked": true, "reason": "..."}`. If blocked, Claude sees the reason and adjusts its approach.

You can customize the guard by editing `scripts/global-guard.py`. Common additions:
- Block specific directories (e.g., a company repo you want read-only)
- Add file extension blocks
- Log blocked operations for audit

### The Self-Improvement Loop

```
Session work → Claude notices correction/preference → Writes to knowledge file → Commits
Next session → Claude reads the file → Doesn't repeat the mistake
```

Same correction twice → gets promoted to a rule (always-loaded, every session).

Run `/reflect` periodically to formalize this. It extracts learnings from your session JSONL, detects contradictions with existing rules, and tracks which rules are helping vs hurting via feedback counters.

### Planning Without Drift

The `/plan` skill enforces a gate between thinking and building:

1. **Explore** the codebase and understand what exists
2. **Search** for existing tools before building custom (MCP server > SDK > custom)
3. **Design** the implementation with file lists and dependencies
4. **Get approval** — no coding starts until you approve the plan
5. **Implement** step by step against the approved plan
6. **Verify** the acceptance criteria are met

This prevents the most common failure mode: Claude starts building before it fully understands what's needed, then drifts from the plan.

### Delegating to Subagents

The delegation rules (`rules/delegation.md`) solve the "compound knowledge" problem — where subagents don't read what previous subagents learned:

- **Dual-write pattern**: subagents write working docs in the project (for next subagent) AND report findings back (for you to consolidate)
- **Authority boundaries**: subagents can read, write, and test — but can't commit, push, or make architectural decisions
- **Quality control**: always spot-check output before committing. "Tests pass" is a claim, not a fact, until you verify it.

### The 12 Favorite Problems

Your problems are a permanent filter for everything: tasks, reading, opportunities, conversations. If something doesn't connect to at least one problem, it's probably noise. Claude scores content and tasks against your problems automatically.

### Security

The guard script (`scripts/global-guard.py`) runs on every tool call and blocks:
- Reading/writing outside `$HOME` and `/tmp`
- Accessing `.env`, `.key`, `.pem`, `.secret` files
- `git push --force`
- `git add` on secrets files

Additional Bash guards block:
- `rm -rf` (use `trash` instead)
- Direct push to `main` or `master` (use feature branches)

## Growing the System

The starter kit is minimal on purpose. As you use it, the system grows naturally:

- **Claude creates knowledge files** as it learns about your projects, preferences, tools
- **Session notes accumulate** in `state/sessions/`, creating searchable history
- **Rules evolve** — corrections become rules, rules that hurt get flagged and removed by `/reflect`
- **New skills** can be added to `skills/` for workflows worth repeating
- **LEARNINGS.md** files in each skill directory capture what worked and what didn't

The `knowledge/` directory is your assistant's brain. Commit and push it regularly.

## Customization

**Project-specific rules:** create `.claude/rules/my-rule.md` in any project directory. Loads only for that project.

**Deny rules:** edit `~/.claude/settings.json` → `permissions.deny` to block specific tools/commands globally.

**Session reminder timing:** edit `scripts/session-save-reminder.sh` — change `600` (seconds) to adjust threshold.

**Compaction prompt:** edit the PreCompact prompt hook in `settings.json` to customize what Claude preserves during context compression.

**Development standards:** edit `rules/development.md` to add your language-specific conventions, preferred linters, or stricter limits.

## Credits

Built from patterns developed by [Mattia Papa](https://mattiapapa.dev) over months of daily Claude Code usage. The compaction prompt and handoff protocol are inspired by patterns from the Claude Code community.
