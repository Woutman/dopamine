#!/usr/bin/env bash
# Tests for the tooling behind the glossary baseline. The runs need Claude and
# stay out of this suite; the fixture, the checks, inject and score do not.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

B="$REPO_ROOT/tests/baselines/glossary"
G="$B/overlays/glossary/docs/GLOSSARY.md"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export PYTHONDONTWRITEBYTECODE=1

check() { (cd "$1" && PYTHONPATH="$1" python3 "$B/checks/$2.py" >/dev/null 2>&1); echo $?; }

echo "-- the fixture"
RC=0
(cd "$B/fixture" && python3 -m unittest discover -q -s tests >/dev/null 2>&1) || RC=$?
assert_eq "its own tests pass as shipped" 0 "$RC"
assert_eq "it holds no glossary, so arm A has none" no \
    "$([ -e "$B/fixture/docs/GLOSSARY.md" ] && echo yes || echo no)"
assert_contains "the overlay declares the glossary tier" \
    "$(cat "$B/overlays/glossary/.dopamine/config")" "glossary: docs/GLOSSARY.md"

echo "-- the glossary"
assert_eq "every entry is one line starting with its headword" \
    "$(grep -c '^- ' "$G")" "$(grep -c '^- \*\*[^*]*\*\* ' "$G")"
assert_eq "headwords are alphabetical" \
    "$(sed -n 's/^- \*\*\([^*]*\)\*\*.*/\1/p' "$G")" \
    "$(sed -n 's/^- \*\*\([^*]*\)\*\*.*/\1/p' "$G" | LC_ALL=C sort)"
while IFS= read -r target; do
    file="${target%%:*}" name="${target##*:}"
    assert_contains "$name is defined where the glossary says" \
        "$(cat "$B/fixture/$file")" "$name"
done < <(grep -o '→ `[^`]*`' "$G" | sed 's/→ `\(.*\)`/\1/')
assert_eq "a lookup returns exactly one line" 1 "$(grep -ic '^- \*\*withheld' "$G")"

echo "-- tasks, keys and checks agree"
while IFS=$'\t' read -r task kind _; do
    assert_eq "$task has a prompt" yes "$([ -s "$B/tasks/$task.md" ] && echo yes || echo no)"
    if [ "$kind" = question ]; then
        assert_contains "$task has an answer" "$(cut -f1 "$B/tasks/answers.tsv")" "$task"
    else
        assert_eq "$task's check fails on the untouched fixture" 1 "$(check "$B/fixture" "$task")"
    fi
done < <(tail -n +2 "$B/tasks/kinds.tsv")

echo "-- the checks pass on a correct edit"
S="$T/solved"
cp -R "$B/fixture" "$S"
sed -i 's/LeadBand.WARM: 0.6/LeadBand.WARM: 0.5/' "$S/leadflow/engine/bands.py"
assert_eq "t5 passes" 0 "$(check "$S" t5-warm-threshold)"
sed -i 's/"Neutraal"/"In afwachting"/' "$S/leadflow/portal/labels.py"
assert_eq "t6 passes" 0 "$(check "$S" t6-withheld-label)"
python3 - "$S/leadflow/engine/scoring.py" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read().replace(
    "band in (LeadBand.HOT, LeadBand.WARM):\n        return LeadBand.NURTURE",
    "band == LeadBand.HOT:\n        return LeadBand.WARM")
open(p, "w").write(s)
PY
assert_eq "t7 passes" 0 "$(check "$S" t7-unresolved-cap)"
printf 'def chunk(items, n):\n    return [items[i:i + n] for i in range(0, len(items), n)]\n' > "$S/leadflow/util.py"
assert_eq "c2 passes" 0 "$(check "$S" c2-chunk)"
printf '\n\ndef normalise_email(s):\n    return s.strip().lower()\n' >> "$S/leadflow/util.py"
assert_eq "c3 passes" 0 "$(check "$S" c3-email)"
sed -i 's/0.55/0.5/' "$S/leadflow/engine/legacy_bands.py"
assert_eq "t5 fails when the backfill threshold moves too" 1 "$(check "$S" t5-warm-threshold)"

echo "-- setup-run"
run=$(bash "$B/setup-run" "$T/runs" A-t1-koud-1 A)
assert_eq "prints the run directory" "$T/runs/A-t1-koud-1" "$run"
assert_eq "arm A's tree is clean and has no glossary" ":no" \
    "$(git -C "$run" status --porcelain):$([ -e "$run/docs/GLOSSARY.md" ] && echo yes || echo no)"
run=$(bash "$B/setup-run" "$T/runs" D-t1-koud-1 D)
assert_eq "arm D's has one" yes "$([ -e "$run/docs/GLOSSARY.md" ] && echo yes || echo no)"
assert_exit "a label already set up is refused" 1 bash "$B/setup-run" "$T/runs" D-t1-koud-1 D
assert_exit "an unknown arm exits 2" 2 bash "$B/setup-run" "$T/runs" E-x-1 E

echo "-- inject"
assert_eq "arm A injects nothing" "" "$(bash "$B/inject" A "$G")"
assert_not_contains "arm B names no definition" "$(bash "$B/inject" B "$G")" "Geen fit"
assert_contains "arm C carries every definition" "$(bash "$B/inject" C "$G")" \
    "$(grep '^- \*\*withheld' "$G")"
d=$(bash "$B/inject" D "$G")
assert_contains "arm D lists the headwords" "$d" "band, excluded, hidden, hot, legacy band"
assert_not_contains "and no definition" "$d" "Geen fit"
assert_exit "an unknown arm exits 2" 2 bash "$B/inject" E "$G"

echo "-- score"
R="$T/scored"
mkdir -p "$R"
bash "$B/setup-run" "$R" C-t1-koud-1 C >/dev/null
bash "$B/setup-run" "$R" C-c2-chunk-1 C >/dev/null
printf '{"structured_output":{"answer":"Nurture."},"total_cost_usd":0.02,"num_turns":1,"usage":{"input_tokens":10,"cache_read_input_tokens":900,"cache_creation_input_tokens":0,"output_tokens":20}}' \
    > "$R/C-t1-koud-1.json"
printf '{"structured_output":{"done":true},"total_cost_usd":0.04,"num_turns":3,"usage":{"input_tokens":30,"cache_read_input_tokens":0,"cache_creation_input_tokens":0,"output_tokens":40}}' \
    > "$R/C-c2-chunk-1.json"
out=$(python3 "$B/score" "$R")
assert_contains "a right answer counts, whatever its case and punctuation" \
    "$out" "| C | term | 1 | 1/1 | 0.0200 | 10 | 0 | 900 | 20 | 1.0 |"
assert_contains "an edit is graded by its check, not by what the agent claims" \
    "$out" "| C | control | 1 | 0/1 | 0.0400 |"

finish
