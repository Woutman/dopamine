#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

UNDER_TEST="$REPO_ROOT/skills/finishing-work/scripts/check-glossary-pointers"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

ROOT="$TEST_ROOT/repo"
mkdir -p "$ROOT/a"
printf 'def real():\n    pass\n' > "$ROOT/a/b.py"

GOOD="$TEST_ROOT/good.md"
cat > "$GOOD" <<'EOF'
# Glossary

The project's own terms, one per line; grep for a term rather than reading the file.

- **real** — resolves → `a/b.py:real`
EOF

echo "-- every pointer resolves"
assert_exit "all pointers resolve" 0 bash "$UNDER_TEST" "$GOOD" "$ROOT"
assert_eq "and nothing is printed" "" "$(bash "$UNDER_TEST" "$GOOD" "$ROOT")"
assert_exit "paths resolve against ROOT, not the cwd" 0 \
    bash -c 'cd / && bash "$0" "$1" "$2"' "$UNDER_TEST" "$GOOD" "$ROOT"
CRLF="$TEST_ROOT/crlf.md"
sed 's/$/\r/' "$GOOD" > "$CRLF"
assert_exit "CRLF line endings resolve" 0 bash "$UNDER_TEST" "$CRLF" "$ROOT"

echo "-- dead pointers are reported"
BAD="$TEST_ROOT/bad.md"
cp "$GOOD" "$BAD"
cat >> "$BAD" <<'EOF'
- **gone** — x → `a/missing.py:real`
- **moved** — x → `a/b.py:renamed`
- **bare** — no pointer here
EOF
out=$(bash "$UNDER_TEST" "$BAD" "$ROOT")
assert_contains "a missing file is dead" "$out" "dead: gone: a/missing.py:real (no file)"
assert_contains "a missing symbol is dead" "$out" "dead: moved: a/b.py:renamed (no symbol)"
assert_contains "an entry without a pointer is reported" "$out" "no pointer: bare"
assert_not_contains "a resolving entry is not" "$out" "real:"
assert_exit "any failure exits 1" 1 bash "$UNDER_TEST" "$BAD" "$ROOT"

echo "-- edge cases a dead pointer could hide behind"
printf 'def real_v2():\n    pass\n' > "$ROOT/a/v2.py"
LAST="$ROOT/last.md"
printf -- '- **last** — x → `a/missing.py:real`' > "$LAST"
assert_contains "a last entry with no trailing newline is checked" \
    "$(bash "$UNDER_TEST" "$LAST" "$ROOT")" "dead: last: a/missing.py:real (no file)"
EDGE="$ROOT/edge.md"
printf -- '- **renamed** — x → `a/v2.py:real`\n- **empty** — x → `a/b.py:`\n' > "$EDGE"
out=$(bash "$UNDER_TEST" "$EDGE" "$ROOT")
assert_contains "a symbol that survives only inside a longer name is dead" \
    "$out" "dead: renamed: a/v2.py:real (no symbol)"
assert_contains "an empty symbol is no pointer" "$out" "no pointer: empty"

echo "-- usage"
assert_exit "no arguments exits 2" 2 bash "$UNDER_TEST"
assert_exit "a missing glossary exits 2" 2 bash "$UNDER_TEST" "$ROOT/none.md" "$ROOT"

finish
