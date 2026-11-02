#!/usr/bin/env bash
# Tests for the tooling behind the glossary baseline. The runs need Claude and
# stay out of this suite; the fixture, the answer key, prompt and score do not.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

B="$REPO_ROOT/tests/baselines/glossary"
F="$B/fixture"
D="$B/tasks/definitions.md"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export PYTHONDONTWRITEBYTECODE=1

echo "-- the fixture"
RC=0
(cd "$F" && python3 -m unittest discover -q -s tests -t . >/dev/null 2>&1) || RC=$?
assert_eq "its own tests pass as shipped" 0 "$RC"
assert_eq "it holds no glossary" "" "$(find "$F" -iname '*glossary*')"
assert_not_contains "no document defines withheld in prose" "$(cat "$F/docs/DESIGN.md")" "withheld"
assert_contains "withheld is defined under another name" \
    "$(cat "$F/leadflow/portal/visibility.py")" "def _suppress_score"
assert_contains "and named withheld only where it is used" \
    "$(cat "$F/leadflow/portal/cards.py")" "withheld = _suppress_score"
assert_contains "excluded has a homonym in privacy" \
    "$(cat "$F/leadflow/privacy/optout.py")" "def is_excluded_contact"

echo "-- the answer key holds against the code"
RC=0
(cd "$F" && python3 - <<'PY'
from datetime import date
from leadflow.engine.assign import assign_band
from leadflow.engine.bands import LeadBand
from leadflow.portal.cooldown import in_cooldown
from leadflow.portal.i18n import label
from leadflow.portal.visibility import _suppress_score
from leadflow.registry.match import MatchResult
from tests.helpers import lead

assert label("nurture") == "Koud" and label("excluded") == "Geen fit"          # q1, q2
optout = {"a@b.nl"}
assert _suppress_score(lead(band=LeadBand.HOT), optout)                         # q3 a
assert not _suppress_score(lead(band=LeadBand.NURTURE, contact=None), optout)   # q3 b
assert not _suppress_score(lead(band=LeadBand.WARM, contact="x@y.nl"), optout)  # q3 c
assert not _suppress_score(lead(band=LeadBand.EXCLUDED, contact=None), optout)  # q3 d
assert assign_band(lead(match=MatchResult("fuzzy", "9", 0.8))) is LeadBand.NURTURE  # q4
assert assign_band(lead(fit=0.6, intent=0.6)) is not LeadBand.EXCLUDED          # q5
from leadflow.config.enrichment import MAX_AGE_DAYS; assert MAX_AGE_DAYS == 30  # q6
d = lead(dismissed_on=date(2026, 10, 20))
assert in_cooldown(d, date(2026, 11, 2)) and not in_cooldown(d, date(2026, 11, 3))  # q7
PY
) >/dev/null 2>&1 || RC=$?
assert_eq "every answer follows from the fixture" 0 "$RC"

echo "-- tasks and definitions agree"
while IFS=$'\t' read -r task answer needs; do
    assert_eq "$task has a prompt" yes "$([ -s "$B/tasks/$task.md" ] && echo yes || echo no)"
    o=$(bash "$B/prompt" O "$task")
    IFS=, read -ra terms <<< "$needs"
    assert_eq "arm O gets exactly the ${#terms[@]} definition(s) $task needs" \
        "${#terms[@]}" "$(printf '%s\n' "$o" | grep -c '^- \*\*')"
    assert_eq "arm A gets the question alone" "$(cat "$B/tasks/$task.md")" "$(bash "$B/prompt" A "$task")"
    assert_eq "arm C gets the question alone" "$(cat "$B/tasks/$task.md")" "$(bash "$B/prompt" C "$task")"
    assert_eq "arm G gets the question alone" "$(cat "$B/tasks/$task.md")" "$(bash "$B/prompt" G "$task")"
done < <(tail -n +2 "$B/tasks/questions.tsv")
while IFS= read -r target; do
    file="${target%%:*}" name="${target##*:}"
    assert_contains "$name is defined where the definitions say" "$(cat "$F/$file")" "$name"
done < <(grep -o '→ `[^`]*`' "$D" | sed 's/→ `\(.*\)`/\1/')
assert_exit "an unknown arm exits 2" 2 bash "$B/prompt" X q1-koud
assert_exit "arm C is known" 0 bash "$B/prompt" C q1-koud
assert_exit "arm G is known" 0 bash "$B/prompt" G q1-koud
assert_exit "an unknown task exits 2" 2 bash "$B/prompt" A q9-none

echo "-- the GREEN overlay"
O="$B/green-overlay"
assert_exit "every overlay pointer resolves in the fixture" 0 \
    bash "$REPO_ROOT/skills/finishing-work/scripts/check-glossary-pointers" "$O/docs/GLOSSARY.md" "$F"
