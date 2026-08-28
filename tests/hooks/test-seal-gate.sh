#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

UNDER_TEST="$REPO_ROOT/hooks/seal-gate"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

# make_repo NAME [--no-config] -- a git repo with an SDD workspace; prints its path
make_repo() {
    local repo="$TEST_ROOT/$1"
    mkdir -p "$repo/docs/superpowers/plans" "$repo/.superpowers/sdd/2026-08-28-widget"
    git init -q "$repo"
    touch "$repo/.superpowers/sdd/2026-08-28-widget/progress.md"
    if [ "${2:-}" != "--no-config" ]; then
        mkdir -p "$repo/.dopamine"
        printf 'living: docs/DESIGN.md\nplans: docs/superpowers/plans\n' > "$repo/.dopamine/config"
    fi
    printf '%s\n' "$repo"
}

# event TOOL CWD COMMAND -- prints a PreToolUse event JSON
event() {
    TOOL="$1" CWD="$2" CMD="$3" python3 -c '
import json, os
print(json.dumps({
    "hook_event_name": "PreToolUse",
    "cwd": os.environ["CWD"],
    "tool_name": os.environ["TOOL"],
    "tool_input": {"command": os.environ["CMD"]},
}))'
}

# run_gate REPO EVENT_JSON -- prints stdout, sets RC
run_gate() {
    RC=0
    GATE_OUT=$(printf '%s' "$2" | (cd "$1" && "$UNDER_TEST")) || RC=$?
}

# decision JSON -- prints the permissionDecision, or "none"
decision() {
    printf '%s' "$1" | python3 -c '
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    print("none"); raise SystemExit
try:
    payload = json.loads(raw)
except ValueError:
    print("invalid-json"); raise SystemExit
print(payload.get("hookSpecificOutput", {}).get("permissionDecision", "none"))'
}

repo=$(make_repo gated)
ws=".superpowers/sdd/2026-08-28-widget"
sealed="$repo/docs/superpowers/plans/2026-08-28-widget.ledger.md"

echo "-- events the gate must ignore"
run_gate "$repo" "$(event Read "$repo" "irrelevant")"
assert_eq "a non-Bash tool exits 0" 0 "$RC"
assert_eq "a non-Bash tool produces no decision" "none" "$(decision "$GATE_OUT")"

run_gate "$repo" "$(event Bash "$repo" "npm test")"
assert_eq "an unrelated command produces no decision" "none" "$(decision "$GATE_OUT")"

run_gate "$repo" "$(event Bash "$repo" "ls -la $ws")"
assert_eq "reading the workspace is not deleting it" "none" "$(decision "$GATE_OUT")"

run_gate "$repo" "$(event Bash "$repo" "rm -rf build/")"
assert_eq "deleting something else is not our business" "none" "$(decision "$GATE_OUT")"

echo "-- an unsealed workspace"
run_gate "$repo" "$(event Bash "$repo" "rm -rf $ws")"
assert_eq "the hook still exits 0 — the JSON carries the decision" 0 "$RC"
assert_eq "an unsealed workspace is denied" "deny" "$(decision "$GATE_OUT")"
assert_contains "the reason names the seal command" "$GATE_OUT" "seal-ledger"
assert_contains "the reason names the plan" "$GATE_OUT" "2026-08-28-widget"

run_gate "$repo" "$(event Bash "$repo" "rm -rf '$repo/$ws'")"
assert_eq "an absolute path is denied the same way" "deny" "$(decision "$GATE_OUT")"

echo "-- once the ledger is sealed"
printf '# Sealed ledger — plan: x — sealed: 2026-08-28\n' > "$sealed"
run_gate "$repo" "$(event Bash "$repo" "rm -rf $ws")"
assert_eq "a sealed workspace is allowed" "none" "$(decision "$GATE_OUT")"
assert_eq "and allowed silently" "" "$GATE_OUT"

echo "-- a repository that has not adopted dopamine"
plain=$(make_repo plain --no-config)
run_gate "$plain" "$(event Bash "$plain" "rm -rf $ws")"
assert_eq "no dopamine config means the gate stays inert" "none" "$(decision "$GATE_OUT")"

echo "-- degraded environments"
run_gate "$repo" "not json at all"
assert_eq "unparseable input exits 0 rather than blocking the session" 0 "$RC"

RC=0
# Resolve bash to an absolute path before breaking PATH: `env PATH=/nonexistent
# bash ...` would otherwise fail to find "bash" itself (env resolves the command
# via the *new* PATH), never reaching the script under test.
BASH_BIN=$(command -v bash)
out=$(printf '%s' "$(event Bash "$repo" "rm -rf $ws")" \
    | (cd "$repo" && env PATH=/nonexistent "$BASH_BIN" "$UNDER_TEST") 2>&1) || RC=$?
assert_eq "with no Python interpreter the gate exits 0, not non-zero" 0 "$RC"
assert_contains "and says so on stderr" "$out" "inactive"

echo "-- hooks.json wiring"
wiring=$(ROOT="$REPO_ROOT" python3 -c '
import json, os
with open(os.environ["ROOT"] + "/hooks/hooks.json", encoding="utf-8") as fh:
    cfg = json.load(fh)["hooks"]
pre = cfg["PreToolUse"][0]
print(pre["matcher"])
print(pre["hooks"][0]["command"])
print(",".join(sorted(cfg)))')
assert_contains "PreToolUse matches Bash" "$wiring" "Bash"
assert_contains "PreToolUse runs the seal gate" "$wiring" "seal-gate"
assert_contains "SessionStart is wired too" "$wiring" "SessionStart"

finish
