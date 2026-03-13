# Claude Code Starter Kit

A pre-built `~/.claude/` configuration that gives Claude Code persistent memory, security guardrails, and structured workflows. Clone, run `setup.sh`, and your next session picks up where the last one left off.

## How It Works

Claude Code reads `~/.claude/` at startup. This kit installs files there — rules, skills, scripts, and a knowledge directory — so every session starts with context about who you are, what you're building, and how to behave.

```
You run setup.sh ──→ Files copied to ~/.claude/ ──→ Claude reads them at startup
                                                          │
                              ┌────────────────────────────┤
                              ▼                            ▼
                     Always loaded:              Loaded on demand:
                     • CLAUDE.md                 • knowledge/user/profile.md
                     • rules/*.md                • knowledge/user/goals.md
                     • MEMORY.md (200 lines)     • knowledge/problems/*.md
                                                 • knowledge/projects/*.md
```

**On-demand loading is how this avoids context bloat.** Your `CLAUDE.md` contains a markdown table — a map of file paths and one-line descriptions. Claude sees the table at startup (~20-30 lines), then uses `Read` to open specific files when they're relevant to the current task. A typical session loads 3-5 files out of however many you have.

This is different from the `@import` syntax in `CLAUDE.md`, which loads files into every session unconditionally. Use `@import` for things you always want (rules). Use the table for everything else.

## What's Included

| Component | What It Does |
|---|---|
| `/onboard` | 20-30 min guided setup: profile, 12 Favorite Problems, goals, tasks, AI identity |
| `/tasks` | SQLite-backed task management. Tasks connect to your goals and problems |
| `/plan` | 6-phase gated workflow: explore → discover tools → design → approve → implement → verify |
| `/reflect` | Extracts corrections and preferences from sessions, routes them to the right files |
| Security guard | Blocks secrets access, force-push, writes outside `$HOME`, `rm -rf` |
| Session persistence | Pre-compact hook saves state before context compression. Session reminders after 10 min |
| Delegation rules | Subagent orchestration: authority boundaries, knowledge flow, quality control |
| Agent handoff | Structured format for chaining subagents without losing context |
| Agent definitions | 4 pre-built agents: code-reviewer, bug-fixer, implementer, researcher |
| Development standards | Code quality limits, testing philosophy, commit conventions |

## Setup (5 minutes)

**Prerequisites:** [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code), Git, Python 3.10+, jq

