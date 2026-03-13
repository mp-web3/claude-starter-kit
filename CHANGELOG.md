# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-03-13

### Added

- **Agent definitions** — 4 pre-built agents for delegating work via the Agent tool:
  - `code-reviewer` — reviews diffs for bugs, security issues, style violations, test gaps (read-only, Sonnet)
  - `bug-fixer` — investigates, reproduces, fixes bugs + writes regression tests (Opus)
  - `implementer` — implements features from a plan/spec in dependency order (Opus)
  - `researcher` — explores codebases, reads docs, searches web for technical answers (read-only, Sonnet)
- Agent definitions referenced in CLAUDE.md template and copied by setup.sh

### Changed

- README rewritten for clarity — opens with one-line description, ASCII flow diagram, addresses context bloat concern upfront, removed duplicate security section

### Files

- 4 new: `agents/code-reviewer.md`, `agents/bug-fixer.md`, `agents/implementer.md`, `agents/researcher.md`
- Modified: `README.md`, `setup.sh`, `templates/CLAUDE.md`, `CHANGELOG.md`

## [1.0.0] - 2026-03-12

First stable release.

### Features

- **Guided onboarding** (`/onboard`) — 5-step interview: profile, 12 problems, goals, tasks, AI identity. Survives disconnects via YAML checkpoint.
- **Session persistence** — pre-compact hook saves state before context compression. Custom compaction prompt. Session save reminder after 10 minutes.
- **Security guard** (`global-guard.py`) — blocks secrets access, force-push, writes outside `$HOME`, `rm -rf`. Runs on every tool call via PreToolUse hook.
- **Task system** (`/tasks`) — SQLite-backed task management. Priority scoring against 12 problems. Auto-export to markdown backlog.
- **Knowledge system** — structured `knowledge/` directory. Claude reads files on demand, not all at startup. CLAUDE.md acts as an index.
- **Plan and implement** (`/plan`) — 6-phase gated workflow: explore, tool discovery, design, approve, implement, verify.
- **Reflection loop** (`/reflect`) — extracts corrections and preferences from session JSONL. Routes to correct files. Tracks rule health via feedback counters.
- **Delegation rules** — subagent orchestration with authority boundaries, dual-write knowledge flow, quality control.
- **Development standards** — code quality limits (100 lines/fn, complexity 8), testing philosophy, commit conventions.
- **Agent handoff protocol** — structured format for chaining subagents.
- **Status line** — two-line display: model, folder, branch, context usage bar, cost, duration, cache %.
- **Setup script** — detects OS, checks dependencies, copies files, personalizes CLAUDE.md.

### Files

- 4 skills: `/onboard`, `/tasks`, `/plan`, `/reflect`
- 6 rules: sessions, workflow, tasks, delegation, development, handoff
- 5 scripts: global-guard.py, db.py, extract-learnings.py, pre-compact.sh, session-save-reminder.sh
- 3 templates: CLAUDE.md, settings.json, gitignore

[1.1.0]: https://github.com/mp-web3/claude-starter-kit/releases/tag/v1.1.0
[1.0.0]: https://github.com/mp-web3/claude-starter-kit/releases/tag/v1.0.0
