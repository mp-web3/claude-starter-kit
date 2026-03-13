#!/bin/bash
set -euo pipefail

# Claude Code Starter Kit — Setup Script
# Checks/installs dependencies, copies template files to ~/.claude/, personalizes them.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "=== Claude Code Starter Kit ==="
echo ""

# -----------------------------------------------
# Step 1: Detect OS and package manager
# -----------------------------------------------

OS="unknown"
PKG_INSTALL=""

case "$(uname -s)" in
    Darwin)
        OS="macos"
        if command -v brew >/dev/null 2>&1; then
            PKG_INSTALL="brew install"
        fi
        ;;
    Linux)
        OS="linux"
        if command -v apt-get >/dev/null 2>&1; then
            PKG_INSTALL="sudo apt-get install -y"
        elif command -v dnf >/dev/null 2>&1; then
            PKG_INSTALL="sudo dnf install -y"
        elif command -v pacman >/dev/null 2>&1; then
            PKG_INSTALL="sudo pacman -S --noconfirm"
        fi
        ;;
    MINGW*|MSYS*|CYGWIN*)
        OS="windows"
        # On Windows/Git Bash, most deps are installed externally (winget, scoop, choco)
        if command -v scoop >/dev/null 2>&1; then
            PKG_INSTALL="scoop install"
        elif command -v choco >/dev/null 2>&1; then
            PKG_INSTALL="choco install -y"
        fi
        ;;
esac

echo "Detected: $OS"
echo ""

install_with_prompt() {
    local name="$1"
    local pkg="${2:-$1}"
    local install_cmd="${3:-}"

    if [[ -z "$install_cmd" && -z "$PKG_INSTALL" ]]; then
        echo "  ✗ $name — not found. Install it manually and re-run setup."
        return 1
    fi

    local cmd="${install_cmd:-$PKG_INSTALL $pkg}"
    read -p "  Install $name? ($cmd) [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        eval "$cmd"
        return $?
    else
        echo "  Skipped $name."
        return 1
    fi
}

# -----------------------------------------------
# Step 2: Check and install dependencies
# -----------------------------------------------

echo "Checking dependencies..."
echo ""
MISSING=0

# --- Homebrew (macOS only) ---
if [[ "$OS" == "macos" ]] && ! command -v brew >/dev/null 2>&1; then
    echo "  ✗ Homebrew — not found (needed to install other tools on macOS)"
    read -p "  Install Homebrew? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Add to PATH for this session
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
        PKG_INSTALL="brew install"
    else
        echo "  Without Homebrew, you'll need to install dependencies manually."
    fi
fi

# --- Git ---
if command -v git >/dev/null 2>&1; then
    echo "  ✓ git ($(git --version | head -c 20))"
else
    echo "  ✗ git — not found"
    install_with_prompt "git" || MISSING=1
fi

# --- Python 3 ---
# On Windows, python3 may be a Microsoft Store stub that doesn't actually work.
# Test that the command actually runs successfully.
PYTHON3=""
if python3 --version >/dev/null 2>&1; then
    PYTHON3="python3"
elif python --version 2>&1 | grep -q "Python 3"; then
    PYTHON3="python"
fi

if [[ -n "$PYTHON3" ]]; then
    PY_VER=$($PYTHON3 --version 2>&1)
    echo "  ✓ $PYTHON3 ($PY_VER)"
else
    echo "  ✗ python3 — not found (needed for security guard and task database)"
    install_with_prompt "python3" "python3" || MISSING=1
fi

# --- jq ---
if command -v jq >/dev/null 2>&1; then
    echo "  ✓ jq ($(jq --version 2>&1))"
else
    echo "  ✗ jq — not found (needed for statusline and hooks)"
    install_with_prompt "jq" || MISSING=1
fi

# --- trash (safe rm replacement) ---
if command -v trash >/dev/null 2>&1 || command -v trash-put >/dev/null 2>&1; then
    echo "  ✓ trash"
elif [[ "$OS" == "macos" ]]; then
    echo "  ✗ trash — not found (safe alternative to rm -rf, moves to Trash)"
    install_with_prompt "trash" "trash" || true
elif [[ "$OS" == "linux" ]]; then
    echo "  ✗ trash-cli — not found (safe alternative to rm -rf)"
    install_with_prompt "trash-cli" "trash-cli" || true
