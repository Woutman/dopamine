#!/usr/bin/env bash
# Tests for the tooling behind the module-depth baseline. The runs need agents
# and a judge and stay out of this suite; the fixture, and the scripts that set
# runs up, fill their prompts and score them, do not.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

B="$REPO_ROOT/tests/baselines/module-depth"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export PYTHONDONTWRITEBYTECODE=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@localhost
export GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@localhost

# A document with one `## ` section removed, so two overlays can be compared
# everywhere but the slot under test.
without() { awk -v s="## $2" '$0 == s { skip = 1; next } /^## / { skip = 0 } !skip' "$1"; }

echo "-- the fixture"
F="$B/fixture"
RC=0
(cd "$F" && python3 -m unittest discover -q -s tests >/dev/null 2>&1) || RC=$?
assert_eq "its own tests pass as shipped" 0 "$RC"
assert_contains "it declares the program design" \
    "$(cat "$F/.dopamine/config")" "living: docs/PROGRAM-DESIGN.md"
for doc in ARCHITECTURE PROGRAM-DESIGN; do
    assert_eq "$doc.md is absent from the base, so arm A derives it" no \
        "$([ -e "$F/docs/$doc.md" ] && echo yes || echo no)"
done
assert_contains "cli reaches past store's surface" \
    "$(cat "$F/feedwatch/cli.py")" "from feedwatch.store.schema import database_path"
assert_contains "notify reaches into fetch's parsing" \
    "$(cat "$F/feedwatch/notify/formats.py")" "from feedwatch.fetch.parsing import clean_title"
assert_contains "the design holds the invariant" \
    "$(cat "$F/docs/DESIGN.md")" "A channel decides its message format"
assert_contains "the digest needs each failing feed's error" \
    "$(cat "$F/docs/superpowers/specs/2026-04-06-daily-digest-design.md")" "the error that poll returned"
assert_contains "the error lives inside store" \
    "$(cat "$F/feedwatch/store/queries.py")" "def latest_failures"
assert_not_contains "and store's surface does not offer it" \
    "$(cat "$F/feedwatch/store/__init__.py")" "\"latest_failures\""

echo "-- the overlays differ only in the slot under test"
R="$B/overlays/red/docs" G="$B/overlays/green/docs"
assert_eq "ARCHITECTURE.md is identical outside How they talk" \
    "$(without "$R/ARCHITECTURE.md" "How they talk")" "$(without "$G/ARCHITECTURE.md" "How they talk")"
assert_eq "PROGRAM-DESIGN.md is identical outside Modules" \
    "$(without "$R/PROGRAM-DESIGN.md" Modules)" "$(without "$G/PROGRAM-DESIGN.md" Modules)"
assert_contains "green's architecture has the component table" \
    "$(cat "$G/ARCHITECTURE.md")" "| Component | Offers its callers | Must hold |"
assert_not_contains "red's has none" "$(cat "$R/ARCHITECTURE.md")" "Offers its callers"
assert_contains "green's Modules has the boundary rule" \
    "$(cat "$G/PROGRAM-DESIGN.md")" "**Rule (boundary):**"
assert_contains "red's Modules is the inherited default" \
    "$(cat "$R/PROGRAM-DESIGN.md")" "smaller units, each with one clear purpose"

echo "-- setup-run"
run=$(bash "$B/setup-run" "$T/runs" A0-1)
assert_eq "prints the run directory" "$T/runs/A0-1" "$run"
assert_eq "the fixture is committed and the tree is clean" "" "$(git -C "$run" status --porcelain)"
assert_eq "the starting point is tagged" \
    "$(git -C "$run" rev-parse HEAD)" "$(git -C "$run" rev-parse baseline-base)"
assert_eq "the database path stays inside the run" ".feedwatch/feeds.db" \
    "$(cd "$run" && python3 -m feedwatch.cli where)"