- **macOS:** `brew install jq`
- **Linux:** `apt install jq` / `dnf install jq`
- **Windows:** Install [Git Bash](https://gitforwindows.org), then `scoop install jq` or `choco install jq`

```bash
git clone https://github.com/mp-web3/claude-starter-kit.git
cd claude-starter-kit
./setup.sh
```

The script checks dependencies, copies files to `~/.claude/`, asks for your name and bio, and initializes a git repo.

Then start your first session:

```bash
cd ~/.claude
claude
```

Type `/onboard` — Claude walks you through defining your profile, problems, goals, and tasks. Takes 20-30 minutes. Saves progress after every step, so you can disconnect and resume anytime.

## Directory Structure

```
~/.claude/
├── CLAUDE.md                  # Global instructions (loads every session)
├── MEMORY.md                  # Cross-session index (first 200 lines auto-loaded)
├── settings.json              # Hooks, permissions, security config
├── rules/
│   ├── sessions.md            # Session logging protocol
│   ├── workflow.md            # Git discipline, file management
│   ├── tasks.md               # Task alignment rules
│   ├── delegation.md          # Subagent orchestration patterns
│   ├── development.md         # Code quality, testing, commits
│   └── handoff.md             # Agent handoff format
├── agents/
│   ├── code-reviewer.md       # Reviews diffs for bugs, security, style
│   ├── bug-fixer.md           # Investigates, reproduces, fixes bugs + writes tests
│   ├── implementer.md         # Implements features from a plan/spec
│   └── researcher.md          # Explores codebases and docs, returns structured findings
├── scripts/
│   ├── global-guard.py        # Security: path boundaries, secrets blocking
│   ├── db.py                  # SQLite task database
│   ├── extract-learnings.py   # Session JSONL parser for /reflect
│   ├── pre-compact.sh         # Saves state before context compression
│   └── session-save-reminder.sh
├── skills/
│   ├── onboard/SKILL.md       # Guided first-session setup
│   ├── tasks/SKILL.md         # Task management
│   ├── plan-and-implement/    # Structured build workflow
│   │   ├── SKILL.md
│   │   └── LEARNINGS.md
│   └── reflect/               # Session learning extraction
│       ├── SKILL.md
│       └── LEARNINGS.md
├── knowledge/                 # Claude reads these on demand
│   ├── self/identity.md       # AI self-knowledge (created by /onboard)
│   ├── user/profile.md        # Your profile (created by /onboard)
│   ├── user/goals.md          # Goals and subgoals (created by /onboard)
│   ├── problems/              # Your 12 problems (created by /onboard)
│   └── projects/              # Project-specific knowledge (grows over time)
├── state/
│   ├── sessions/              # Session logs
│   ├── backlog.md             # Task backlog (auto-exported from SQLite)
│   └── rule-feedback.json     # Rule health counters (from /reflect)
└── statusline.sh              # Context %, cost, branch info
```

## Security Guard

The guard script (`scripts/global-guard.py`) hooks into Claude Code's `PreToolUse` event — it runs before every tool call and can block dangerous operations.

| Category | What's Blocked | Why |
|---|---|---|
| Path boundaries | Reads/writes outside `$HOME` and `/tmp` | Prevents system file modification |
| Secrets | `.env`, `.key`, `.pem`, `.secret` files | Prevents accidental exposure |
| Git safety | `git push --force`, `git add` on secret files | Prevents data loss and secret commits |
| Destructive ops | `rm -rf` | Use `trash` instead (recoverable) |
| Branch protection | Direct push to `main`/`master` | Forces feature branch workflow |

**How it works:** The guard is configured in `settings.json` as a `PreToolUse` hook. Claude Code sends the tool name and input as JSON to stdin. The script checks against its rules and returns `{"allow": true}` or `{"blocked": true, "reason": "..."}`. Claude sees the reason and adjusts.

Customize by editing `scripts/global-guard.py` — add directory blocks, file extension rules, or audit logging.

## Agent Definitions

The `agents/` directory contains pre-built agent definitions for common development tasks. These work with Claude Code's Agent tool for delegating work to subagents.

| Agent | Purpose | Writes Code? |
|---|---|---|
| `code-reviewer` | Reviews diffs for bugs, security issues, style violations, test gaps | No (read-only) |
| `bug-fixer` | Takes a symptom → reproduces → finds root cause → fixes + tests | Yes |
| `implementer` | Implements features from a plan/spec in dependency order | Yes |
| `researcher` | Explores codebases, reads docs, answers technical questions | No (research only) |

All agents follow the delegation rules: they can read, write, and test, but cannot commit, push, or make architectural decisions. Each agent produces structured output (status, summary, files changed, next steps) for the main session to review.

## Self-Improvement Loop

```
Session work → Claude notices correction → Writes to knowledge file → Commits
Next session → Claude reads the file → Doesn't repeat the mistake
```

Same correction twice → gets promoted to a rule (always-loaded, every session).

Run `/reflect` periodically to formalize this. It reads your session transcript, detects corrections and preferences, checks for contradictions with existing rules, and tracks which rules are helping vs hurting via feedback counters.

## Growing the System

The starter kit is minimal on purpose. As you use it:

- Claude creates knowledge files as it learns about your projects and preferences
- Session notes accumulate in `state/sessions/`, creating searchable history
- Rules evolve — corrections become rules, unhealthy rules get flagged by `/reflect`
- New skills can be added to `skills/` for workflows worth repeating
- `LEARNINGS.md` files in each skill capture what worked and what didn't

The `knowledge/` directory is your assistant's brain. Commit and push it regularly.

## Customization

**Project-specific rules:** Create `.claude/rules/my-rule.md` in any project directory. Loads only for that project.

**Deny rules:** Edit `~/.claude/settings.json` → `permissions.deny` to block specific tools or commands globally.

**Session reminder timing:** Edit `scripts/session-save-reminder.sh` — change `600` (seconds) to adjust the threshold.

**Compaction prompt:** Edit the PreCompact prompt hook in `settings.json` to customize what Claude preserves during context compression.

**Development standards:** Edit `rules/development.md` to add your language-specific conventions, preferred linters, or stricter limits.

## Credits

Built from patterns developed by [Mattia Papa](https://mattiapapa.dev) over months of daily Claude Code usage.

## License

MIT
