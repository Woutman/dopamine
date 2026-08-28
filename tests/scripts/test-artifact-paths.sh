#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

UNDER_TEST="$REPO_ROOT/skills/sweep/scripts/artifact-paths"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

# make_repo NAME -- writes .dopamine/config from stdin, prints the repo path
make_repo() {
    local repo="$TEST_ROOT/$1"
    mkdir -p "$repo/.dopamine"
    cat > "$repo/.dopamine/config"
    printf '%s\n' "$repo"
}

echo "-- no config at all"
bare="$TEST_ROOT/bare"
mkdir -p "$bare"
out=$("$UNDER_TEST" "$bare" 2>&1) && rc=0 || rc=$?
assert_eq "exits 3 when the repo has no dopamine config" 3 "$rc"
assert_contains "names the config path it looked for" "$out" ".dopamine/config"

echo "-- a declared document that exists, and one that does not"
repo=$(make_repo present <<'CONFIG'
# dopamine configuration
living: docs/DESIGN.md
living: docs/ARCHITECTURE.md

instructions: CLAUDE.md      # highest read frequency
lessons: docs/LESSONS.md
plans: docs/superpowers/plans
CONFIG
)
mkdir -p "$repo/docs/superpowers/plans"
touch "$repo/docs/DESIGN.md" "$repo/CLAUDE.md" "$repo/docs/LESSONS.md"
out=$("$UNDER_TEST" "$repo") && rc=0 || rc=$?
assert_eq "exits 0 with a valid config" 0 "$rc"
assert_contains "reports an existing living document present" "$out" \
    "$(printf 'living\tdocs/DESIGN.md\tpresent')"
assert_contains "reports a declared-but-absent document absent, not as an error" "$out" \
    "$(printf 'living\tdocs/ARCHITECTURE.md\tabsent')"
assert_contains "reports the instructions tier" "$out" \
    "$(printf 'instructions\tCLAUDE.md\tpresent')"
assert_contains "reports the plans directory" "$out" \
    "$(printf 'plans\tdocs/superpowers/plans\tpresent')"
assert_eq "emits one row per declared path" 5 "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"

echo "-- comments and blank lines are not paths"
assert_not_contains "strips trailing comments from a value" "$out" "highest read frequency"

echo "-- tier filter"
out=$("$UNDER_TEST" --tier plans "$repo")
assert_eq "--tier returns only that tier" \
    "$(printf 'plans\tdocs/superpowers/plans\tpresent')" "$out"

echo "-- malformed configs"
repo=$(make_repo unknown_tier <<'CONFIG'
living: docs/DESIGN.md
evidence: docs/EVIDENCE.md
CONFIG
)
out=$("$UNDER_TEST" "$repo" 2>&1) && rc=0 || rc=$?
assert_eq "exits 2 on an unknown tier" 2 "$rc"
assert_contains "names the offending line number" "$out" ":2:"
assert_contains "names the offending tier" "$out" "evidence"

repo=$(make_repo not_a_pair <<'CONFIG'
docs/DESIGN.md
CONFIG
)
assert_exit "exits 2 on a line that is not 'tier: path'" 2 "$UNDER_TEST" "$repo"

repo=$(make_repo absolute <<'CONFIG'
living: /etc/passwd
CONFIG
)
out=$("$UNDER_TEST" "$repo" 2>&1) && rc=0 || rc=$?
assert_eq "exits 2 on an absolute path" 2 "$rc"
assert_contains "says paths are relative to the repo root" "$out" "relative to the repo root"

repo=$(make_repo traversal <<'CONFIG'
living: ../elsewhere/DESIGN.md
CONFIG
)
assert_exit "exits 2 on a path containing .." 2 "$UNDER_TEST" "$repo"

repo=$(make_repo empty <<'CONFIG'
# nothing but a comment
CONFIG
)
assert_exit "exits 2 on a config that declares no paths" 2 "$UNDER_TEST" "$repo"

finish