assert_exit "a label already set up is refused" 1 bash "$B/setup-run" "$T/runs" A0-1
assert_exit "bad usage exits 2" 2 bash "$B/setup-run" "$T/runs"
run=$(bash "$B/setup-run" "$T/runs" P0-1 "$B/overlays/red")
assert_exit "an overlay is part of the starting point" 0 \
    git -C "$run" cat-file -e baseline-base:docs/PROGRAM-DESIGN.md
run=$(bash "$B/setup-run" "$T/runs" X1-1 "$B/overlays/green" "$B/overlays/work")
assert_eq "the work changes cli.py and nothing else" "feedwatch/cli.py" \
    "$(git -C "$run" diff --name-only baseline-base...HEAD)"
added=$(git -C "$run" diff baseline-base...HEAD | grep -E '^\+(from|import|def) ')
assert_eq "it adds exactly the planted import, reach-in and wrapper" \
    "$(printf '+from feedwatch.fetch import FetchError\n+from feedwatch.store.queries import latest_failures\n+def _feeds(conn):')" \
    "$added"
RC=0
(cd "$run" && python3 -m unittest discover -q -s tests >/dev/null 2>&1) || RC=$?
assert_eq "the work's tests pass" 0 "$RC"

echo "-- render"
printf 'A {X} and {Y_Z}.\n' > "$T/t.md"
printf 'has {BRACES}\n' > "$T/v.txt"
assert_eq "fills a value and a file, and leaves a filled-in file's braces alone" \
    "A one and has {BRACES}." "$(python3 "$B/render" "$T/t.md" X=one Y_Z=@"$T/v.txt")"
assert_exit "an unfilled placeholder exits 2" 2 python3 "$B/render" "$T/t.md" X=one
assert_exit "a key the template lacks exits 2" 2 python3 "$B/render" "$T/t.md" X=1 Y_Z=2 W=3
assert_exit "a malformed argument exits 2" 2 python3 "$B/render" "$T/t.md" X
P="$B/prompts"
for spec in "session-context.md INJECTION SUPERPOWERS DOPAMINE" \
            "plan.md RUN_DIR SESSION_CONTEXT" \
            "gate.md RUN_DIR SESSION_CONTEXT" \
            "architecture.md RUN_DIR SESSION_CONTEXT SKILL" \
            "judge.md POOL_DIR RUBRIC"; do
    set -- $spec
    file="$1"; shift
    fills=()
    for key in "$@"; do fills+=("$key=x"); done
    assert_exit "$file renders with exactly its keys" 0 python3 "$B/render" "$P/$file" "${fills[@]}"
done

echo "-- the rubrics and the vocabulary agree"
for column in table exception invariant clean named stopped pairs reach-in wrapper misflagged; do
    assert_contains "vocab.tsv declares $column" "$(cut -f1 "$B/vocab.tsv")" "$column"
done
for pair in architecture:table architecture:exception architecture:invariant \
            plan:clean plan:named plan:stopped plan:pairs \
            gate:reach-in gate:wrapper gate:misflagged; do
    assert_contains "rubric-${pair%%:*}.md reads ${pair#*:}" \
        "$(cat "$P/rubric-${pair%%:*}.md")" "| \`${pair#*:}\` |"
done

echo "-- blind and score, as copied"
printf 'Checked %s: fine.\n' "$T/runs/X1-1" > "$T/runs/X1-1.reply.md"
printf 'DONE\n' > "$T/runs/A0-1.reply.md"
printf 'DONE\n' > "$T/runs/P0-1.reply.md"
python3 "$B/blind" "$T/runs" "$T/out" --columns reach-in --seed 1 >/dev/null 2>&1
items=$(cat "$T/out/items.md")
assert_contains "the run directory is replaced" "$items" "Checked <repo>: fine."
assert_not_contains "no item names its run" "$items" "X1-1"
printf 'id\trun\np001\tX0-1\np002\tX1-1\n' > "$T/out/key.tsv"
printf 'id\treach-in\np001\tno\np002\tyes\n' > "$T/out/verdicts.tsv"
assert_contains "score keeps the arms apart" \
    "$(python3 "$B/score" "$T/out" "$B/vocab.tsv")" "| X1 | 1 | 1/1 | 0 |"

finish
