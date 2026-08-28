#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

UNDER_TEST="$REPO_ROOT/skills/sweep/scripts/sweep-package"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

# A repo with one commit before and one commit after, touching both a declared
# living document and an undeclared source file.
repo="$TEST_ROOT/repo"
mkdir -p "$repo/docs/superpowers/plans" "$repo/src"
git init -q "$repo"
git -C "$repo" config user.email dev@example.com
git -C "$repo" config user.name "Dev"

mkdir -p "$repo/.dopamine"
printf 'living: docs/DESIGN.md\nlessons: docs/LESSONS.md\nplans: docs/superpowers/plans\n' \
    > "$repo/.dopamine/config"
printf '# A plan\n' > "$repo/docs/superpowers/plans/2026-08-28-widget.md"
printf 'The widget is synchronous.\n' > "$repo/docs/DESIGN.md"
printf 'no lessons yet\n' > "$repo/docs/LESSONS.md"
printf 'def widget(): pass\n' > "$repo/src/widget.py"
git -C "$repo" add -A
git -C "$repo" commit -qm "before"
BASE=$(git -C "$repo" rev-parse HEAD)

printf 'The widget is asynchronous.\n' > "$repo/docs/DESIGN.md"
printf 'def widget(): await go()  # UNDECLARED_MARKER\n' > "$repo/src/widget.py"
printf '# A plan\n\nTask 1 done.  # PLAN_MARKER\n' > "$repo/docs/superpowers/plans/2026-08-28-widget.md"
git -C "$repo" add -A
git -C "$repo" commit -qm "after: make the widget async"
HEAD_REV=$(git -C "$repo" rev-parse HEAD)

plan="$repo/docs/superpowers/plans/2026-08-28-widget.md"

echo "-- usage and bad revisions"
assert_exit "exits 2 with too few arguments" 2 "$UNDER_TEST" "$plan" "$BASE"
assert_exit "exits 2 on a bad BASE" 2 "$UNDER_TEST" "$plan" nosuchrev "$HEAD_REV"
assert_exit "exits 2 on a bad HEAD" 2 "$UNDER_TEST" "$plan" "$BASE" nosuchrev

echo "-- the diff is scoped to the declared documents"
out=$("$UNDER_TEST" "$plan" "$BASE" "$HEAD_REV") && rc=0 || rc=$?
assert_eq "exits 0" 0 "$rc"
assert_contains "reports the file it wrote" "$out" "wrote "

pkg="$repo/.dopamine/run/2026-08-28-widget-sweep-$(git -C "$repo" rev-parse --short "$BASE")..$(git -C "$repo" rev-parse --short "$HEAD_REV").diff"
assert_eq "the default output path is under .dopamine/run" \
    "yes" "$([ -f "$pkg" ] && echo yes || echo no)"

body=$(cat "$pkg")
assert_contains "carries the range in its header" "$body" "$BASE..$HEAD_REV"
assert_contains "has a Commits section" "$body" "## Commits"
assert_contains "has a Files changed section" "$body" "## Files changed"
assert_contains "has a Diff section" "$body" "## Diff"
assert_contains "includes the living document's change" "$body" "The widget is asynchronous."
assert_not_contains "excludes an undeclared source file" "$body" "UNDECLARED_MARKER"
assert_not_contains "excludes the plans tier — plans are immutable records" "$body" "PLAN_MARKER"

echo "-- .dopamine/run keeps itself out of git"
assert_eq "run/ carries a self-ignoring .gitignore" \
    "*" "$(cat "$repo/.dopamine/run/.gitignore")"
assert_eq "so the package never shows up in git status" \
    "" "$(git -C "$repo" status --porcelain -- .dopamine/run)"

echo "-- an explicit OUTFILE"
alt="$TEST_ROOT/explicit.diff"
"$UNDER_TEST" "$plan" "$BASE" "$HEAD_REV" "$alt" >/dev/null
assert_eq "writes where it was told" "yes" "$([ -f "$alt" ] && echo yes || echo no)"

echo "-- a repository with no dopamine config"
rm "$repo/.dopamine/config"
assert_exit "exits 3, the same code artifact-paths uses" 3 \
    "$UNDER_TEST" "$plan" "$BASE" "$HEAD_REV"

finish
