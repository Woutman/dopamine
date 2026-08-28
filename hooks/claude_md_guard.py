#!/usr/bin/env python3
"""PostToolUse guard: after an edit to an instructions-tier file, return the
admission test as additionalContext.

The hook renders no verdict, because a verdict is a judgement and this is a
shell-invoked script. It reports what a script can know for certain — the file's
length against the 200-line target, what this working tree adds and removes since
HEAD, and which path holds the lessons tier — and hands the judgement to the
agent, pointed at dopamine:claude-md-guard. superpowers:writing-skills draws that
line explicitly: automate the mechanical constraint, save documentation for the
judgement call.

Silent no-op unless all of these hold:
  * the tool call carries a tool_input.file_path,
  * a repository root resolves from the event's cwd,
  * .dopamine/config declares at least one `instructions:` path,
  * and the edited file is one of them.

Why additionalContext rather than a warning or a block: a hook that exits 0 sends
stderr to the debug log only and Claude never sees it, so a plain warning changes
nothing; exit 2 shows stderr to Claude framed as a blocking error, which an
admission test is not. additionalContext arrives beside the tool result with no
error framing. Escalation to exit 2 remains available if it proves ignorable.

Known gap, accepted: Claude Code does not fire a PostToolUse hook matching
Edit|Write when a Bash command rewrites the same file, so `cat >> CLAUDE.md`
bypasses this guard. The sweep's own draining of the instructions tier is the
backstop for that path.
"""

import json
import os
import subprocess
import sys

TARGET_LINES = 200
CONTEXT_FILE = "claude-md-guard-context.md"


def read_event():
    try:
        return json.load(sys.stdin)
    except (ValueError, OSError):
        return None


def repo_root(cwd):
    try:
        result = subprocess.run(
            ["git", "-C", cwd, "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    root = result.stdout.strip()
    return root or None


def declared(root, tier):
    """Every path declared for one tier in .dopamine/config, repo-relative.

    An empty list means this repository has not adopted dopamine, or has not
    declared that tier, and the guard stays inert either way.
    """
    config = os.path.join(root, ".dopamine", "config")
    paths = []
    try:
        with open(config, encoding="utf-8") as handle:
            for raw in handle:
                line = raw.split("#", 1)[0].strip()
                if ":" not in line:
                    continue
                name, _, path = line.partition(":")
                if name.strip() == tier and path.strip():
                    paths.append(path.strip())
    except OSError:
        return []
    return paths


def same_file(a, b):
    return os.path.normcase(os.path.realpath(a)) == os.path.normcase(os.path.realpath(b))


def line_count(path):
    try:
        with open(path, "rb") as handle:
            return sum(1 for _ in handle)
    except OSError:
        return None


def worktree_delta(root, relpath):
    """(added, removed) for this path against HEAD, or None if git cannot say."""
    try:
        result = subprocess.run(
            ["git", "-C", root, "diff", "HEAD", "--numstat", "--", relpath],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if result.returncode != 0:
        return None
    for row in result.stdout.splitlines():
        parts = row.split("\t")
        # A binary file reports "-" for both counts; only digits are usable.
        if len(parts) >= 3 and parts[0].isdigit() and parts[1].isdigit():
            return int(parts[0]), int(parts[1])
    return None


def facts(root, relpath, abspath):
    lines = line_count(abspath)
    if lines is None:
        return None
    sentence = "`{path}` is {lines} lines against the {target}-line target".format(
        path=relpath, lines=lines, target=TARGET_LINES
    )
    delta = worktree_delta(root, relpath)
    if delta is not None and (delta[0] or delta[1]):
        sentence += "; this working tree adds {a} and removes {r} since HEAD".format(
            a=delta[0], r=delta[1]
        )
    sentence += "."
    lessons = declared(root, "lessons")
    if lessons:
        sentence += " The lessons tier here is `{path}`.".format(path=lessons[0])
    return sentence


def context_text():
    here = os.path.dirname(os.path.abspath(__file__))
    try:
        with open(os.path.join(here, CONTEXT_FILE), encoding="utf-8") as handle:
            return handle.read().strip()
    except OSError:
        return None


def emit(context):
    """Claude Code reads the nested shape; other hosts read the flat one.

    No Cursor-specific PostToolUse field name is documented, so Cursor receives
    the flat shape rather than an invented one.
    """
    if os.environ.get("CLAUDE_PLUGIN_ROOT") and not os.environ.get("COPILOT_CLI"):
        payload = {
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "additionalContext": context,
            }
        }
    else:
        payload = {"additionalContext": context}
    json.dump(payload, sys.stdout)
    sys.stdout.write("\n")


def main():
    event = read_event()
    if not isinstance(event, dict):
        return 0

    tool_input = event.get("tool_input")
    if not isinstance(tool_input, dict):
        return 0
    file_path = tool_input.get("file_path")
    if not isinstance(file_path, str) or not file_path:
        return 0

    root = repo_root(event.get("cwd") or os.getcwd())
    if root is None:
        return 0

    for relpath in declared(root, "instructions"):
        candidate = os.path.join(root, relpath)
        if not same_file(candidate, file_path):
            continue
        body = context_text()
        if body is None:
            return 0
        line = facts(root, relpath, candidate)
        emit(line + "\n\n" + body if line else body)
        return 0

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:  # a hook that cannot run must not break the session
        sys.exit(0)
