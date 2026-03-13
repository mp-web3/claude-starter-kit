#!/bin/bash
# pre-compact.sh — PreCompact hook
# Saves volatile state before context compression so it can be re-injected
# by the SessionStart (compact) hook.
#
# Captures: MEMORY.md sections, git state, recently modified files, knowledge file index.
# Does NOT dump full file contents — they're on disk and can be Read when needed.

set -euo pipefail

STATE_DIR="$HOME/.claude/state"
STATE_FILE="$STATE_DIR/pre-compact-state.md"
# date -u works in Git Bash on Windows; use fallback if needed
DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")
KB_DIR="$HOME/.claude/knowledge"

mkdir -p "$STATE_DIR"

# --- Find MEMORY.md (auto-memory path varies by project) ---
MEMORY=""
for f in "$HOME"/.claude/projects/*/memory/MEMORY.md; do
  if [[ -f "$f" ]]; then
    MEMORY="$f"
    break
  fi
done

NEXT_UP=""
ACTIVE=""
if [[ -n "$MEMORY" ]]; then
  NEXT_UP=$(sed -n '/^## Next Up/,/^##/{/^## Next Up/d;/^##/d;p;}' "$MEMORY" 2>/dev/null | head -10)
  ACTIVE=$(sed -n '/^## Active/,/^##/{/^## Active/d;/^##/d;p;}' "$MEMORY" 2>/dev/null | head -20)
fi

# --- Git state ---
GIT_INFO="No git repo"
if git rev-parse --is-inside-work-tree &>/dev/null; then
  BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
  LAST_COMMIT=$(git log -1 --oneline 2>/dev/null || echo "none")
  DIFF_STAT=$(git diff --stat HEAD 2>/dev/null | tail -1)
  GIT_INFO="Branch: ${BRANCH} | Last: ${LAST_COMMIT} | ${DIFF_STAT:-clean}"
fi

# --- Recently modified files ---
RECENT=$(find "${CLAUDE_PROJECT_DIR:-.}" -type f -mmin -30 \
  -not -path '*/.git/*' \
  -not -path '*/node_modules/*' \
  -not -path '*/__pycache__/*' \
  -not -path '*/.venv/*' \
  -not -name '.DS_Store' \
  -not -name '*.pyc' \
  -not -name '*.jsonl' \
  2>/dev/null | head -15 | sort)

# --- Knowledge file index ---
KB_INDEX=""
if [[ -d "$KB_DIR" ]]; then
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    KB_INDEX+="- ${f#$KB_DIR/}
"
  done < <(find "$KB_DIR" -name "*.md" -maxdepth 3 2>/dev/null | sort)
fi

# --- Write state file ---
cat > "$STATE_FILE" << EOF
---
saved: ${DATE}
trigger: pre-compact
---

# Pre-Compaction State

## IMPORTANT
Context was compressed. Knowledge files may not reflect what was discussed before compaction.
Check with the user what was being worked on.

## Next Up (from MEMORY.md)
${NEXT_UP:-Not set.}

## Active State (from MEMORY.md)
${ACTIVE:-Not set.}

## Git
${GIT_INFO}

## Recent Files (last 30 min)
${RECENT:-None detected}

## Knowledge Files Available (read on demand)
${KB_INDEX:-No knowledge files found.}
EOF

echo "Pre-compaction state saved. Read ~/.claude/state/pre-compact-state.md to recover context."
exit 0
