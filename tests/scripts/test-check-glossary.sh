#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

UNDER_TEST="$REPO_ROOT/skills/finishing-work/scripts/check-glossary"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

ROOT="$TEST_ROOT/repo"
mkdir -p "$ROOT/a"
printf 'def real():\n    pass\ndef other():\n    pass\n' > "$ROOT/a/b.py"
printf 'def real_v2():\n    pass\n' > "$ROOT/a/v2.py"

HEAD='# Glossary

The project'"'"'s own terms, one per line; grep for a term rather than reading the file.
'
# glossary NAME BODY -- the header above plus BODY, printed as the file's path
glossary() {
    printf '%s\n%b' "$HEAD" "$2" > "$TEST_ROOT/$1.md"
    printf '%s' "$TEST_ROOT/$1.md"
}
# check NAME BODY -- the script's output on that glossary
check() { bash "$UNDER_TEST" "$(glossary "$1" "$2")" "$ROOT"; }

GOOD=$(glossary good '- **other** (UI: "Ander") — x → `a/b.py:other`\n- **real** — resolves → `a/b.py:real`\n\n## Reconstructed, unconfirmed\n\n- **guess** — x → `a/b.py:real`\n')

echo "-- a well-formed glossary passes"
assert_exit "it exits 0" 0 bash "$UNDER_TEST" "$GOOD" "$ROOT"
assert_eq "and prints nothing" "" "$(bash "$UNDER_TEST" "$GOOD" "$ROOT")"
assert_exit "paths resolve against ROOT, not the cwd" 0 \
    bash -c 'cd / && bash "$0" "$1" "$2"' "$UNDER_TEST" "$GOOD" "$ROOT"
sed 's/$/\r/' "$GOOD" > "$TEST_ROOT/crlf.md"
assert_exit "CRLF line endings pass" 0 bash "$UNDER_TEST" "$TEST_ROOT/crlf.md" "$ROOT"
printf '%s- **real** — x → `a/b.py:real`' "$HEAD" > "$TEST_ROOT/nonl.md"
assert_exit "so does a file without a final newline" 0 bash "$UNDER_TEST" "$TEST_ROOT/nonl.md" "$ROOT"
printf -- '- **real** — x → `a/b.py:real`\n' > "$TEST_ROOT/bare.md"
assert_exit "and one with no title or header" 0 bash "$UNDER_TEST" "$TEST_ROOT/bare.md" "$ROOT"

echo "-- each failure names its line, what is wrong, and the fix"
out=$(check dead '- **gone** — x → `a/missing.py:real`\n- **moved** — x → `a/b.py:renamed`\n- **renamed** — x → `a/v2.py:real`\n')
assert_contains "a missing file" "$out" 'dead.md:5: dead pointer `a/missing.py:real`: no file a/missing.py — re-point it'
assert_contains "a missing symbol" "$out" 'dead.md:6: dead pointer `a/b.py:renamed`: "renamed" is not in a/b.py — re-point it'
assert_contains "a symbol that survives only inside a longer name" "$out" 'dead.md:7: dead pointer `a/v2.py:real`: "real" is not in a/v2.py'
assert_exit "any failure exits 1" 1 bash "$UNDER_TEST" "$TEST_ROOT/dead.md" "$ROOT"

out=$(check ptr '- **bare** — no pointer here\n- **colon** — x → `a/b.py`\n- **empty** — x → `a/b.py:`\n- **trail** — x → `a/b.py:real` (UI)\n')
assert_contains "no pointer" "$out" 'ptr.md:5: no pointer — end the line with'
assert_contains "a pointer without a colon" "$out" 'ptr.md:6: malformed pointer `a/b.py` — write it as `path:symbol`'
assert_contains "an empty symbol" "$out" 'ptr.md:7: malformed pointer `a/b.py:` — write it as `path:symbol`'
assert_contains "text after the pointer" "$out" 'ptr.md:8: no pointer — end the line with'

out=$(check shape '- **real** — x → `a/b.py:real`\n* **star** — x → `a/b.py:real`\n  - **indent** — x → `a/b.py:real`\nSome prose.\n')
assert_contains "a star bullet is not an entry" "$out" 'shape.md:6: not an entry — '
assert_contains "nor is an indented one" "$out" 'shape.md:7: not an entry — '
assert_contains "nor prose after the header" "$out" 'shape.md:8: not an entry — '
assert_contains "a star bullet before any entry is not a header" \
    "$(check starfirst '* **star** — x → `a/b.py:real`\n')" 'starfirst.md:5: not an entry — '

out=$(check blank '- **a** — x → `a/b.py:real`\n\n- **b** — x → `a/b.py:real`\n')
assert_contains "a blank line between entries" "$out" 'blank.md:6: blank line between entries — delete it'

printf '# G\n\nOne sentence.\nAnother sentence.\n\n- **real** — x → `a/b.py:real`\n' > "$TEST_ROOT/hdr.md"
assert_contains "a second header sentence" "$(bash "$UNDER_TEST" "$TEST_ROOT/hdr.md" "$ROOT")" \
    'hdr.md:4: second header line — '

out=$(check order '- **real** — x → `a/b.py:real`\n- **Other** — x → `a/b.py:other`\n')
assert_contains "an entry out of order, case ignored" "$out" \
    'order.md:6: "Other" is out of order — move it above "real" (line 5)'

out=$(check dup '- **real** — x → `a/b.py:real`\n- **real** — y → `a/b.py:real`\n')
assert_contains "a duplicate headword" "$out" 'dup.md:6: "real" is already defined on line 5 — merge'
# A UI label can be another term's headword: the grep returning both is the
# drift the glossary records.
assert_exit "a spelling two entries share is allowed" 0 bash "$UNDER_TEST" \
    "$(glossary spell '- **cold** — x → `a/b.py:real`\n- **nurture** (UI: "Cold") — x → `a/b.py:other`\n')" "$ROOT"

out=$(check sect '- **real** — x → `a/b.py:real`\n\n## Notes\n')
assert_contains "an unknown section" "$out" 'sect.md:7: unknown section "## Notes" — '
out=$(check late '## Reconstructed, unconfirmed\n\n- **guess** — x → `a/b.py:real`\n\n- **real** — x → `a/b.py:real`\n')
assert_contains "an entry after the unconfirmed section's" "$out" 'late.md:8: blank line between entries'

echo "-- usage"
assert_exit "no arguments exits 2" 2 bash "$UNDER_TEST"
assert_exit "a missing glossary exits 2" 2 bash "$UNDER_TEST" "$ROOT/none.md" "$ROOT"

finish
