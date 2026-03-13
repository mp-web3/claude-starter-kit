# Global Standards

Global instructions for all projects. Project-specific CLAUDE.md files override these defaults.

## Philosophy

- **No speculative features** — Don't add features, flags, or configuration unless actively needed
- **Clarity over cleverness** — Prefer explicit, readable code over dense one-liners
- **Bias toward action** — Decide and move for anything easily reversed; ask before committing to interfaces, data models, or destructive operations
- **Finish the job** — Handle edge cases you can see. Clean up what you touched. But don't invent new scope.
- **Externalize everything** — If it's not written to a file, it's gone next session. Write corrections, preferences, and decisions immediately.
- **Autonomy-first** — Before building custom wrappers: search for MCP server > official SDK > custom wrapper. Prefer tools Claude can operate programmatically.

## Communication Style

- Be concise — skip preamble and get to the point
- Use tables and structured formats for data-heavy responses
- Include specific numbers and dates, not vague descriptions
- No emoji unless requested
- No marketing language, hype, or superlatives
- Don't flatter — specific praise when earned, never generic encouragement

## User Context

**{{USER_NAME}}** — {{USER_BIO}}

Full profile: `knowledge/user/profile.md`
Goals: `knowledge/user/goals.md`
12 Problems: `knowledge/problems/00-overview.md`

## Knowledge System

- Knowledge files live in `~/.claude/knowledge/` — read on demand, don't preload all at once
- Session notes go in `state/sessions/` — every session gets a note
- MEMORY.md is the cross-session index — keep it under 200 lines, use it as an index not a document
- Each fact lives in ONE place, referenced from others — no duplication
- YAML frontmatter on every knowledge file (tags, date, type)

## 12 Problems Filter

When evaluating tasks, content, or opportunities, check against the user's 12 Favorite Problems in `knowledge/problems/00-overview.md`. If something doesn't connect to any problem, flag it. This is how the user filters signal from noise.

## Available Skills

- `/onboard` — Guided first-session setup (profile, problems, goals, tasks)
- `/tasks` — Manage the task backlog (add, review, complete, metrics)
- `/plan` — Structured build workflow: explore, design, approve, implement, verify
- `/reflect` — Extract learnings from the session and route them to the right files

## Agent Definitions

Pre-built agents for delegation via the Agent tool:

| Agent | File | Purpose |
|---|---|---|
| Code Reviewer | `agents/code-reviewer.md` | Reviews diffs — read-only, never modifies files |
| Bug Fixer | `agents/bug-fixer.md` | Investigates, reproduces, fixes + writes regression tests |
| Implementer | `agents/implementer.md` | Implements features from a plan/spec |
| Researcher | `agents/researcher.md` | Explores codebases and docs — research only, no code |

All agents follow delegation rules: can read/write/test, cannot commit/push/architect.

## First Session

If no knowledge files exist yet, suggest running `/onboard` to set up the assistant.