elif [[ "$OS" == "windows" ]]; then
    echo "  ⚠ trash — not found (optional; install via: npm install -g trash-cli)"
fi

# --- Claude Code CLI ---
if command -v claude >/dev/null 2>&1; then
    echo "  ✓ claude CLI"
else
    echo "  ✗ Claude Code CLI — not found"
    if command -v npm >/dev/null 2>&1; then
        install_with_prompt "claude" "" "npm install -g @anthropic-ai/claude-code" || MISSING=1
    elif command -v brew >/dev/null 2>&1; then
        install_with_prompt "claude" "" "brew install claude-code" || MISSING=1
    else
        echo "    Install Node.js first, then: npm install -g @anthropic-ai/claude-code"
        echo "    Or see: https://docs.anthropic.com/en/docs/claude-code"
        MISSING=1
    fi
fi

echo ""

if [[ $MISSING -eq 1 ]]; then
    echo "Some required tools are missing. Install them and re-run ./setup.sh"
    exit 1
fi

echo "All dependencies OK."
echo ""

# -----------------------------------------------
# Step 3: Check for existing config
# -----------------------------------------------

if [[ -f "$CLAUDE_DIR/settings.json" ]]; then
    echo "Warning: ~/.claude/settings.json already exists."
    read -p "Overwrite? This will replace your current config. (y/N) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
fi

# -----------------------------------------------
# Step 4: Personalize
# -----------------------------------------------

echo "Let's personalize your assistant."
echo ""
read -p "Your first name: " USER_NAME
read -p "One-line bio (e.g., 'Python dev, building SaaS tools'): " USER_BIO

