#!/usr/bin/env bash
# The spine as one mechanism: config, injection, skill.
#
# What is left of the spine after the hooks and scripts came out is a chain of
# names: a repository declares .dopamine/config, the SessionStart hook notices
# and injects, the injection names dopamine:finishing-work, and that skill names
# the three skills it delegates to. Every unit test here reads one file by its
# own path, so all of them keep passing after a rename that leaves the shipped
# plugin pointing at nothing. This file is what catches that.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

repo="$TEST_ROOT/project"
mkdir -p "$repo/.dopamine" "$repo/docs/superpowers/plans"
git init -q "$repo"
printf 'living: docs/DESIGN.md\ninstructions: CLAUDE.md\nplans: docs/superpowers/plans\n' \
    > "$repo/.dopamine/config"

echo "-- an adopted repository gets the injection"
out=$( (cd "$repo" && CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$REPO_ROOT/hooks/session-start") )
ctx=$(printf '%s' "$out" | python3 -c '
import json, sys
raw = sys.stdin.read().strip()
print(json.loads(raw)["hookSpecificOutput"]["additionalContext"] if raw else "")')
assert_contains "the injection arrived" "$ctx" "living document"

echo "-- the injection names skills that exist"
unresolved=""
while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    [ -f "$REPO_ROOT/skills/$ref/SKILL.md" ] || unresolved="$unresolved $ref"
done < <(printf '%s' "$ctx" | grep -oE 'dopamine:[a-z][a-z-]*' | sed 's/^dopamine://' | sort -u)
if [ -z "$unresolved" ]; then
    pass "every skill the injection names resolves"
else
    fail "every skill the injection names resolves" "unresolved:$unresolved"
fi
assert_contains "it names the skill that closes a unit of work" \
    "$ctx" "dopamine:finishing-work"

echo "-- and that skill names the three it delegates to"
fw=$(cat "$REPO_ROOT/skills/finishing-work/SKILL.md")
for dep in routing-documentation-updates writing-living-documents writing-claude-md; do
    assert_contains "finishing-work reaches dopamine:$dep" "$fw" "dopamine:$dep"
    assert_eq "and dopamine:$dep exists" "yes" \
        "$([ -f "$REPO_ROOT/skills/$dep/SKILL.md" ] && echo yes || echo no)"
done

echo "-- the sweep's own record is the sealed ledger, and nothing beside it"
assert_contains "sealing is a copy the recipe spells out" "$fw" "cp .superpowers/sdd/"
assert_contains "the commit prefix that makes sweeps greppable is stated" \
    "$fw" "git log --grep='^sweep:'"

echo "-- an unadopted repository is silent"
plain="$TEST_ROOT/plain"
mkdir -p "$plain"
git init -q "$plain"
RC=0
out=$( (cd "$plain" && CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$REPO_ROOT/hooks/session-start") ) || RC=$?
assert_eq "exits 0" 0 "$RC"
assert_eq "and injects nothing" "" "$out"

finish