while IFS= read -r entry; do
    assert_eq "the overlay holds ${entry:0:30}... verbatim" yes \
        "$(grep -Fxq -- "$entry" "$O/docs/GLOSSARY.md" && echo yes || echo no)"
done < <(grep '^- \*\*' "$D")
assert_eq "it holds 12 entries" 12 "$(grep -c '^- \*\*' "$O/docs/GLOSSARY.md")"
RC=0
sed -n 's/^- \*\*\([^*]*\)\*\*.*/\1/p' "$O/docs/GLOSSARY.md" | LC_ALL=C sort -c || RC=$?
assert_eq "its entries are alphabetical by headword" 0 "$RC"
assert_eq "its config is the fixture's plus the glossary line" \
    "$(cat "$F/.dopamine/config"; echo 'glossary: docs/GLOSSARY.md')" "$(cat "$O/.dopamine/config")"

echo "-- setup-run"
run=$(bash "$B/setup-run" "$T/runs" A-q1-koud-1)
assert_eq "prints the run directory" "$T/runs/A-q1-koud-1" "$run"
assert_eq "the fixture is committed and the tree is clean" "" "$(git -C "$run" status --porcelain)"
assert_exit "a label already set up is refused" 1 bash "$B/setup-run" "$T/runs" A-q1-koud-1
g=$(bash "$B/setup-run" "$T/runs" G-q1-koud-1)
c=$(bash "$B/setup-run" "$T/runs" C-q1-koud-1)
assert_eq "G's run holds the glossary" yes "$([ -f "$g/docs/GLOSSARY.md" ] && echo yes || echo no)"
assert_contains "and declares it" "$(cat "$g/.dopamine/config")" "glossary: docs/GLOSSARY.md"
assert_eq "C's run does not" no "$([ -f "$c/docs/GLOSSARY.md" ] && echo yes || echo no)"
assert_eq "G's tree is committed clean" "" "$(git -C "$g" status --porcelain)"

echo "-- score"
R="$T/scored"
mkdir -p "$R"
printf '{"structured_output":{"answer":"Nurture."},"total_cost_usd":0.02,"num_turns":1,"usage":{"cache_read_input_tokens":900,"cache_creation_input_tokens":100,"output_tokens":20}}' \
    > "$R/O-q1-koud-1.json"
printf '{"structured_output":{"answer":"warm"},"total_cost_usd":0.04,"num_turns":3,"usage":{"cache_read_input_tokens":0,"cache_creation_input_tokens":0,"output_tokens":40}}' \
    > "$R/A-q4-unresolved-1.json"
out=$(python3 "$B/score" "$R")
assert_contains "a right answer counts, whatever its case and punctuation" \
    "$out" "| O | 1 | 1/1 | 0.0200 ± 0.0000 | 100 | 900 | 20 | 1.0 | 0/1 |"
assert_contains "a wrong one does not" "$out" "| A | 1 | 0/1 |"
printf '{"structured_output":{"answer":"No. It is withheld, not excluded."},"total_cost_usd":0.01,"num_turns":1,"usage":{}}' \
    > "$R/A-q5-opted-out-1.json"
printf '{"structured_output":{"answer":"Notably not."},"total_cost_usd":0.01,"num_turns":1,"usage":{}}' \
    > "$R/A-q5-opted-out-2.json"
out=$(python3 "$B/score" "$R")
assert_contains "an answer followed by its reasoning counts, a longer word does not" \
    "$out" "| q5-opted-out A | 2 | 1/2 |"
assert_contains "tasks are reported per arm" "$out" "| q4-unresolved A | 1 | 0/1 |"
printf '{"session_id":"s1","structured_output":{"answer":"nurture"},"total_cost_usd":0.01,"num_turns":1,"usage":{}}' \
    > "$R/G-q1-koud-1.json"
mkdir -p "$R/.claude-config/projects/p"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Grep","input":{"pattern":"withheld","path":"docs/GLOSSARY.md"}}]}}' \
    > "$R/.claude-config/projects/p/s1.jsonl"
out=$(python3 "$B/score" "$R")
assert_contains "a run that searched the glossary is counted" "$(grep '^| G |' <<< "$out")" "| 1.0 | 1/1 |"
assert_contains "a run without a transcript is not" "$(grep '^| O |' <<< "$out")" "| 1.0 | 0/1 |"
printf '{"session_id":"s2","structured_output":{"answer":"nurture"},"total_cost_usd":0.01,"num_turns":1,"usage":{}}' \
    > "$R/G-q1-koud-2.json"
{
    printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Grep","input":{"pattern":"Koud","path":"/run"}}]}}'
    printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","content":"docs/GLOSSARY.md:12:- **nurture** (UI: Koud)"}]}}'
} > "$R/.claude-config/projects/p/s2.jsonl"
out=$(python3 "$B/score" "$R")
assert_contains "a repo-wide search that came back from the glossary counts too" \
    "$(grep '^| G |' <<< "$out")" "| 1.0 | 2/2 |"

finish