if [[ -z "$USER_NAME" || ${#USER_NAME} -lt 2 ]]; then
    echo "Error: name is required (at least 2 characters)"
    exit 1
fi

echo ""
echo "Setting up ~/.claude/ ..."

# -----------------------------------------------
# Step 5: Copy files
# -----------------------------------------------

# Create directory structure
mkdir -p "$CLAUDE_DIR"/{rules,scripts,agents,knowledge/self,knowledge/user,knowledge/problems,knowledge/projects,skills/onboard,skills/tasks,skills/plan-and-implement,skills/reflect,state/sessions}

# --- Copy scripts ---
cp "$SCRIPT_DIR/scripts/global-guard.py" "$CLAUDE_DIR/scripts/"
cp "$SCRIPT_DIR/scripts/pre-compact.sh" "$CLAUDE_DIR/scripts/"
cp "$SCRIPT_DIR/scripts/session-save-reminder.sh" "$CLAUDE_DIR/scripts/"
cp "$SCRIPT_DIR/scripts/db.py" "$CLAUDE_DIR/scripts/"
cp "$SCRIPT_DIR/scripts/extract-learnings.py" "$CLAUDE_DIR/scripts/"
chmod +x "$CLAUDE_DIR/scripts/"*.sh "$CLAUDE_DIR/scripts/"*.py

# --- Copy rules ---
for rule in "$SCRIPT_DIR"/rules/*.md; do
    cp "$rule" "$CLAUDE_DIR/rules/"
done

# --- Copy agents ---
for agent in "$SCRIPT_DIR"/agents/*.md; do
    cp "$agent" "$CLAUDE_DIR/agents/"
done

# --- Copy skills ---
cp "$SCRIPT_DIR/skills/onboard/SKILL.md" "$CLAUDE_DIR/skills/onboard/"
cp "$SCRIPT_DIR/skills/tasks/SKILL.md" "$CLAUDE_DIR/skills/tasks/"
cp "$SCRIPT_DIR/skills/plan-and-implement/SKILL.md" "$CLAUDE_DIR/skills/plan-and-implement/"
cp "$SCRIPT_DIR/skills/plan-and-implement/LEARNINGS.md" "$CLAUDE_DIR/skills/plan-and-implement/"
cp "$SCRIPT_DIR/skills/reflect/SKILL.md" "$CLAUDE_DIR/skills/reflect/"
cp "$SCRIPT_DIR/skills/reflect/LEARNINGS.md" "$CLAUDE_DIR/skills/reflect/"

# --- Copy statusline ---
cp "$SCRIPT_DIR/statusline.sh" "$CLAUDE_DIR/"
chmod +x "$CLAUDE_DIR/statusline.sh"

# --- Copy settings.json ---
cp "$SCRIPT_DIR/templates/settings.json" "$CLAUDE_DIR/settings.json"

# --- Copy .gitignore ---
cp "$SCRIPT_DIR/templates/gitignore" "$CLAUDE_DIR/.gitignore"

# --- Generate CLAUDE.md from template ---
sed -e "s/{{USER_NAME}}/$USER_NAME/g" \
    -e "s|{{USER_BIO}}|$USER_BIO|g" \
    "$SCRIPT_DIR/templates/CLAUDE.md" > "$CLAUDE_DIR/CLAUDE.md"

# --- Initialize task database and export backlog ---
${PYTHON3:-python3} "$CLAUDE_DIR/scripts/db.py" init
${PYTHON3:-python3} "$CLAUDE_DIR/scripts/db.py" export

# --- Create starter MEMORY.md ---
cat > "$CLAUDE_DIR/MEMORY.md" << 'MEMEOF'
# Auto-Memory

## Active Tasks

(Run `/tasks` or `/onboard` to populate)

## Active Projects

(Will grow as you work on projects)

## Next Up

1. Run `/onboard` to set up your profile, problems, goals, and tasks

## File Map

| Path | Content |
|---|---|
| `knowledge/user/profile.md` | Your profile (created by /onboard) |
| `knowledge/user/goals.md` | Goals and subgoals (created by /onboard) |
| `knowledge/problems/00-overview.md` | 12 problems overview (created by /onboard) |
| `knowledge/self/identity.md` | AI self-knowledge (created by /onboard) |
MEMEOF

# -----------------------------------------------
# Step 6: Initialize git repo
# -----------------------------------------------

if [[ ! -d "$CLAUDE_DIR/.git" ]]; then
    cd "$CLAUDE_DIR"
    git init
    git add \
        CLAUDE.md MEMORY.md settings.json statusline.sh .gitignore \
        rules/ agents/ scripts/ skills/ state/backlog.md \
        knowledge/
    git commit -m "initial setup from claude-starter-kit"
    echo ""
    echo "Git repo initialized at ~/.claude/"
    echo "To back up your config, create a private repo and run:"
    echo "  cd ~/.claude && git remote add origin git@github.com:YOUR_USERNAME/claude-config.git && git push -u origin main"
fi

# -----------------------------------------------
# Done
# -----------------------------------------------

echo ""
echo "=== Setup complete ==="
echo ""
echo "Files installed:"
echo "  ~/.claude/CLAUDE.md          — global instructions"
echo "  ~/.claude/MEMORY.md          — cross-session index (first 200 lines auto-loaded)"
echo "  ~/.claude/settings.json      — hooks + security"
echo "  ~/.claude/rules/             — session, workflow, handoff, task, delegation, development rules"
echo "  ~/.claude/agents/            — code-reviewer, bug-fixer, implementer, researcher"
echo "  ~/.claude/scripts/           — security guard, pre-compact, reminders, db, learning extractor"
echo "  ~/.claude/skills/onboard/    — guided first-session setup"
echo "  ~/.claude/skills/tasks/      — task management (/tasks)"
echo "  ~/.claude/skills/plan-and-implement/ — structured build workflow (/plan)"
echo "  ~/.claude/skills/reflect/    — session learning extraction (/reflect)"
echo "  ~/.claude/tasks.db           — SQLite task store"
echo "  ~/.claude/knowledge/         — your assistant's growing brain"
echo "  ~/.claude/statusline.sh      — context/cost display"
echo ""
echo "=== Next: Start your first session ==="
echo ""
echo "  cd ~/.claude"
echo "  claude"
echo ""
echo "Then type:"
echo "  /onboard"
echo ""
echo "This will walk you through a 20-30 minute guided setup:"
echo "  1. Build your user profile"
echo "  2. Define your 12 Favorite Problems (Feynman method)"
echo "  3. Set your end goal and subgoals"
echo "  4. Create initial tasks"
echo "  5. Set up the AI's self-knowledge"
echo ""
echo "You can pause anytime and resume later with: /onboard resume"
echo ""
