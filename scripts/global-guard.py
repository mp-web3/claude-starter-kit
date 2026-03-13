#!/usr/bin/env python3
"""global-guard.py — Security guard for Claude Code.

Defense-in-depth: secrets protection, path boundaries, destructive command checks.
Blocks writes outside $HOME, secrets access, force-push, rm -rf.

Receives JSON on stdin: { "tool_name": "...", "tool_input": { ... } }
Exit 0 = allow, Exit 2 = block (stderr shown to user)
"""

import json
import os
import re
import shlex
import sys
from pathlib import Path

HOME_DIR = str(Path.home())
IS_WINDOWS = sys.platform == "win32" or os.name == "nt"

SECRETS_RE = re.compile(r"\.(env|key|pem|secret|keystore)$|\.env\.", re.IGNORECASE)

if IS_WINDOWS:
    # On Windows/Git Bash, /tmp may map to a system temp dir; also allow the real temp path
    _tmp_dirs = [
        str(Path(os.environ.get("TEMP", "")).resolve()) if os.environ.get("TEMP") else None,
        str(Path(os.environ.get("TMP", "")).resolve()) if os.environ.get("TMP") else None,
    ]
    WRITABLE_ROOTS = [HOME_DIR] + [d for d in _tmp_dirs if d]
    READABLE_ROOTS = WRITABLE_ROOTS + [
        str(Path(os.environ.get("PROGRAMFILES", "C:\\Program Files")).resolve()),
    ]
else:
    WRITABLE_ROOTS = [HOME_DIR, str(Path("/tmp").resolve()), str(Path("/var/tmp").resolve())]
    READABLE_ROOTS = WRITABLE_ROOTS + [str(Path("/usr/local").resolve()), str(Path("/opt/homebrew").resolve())]

PASSTHROUGH_TOOLS = {
    "WebSearch", "WebFetch", "AskUserQuestion",
    "TaskCreate", "TaskUpdate", "TaskList", "TaskGet",
}

READ_CMDS = {"cat", "head", "tail", "less", "more", "bat", "sed", "awk", "grep"}
DESTRUCTIVE_CMDS = {"rm", "rmdir", "mv", "cp", "touch", "mkdir", "chmod", "chown", "ln"}

SHELL_OP_RE = re.compile(r"\s*(?:&&|\|\||[;|])\s*")


def block(tool: str, reason: str) -> None:
    print(reason, file=sys.stderr)
    sys.exit(2)


def resolve(p: str) -> str:
    return str(Path(os.path.expanduser(p)).resolve())


def inside(path: str, roots: list) -> bool:
    r = resolve(path)
    sep = os.sep
    return any(r == root or r.startswith(root + sep) for root in roots)


def is_secrets(p: str) -> bool:
    return bool(SECRETS_RE.search(os.path.basename(p)))


def tokenize(cmd: str) -> list:
    try:
        return shlex.split(cmd)
    except ValueError:
        return cmd.split()


def looks_like_path(token: str) -> bool:
    return token.startswith("/") or token.startswith("~") or token.startswith(".")


def check_bash(tool: str, cmd: str) -> None:
    if re.search(r"git\s+push\s+.*(-f\b|--force\b)", cmd):
        block(tool, "SECURITY: Force-push is blocked")

    if re.search(r"git\s+add\s", cmd):
        if re.search(r"\.(env|key|pem|secret|keystore)\b|\.env\.", cmd, re.IGNORECASE):
            block(tool, "SECURITY: Cannot stage secrets files")

    for m in re.finditer(r">{1,2}\s*(/[^\s;|&>]+)", cmd):
        target = m.group(1)
        if target != "/dev/null" and not inside(target, WRITABLE_ROOTS):
            block(tool, f"BOUNDARY: Redirect targets outside allowed directories: {cmd}")

    for subcmd in SHELL_OP_RE.split(cmd):
        subcmd = subcmd.strip()
        if not subcmd:
            continue

        tokens = tokenize(subcmd)
        if not tokens:
            continue

        cmd_idx = 0
        for i, t in enumerate(tokens):
            if "=" in t and not t.startswith("-") and t.index("=") > 0:
                continue
            cmd_idx = i
            break

        command = tokens[cmd_idx] if cmd_idx < len(tokens) else ""
        args = tokens[cmd_idx + 1:]

        if command in READ_CMDS:
            for arg in args:
                if arg.startswith("-"):
                    continue
                if looks_like_path(arg):
                    if not inside(arg, READABLE_ROOTS):
                        block(tool, f"BOUNDARY: Shell read targets outside allowed directories: {cmd}")
                    if is_secrets(arg):
                        block(tool, "SECURITY: Cannot read secrets files via shell commands")

        if command in DESTRUCTIVE_CMDS:
            for arg in args:
                if arg.startswith("-"):
                    continue
                if looks_like_path(arg):
                    if not inside(arg, WRITABLE_ROOTS):
                        block(tool, f"BOUNDARY: Destructive command targets outside allowed directories: {cmd}")

        if command == "tee":
            for arg in args:
                if arg.startswith("-"):
                    continue
                if looks_like_path(arg):
                    if not inside(arg, WRITABLE_ROOTS):
                        block(tool, f"BOUNDARY: tee targets outside allowed directories: {cmd}")


def main() -> None:
    raw = sys.stdin.read()
    try:
        data = json.loads(raw)
    except (json.JSONDecodeError, TypeError):
        sys.exit(0)

    tool = data.get("tool_name", "")
    inp = data.get("tool_input", {})

    if tool in PASSTHROUGH_TOOLS or tool.startswith("mcp__"):
        sys.exit(0)

    if tool in ("Grep", "Glob"):
        p = inp.get("path", "")
        if p and not inside(p, READABLE_ROOTS):
            block(tool, f"BOUNDARY: Search outside allowed directories: {p}")
        sys.exit(0)

    if tool == "Read":
        p = inp.get("file_path", "")
        if p:
            if not inside(p, READABLE_ROOTS):
                block(tool, f"BOUNDARY: Read outside allowed directories: {p}")
            if is_secrets(p):
                block(tool, f"SECURITY: Cannot read secrets file: {os.path.basename(p)}")
        sys.exit(0)

    if tool in ("Write", "Edit"):
        p = inp.get("file_path", "")
        if p:
            if not inside(p, WRITABLE_ROOTS):
                block(tool, f"BOUNDARY: Write outside allowed directories: {p}")
            if is_secrets(p):
                block(tool, f"SECURITY: Cannot write secrets file: {os.path.basename(p)}")
        sys.exit(0)

    if tool == "Bash":
        cmd = inp.get("command", "")
        if cmd:
            check_bash(tool, cmd)
        sys.exit(0)

    sys.exit(0)


if __name__ == "__main__":
    main()
