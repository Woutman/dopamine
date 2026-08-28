#!/usr/bin/env bash
# The spine as one mechanism: config, gate, seal, package.
#
# Each unit is tested on its own elsewhere. What this file checks is the
# handover between them — that the filename seal-ledger writes is the filename
# the gate looks for, and that the gate's answer actually changes when it does.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

SEAL="$REPO_ROOT/skills/sweep/scripts/seal-ledger"
PACKAGE="$REPO_ROOT/skills/sweep/scripts/sweep-package"
GATE="$REPO_ROOT/hooks/seal-gate"

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

repo="$TEST_ROOT/project"
mkdir -p "$repo/docs/superpowers/plans" "$repo/src" "$repo/.dopamine"
git init -q "$repo"
git -C "$repo" config user.email dev@example.com
git -C "$repo" config user.name "Dev"

printf 'living: docs/DESIGN.md\nliving: docs/ARCHITECTURE.md\nlessons: docs/LESSONS.md\nplans: docs/superpowers/plans\n' \
    > "$repo/.dopamine/config"
plan="$repo/docs/superpowers/plans/2026-08-28-widget.md"
printf '# Widget plan\n' > "$plan"
printf 'The widget is synchronous.\n' > "$repo/docs/DESIGN.md"
printf 'no lessons yet\n' > "$repo/docs/LESSONS.md"
printf 'def widget(): pass\n' > "$repo/src/widget.py"
git -C "$repo" add -A
git -C "$repo" commit -qm "before"
BASE=$(git -C "$repo" rev-parse HEAD)

# The unit of work: code changed, and so did a living document.
printf 'The widget is asynchronous.\n' > "$repo/docs/DESIGN.md"
printf 'def widget(): await go()  # SOURCE_ONLY\n' > "$repo/src/widget.py"
git -C "$repo" add -A
git -C "$repo" commit -qm "make the widget async"
HEAD_REV=$(git -C "$repo" rev-parse HEAD)

# superpowers' workspace and ledger, as subagent-driven-development leaves them.
ws="$repo/.superpowers/sdd/2026-08-28-widget"
mkdir -p "$ws"
{
    printf '# SDD ledger — plan: docs/superpowers/plans/2026-08-28-widget.md\n\n'
    printf 'Task 1: complete — %s\n' "$(git -C "$repo" rev-parse --short HEAD)"
    printf 'Ruling: made the widget async — the sync call blocked the batch — costs a caller migration if wrong\n'
} > "$ws/progress.md"

gate_decision() {
    CWD="$repo" CMD="$1" python3 -c '
import json, os
print(json.dumps({"hook_event_name": "PreToolUse", "cwd": os.environ["CWD"],
                  "tool_name": "Bash", "tool_input": {"command": os.environ["CMD"]}}))' \
    | (cd "$repo" && "$GATE") | python3 -c '
import json, sys
raw = sys.stdin.read().strip()
print(json.loads(raw)["hookSpecificOutput"]["permissionDecision"] if raw else "none")'
}

echo "-- before sealing"
assert_eq "the gate denies deleting an unsealed workspace" \
    "deny" "$(gate_decision "rm -rf .superpowers/sdd/2026-08-28-widget")"

echo "-- sealing"
out=$("$SEAL" "$plan") && rc=0 || rc=$?
assert_eq "seal-ledger succeeds" 0 "$rc"
sealed="$repo/docs/superpowers/plans/2026-08-28-widget.ledger.md"
assert_eq "the sealed ledger lands where the gate looks for it" \
    "yes" "$([ -f "$sealed" ] && echo yes || echo no)"
assert_contains "and it carries the ruling that would otherwise have died" \
    "$(cat "$sealed")" "the sync call blocked the batch"

echo "-- after sealing"
assert_eq "the same deletion now passes" \
    "none" "$(gate_decision "rm -rf .superpowers/sdd/2026-08-28-widget")"

echo "-- the sweep's input"
out=$("$PACKAGE" "$plan" "$BASE" "$HEAD_REV") && rc=0 || rc=$?
assert_eq "sweep-package succeeds" 0 "$rc"
pkg=${out#wrote }
pkg=${pkg%% (*}
body=$(cat "$pkg")
assert_contains "the package carries the living document's change" "$body" "asynchronous"
assert_not_contains "and not the source file the sweep does not own" "$body" "SOURCE_ONLY"

echo "-- the ledger outlived the workspace"
rm -rf "$ws"
assert_eq "the sealed copy survives workspace deletion" \
    "yes" "$([ -f "$sealed" ] && echo yes || echo no)"

finish
