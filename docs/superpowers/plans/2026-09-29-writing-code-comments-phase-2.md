# Code-comment discipline, Phase 2: skill, wiring and GREEN — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Write `dopamine:writing-code-comments`, fitted to the one failure the baselines reproduced, wire it into the `SessionStart` injection and `finishing-work`'s exit gate, and show with a GREEN run of scenario L that it removes that failure without stripping useful comments.

**Architecture:** The baseline harness keeps only scenario L and its legacy fixture; everything else is deleted. The skill's wording is chosen by a micro-test against a no-guidance control before any full run. The skill is one `SKILL.md` under 200 words: a positive contract, one example, and, if the micro-test keeps it, a table of the mistakes the baselines showed. GREEN reruns L with the injection and the skill's path, pooled with the L0 runs and judged blind.

**Tech Stack:** bash, git, markdown. Python 3 for the baseline tooling and the test suite only, never shipped runtime.

**Spec:** `docs/superpowers/specs/2026-09-29-writing-code-comments-design.md`, amended by `docs/superpowers/specs/2026-09-29-writing-code-comments-rebaseline-design.md` (§7: the contract gains a shape, the injection names plans) and `docs/superpowers/specs/2026-09-29-writing-code-comments-legacy-phase-design.md` (scenario L).

**Relation to earlier plans.** This plan replaces the draft Phase 2 of `docs/superpowers/plans/2026-09-29-writing-code-comments.md`, as `docs/superpowers/plans/2026-09-29-writing-code-comments-rebaseline.md` said it would. That draft stays as written. The evidence it rests on is in `docs/superpowers/plans/2026-09-29-writing-code-comments.baseline/`: `red/` (A0, S0), `red2/` (P0, R0, M0) and `legacy/` (L0p, L0x).

## What the baselines showed, and the decisions taken on it

**Evidence.**
- Across 35 runs in three baselines, no comment narrated the change.
- The only scenario to reach the gate was L: L0p averaged 1.4 bad comments per run, L0x 1.2.
- Of those bad comments, 12 were bloat, and every one was a comment that argues a spec ruling: it argues against the rejected alternative, or it recites the measurements behind a number. Two were restatements.
- 135 of the 136 comments in L0x were copied word for word from the run's own plan, so plans are where comments get written.

**Decisions from the Phase 1 review (the human, 2026-09-29):**
1. GREEN reruns only scenario L. The other scenarios, and every file that only they use, are deleted. Their committed results stay: they are the evidence.
2. The L1 runs are given the `SessionStart` injection and the skill's path, and must choose to load it.
3. The injection does not ask the controller to copy the contract into implementer prompts: implementers copy the plan's comments and add almost none.
4. GREEN passes on a criterion aimed at the failure, combined with a general one and a floor (Task 6, Step 9).
5. The skill is built with `superpowers:writing-skills`. The failure is wrong-shaped output, so the skill is a positive contract, not a prohibition list, and its wording is micro-tested against a no-guidance control before the full runs.

**Ruling: the skill has no sentence about correcting a comment the change made false.** The design spec (§2) keeps such comments in scope. Against: no baseline run kept one. L kept the stale comment in 0 of 5 runs per arm, and P0's 3 of 5 was the extractor reading plan prose, fixed since. writing-skills says a GREEN skill addresses the failures RED showed and adds nothing for hypothetical ones. **Cost if wrong:** a stale comment survives a change. The exit gate reads only added comments, so nothing else catches it.

## Global Constraints

- **The skill applies only in adopted repositories.** It is reached through the `SessionStart` injection, which is silent without `.dopamine/config`.
- **Only comments the diff adds or touches are governed.** This includes comments inside a plan's python code blocks.
- **The skill is a positive contract, not a prohibition list.** No density clause, and no supporting files.
- **`SKILL.md` body stays under 200 words.** Its `description` starts with `Use when`, is under 500 characters, and states triggers only.
- **The skill's example is from neither fixture nor the micro-test's domain.** It is about webhook events.
- **The injection stays within its 200-word budget and uses no `never`, `do not` or `don't`** (enforced by `tests/hooks/test-session-start.sh`).
- **Categories, exactly:** `why contract warning narration bloat restatement`. Bad = `narration`, `bloat`, `restatement`.
- **Specs, executed plans and earlier results are not edited.**
- **Scripts are invoked through their interpreter** (`bash setup-run`, `python3 accept`), never by bare path.
- **`bash tests/run-tests.sh` exits 0 at the end of every task.**
- **Micro-tests, baseline runs and judging are done by the main session**, not an implementer subagent.

## Review Focus

1. **A skill that fixes the failure by suppressing comments.** Expected: GREEN's floor holds why and contract comments to at least half of L0's. *(Task 6, Step 9.)*
2. **A skill whose example leaks into the runs.** A run could copy the example instead of applying the contract. Expected: the example's domain appears in no fixture, and the content test checks it. *(Task 3.)*
3. **A micro-test control that shows no failure.** Then the micro-test cannot choose between wordings. Expected: one revision of the micro task, and if the control is still clean, the fuller variant goes to GREEN under a recorded ruling. *(Task 2, Step 5.)*
4. **Judging that recognises L0's comments.** The judge has seen them all. Expected: the pool is re-extracted under a new seed and every comment is judged again, so L0 and L1 are scored under one judgment. *(Task 6, Steps 7–8.)*
5. **The deletion breaking the tooling it keeps.** Expected: the rewritten tooling test covers `setup-run`, `accept legacy-plan`, `extract-comments` and `score` on the legacy fixture. *(Task 1.)*

---

## File Structure

**Deleted:** `tests/baselines/writing-code-comments/fixture/`, `overlays/`, `scenarios/`, and `prompts/agent.md`, `prompts/implementer.md`, `prompts/plan.md`.

**Created:**

| Path | Responsibility |
|---|---|
| `tests/baselines/writing-code-comments/micro/task.md` | The micro-test task: one plan code block, from a spec full of rulings |
| `tests/baselines/writing-code-comments/micro/guidance.md` | How a variant's skill text is put in front of the task |
| `tests/baselines/writing-code-comments/micro/skill-v1.md`, `skill-v2.md` | The two wordings under test |
| `tests/baselines/writing-code-comments/prompts/session-context.md` | GREEN's `{LOADED_SKILL}`: the injection and the skill's path |
| `skills/writing-code-comments/SKILL.md` | The skill |
| `tests/skills/test-code-comments.sh` | Content assertions for the skill |
| `docs/superpowers/plans/2026-09-29-writing-code-comments.baseline/micro/`, `green/` | Committed results |

**Modified:** `tests/baselines/writing-code-comments/setup-run`, `accept`; `tests/scripts/test-baseline-tooling.sh`; `hooks/session-start-context.md`; `tests/hooks/test-session-start.sh`; `skills/finishing-work/SKILL.md`; `tests/skills/test-skill-structure.sh`; `README.md`; `.claude-plugin/plugin.json`.

**Run scratch** (gitignored by the `.dopamine/run/` rule): `.dopamine/run/baseline/micro/`, `.dopamine/run/baseline/green/`. GREEN also reads the L0 runs in `.dopamine/run/baseline/legacy/`.

**Task order:** the cleanup first, so every later task works against the harness GREEN uses; the micro-test before the skill, because it chooses the skill's wording; then the skill, the injection and the gate, which GREEN needs in place; GREEN; then the README.

---

### Task 1: Keep only scenario L

**Files:**
- Delete: `tests/baselines/writing-code-comments/fixture/`, `overlays/`, `scenarios/`, `prompts/agent.md`, `prompts/implementer.md`, `prompts/plan.md`
- Modify: `tests/baselines/writing-code-comments/setup-run`, `tests/baselines/writing-code-comments/accept`
- Test: `tests/scripts/test-baseline-tooling.sh`

**Interfaces:**
- Produces:
  - `setup-run RUNS_DIR LABEL [OVERLAY_DIR]`. It always uses `legacy-fixture/`, and commits an overlay as `plan: Phase 2, unattended import from the inbox`. The `--fixture` and `--message` options are gone.
  - `accept RUN_DIR legacy-code` and `accept RUN_DIR legacy-plan PLAN_PATH`. The `code` and `plan` modes are gone.
  - `extract-comments` and `score` are unchanged.

- [ ] **Step 1: Replace the tooling test**

`tests/scripts/test-baseline-tooling.sh`:

````bash
#!/usr/bin/env bash
# Tests for the tooling behind the writing-code-comments baseline. The runs
# themselves need agents and a judge and stay out of this suite; the scripts
# that set them up, check them and score them do not.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

B="$REPO_ROOT/tests/baselines/writing-code-comments"
L="$B/legacy-fixture"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export PYTHONDONTWRITEBYTECODE=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@localhost
export GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@localhost

echo "-- the fixture"
RC=0
(cd "$L" && python3 -m unittest -q >/dev/null 2>&1) || RC=$?
assert_eq "its own tests pass as shipped" 0 "$RC"
assert_contains "it carries the comment the spec makes false" \
    "$(cat "$L/readings/runner.py")" "Keyed by station and row"
assert_exit "accept refuses it: the phase is not done" 1 python3 "$B/accept" "$L" legacy-code
assert_exit "accept's bad usage exits 2" 2 python3 "$B/accept" "$L"

echo "-- setup-run"
run=$(bash "$B/setup-run" "$T/runs" A0-1)
assert_eq "prints the run directory" "$T/runs/A0-1" "$run"
assert_eq "the fixture is committed and the tree is clean" "" "$(git -C "$run" status --porcelain)"
assert_eq "the starting point is tagged" \
    "$(git -C "$run" rev-parse HEAD)" "$(git -C "$run" rev-parse baseline-base)"
assert_exit "a label already set up is refused" 1 bash "$B/setup-run" "$T/runs" A0-1
assert_exit "bad usage exits 2" 2 bash "$B/setup-run" "$T/runs"
mkdir -p "$T/overlay/docs"
echo "# a plan" > "$T/overlay/docs/p.md"
exec_run=$(bash "$B/setup-run" "$T/legacy" L0x-1 "$T/overlay")
assert_eq "an overlay is committed on top of the fixture" 2 "$(git -C "$exec_run" rev-list --count HEAD)"
assert_eq "under the plan's commit message" "plan: Phase 2, unattended import from the inbox" \
    "$(git -C "$exec_run" log -1 --format=%s)"
assert_eq "and the overlay is the tagged starting point" \
    "$(git -C "$exec_run" rev-parse HEAD)" "$(git -C "$exec_run" rev-parse baseline-base)"

# A0-1: a docstring, a comment, and a '#' that lives inside a string.
cat >> "$run/readings/report.py" <<'PY'


def total_stored(summaries):
    """Sum of the stored counts."""
    # Loop over the summaries
    label = "run # count"
    return sum(summary.stored for summary in summaries)
PY
# A0-2: changes nothing.
bash "$B/setup-run" "$T/runs" A0-2 >/dev/null
# A0-3: a new file, committed by the run itself.
run=$(bash "$B/setup-run" "$T/runs" A0-3)
printf '# Added helper\ndef helper():\n    return 1\n' > "$run/readings/helpers.py"
git -C "$run" add -A && git -C "$run" commit -qm work
# A0-4: leaves the module unparseable.
run=$(bash "$B/setup-run" "$T/runs" A0-4)
printf '\n\ndef broken(:\n    # Fixed the thing\n' >> "$run/readings/runner.py"
# A0-5: a plan whose python blocks carry comments; one block is indented and does not parse.
run=$(bash "$B/setup-run" "$T/runs" A0-5)
cat > "$run/docs/plan.md" <<'MD'
# Plan

```bash
# not python
echo hi
```

```python
def helper():
    # Critical 1: keep this
    return 1
```

  ```python
      def method(self):
          """Half of a class,
          so it does not parse."""
          return (
  ```
MD

echo "-- accept legacy-plan"
plan=$(bash "$B/setup-run" "$T/plans" L0p-1)
tasks() { for n in $(seq "$1"); do printf '### Task %s: step\n\n```python\nx = %s\n```\n\n' "$n" "$n"; done; }
names='readings/calibrate.py INBOX_DIR POISON_AFTER set_marker Summary readings/cli.py'
{ tasks 5; echo "$names"; } > "$plan/docs/p.md"
assert_exit "refuses an uncommitted plan" 1 python3 "$B/accept" "$plan" legacy-plan docs/p.md
git -C "$plan" add -A && git -C "$plan" commit -qm plan
assert_exit "takes a committed plan of five tasks" 0 python3 "$B/accept" "$plan" legacy-plan docs/p.md
{ tasks 4; echo "$names"; } > "$plan/docs/p.md"
git -C "$plan" add -A && git -C "$plan" commit -qm plan
assert_exit "but not one of four: the fixture would be too small" 1 \
    python3 "$B/accept" "$plan" legacy-plan docs/p.md
{ tasks 5; echo "readings/calibrate.py INBOX_DIR POISON_AFTER set_marker Summary"; } > "$plan/docs/p.md"
git -C "$plan" add -A && git -C "$plan" commit -qm plan
assert_exit "nor one that leaves a decision out" 1 python3 "$B/accept" "$plan" legacy-plan docs/p.md
{ tasks 5; echo "$names"; } > "$plan/docs/p.md"
echo "x = 1" >> "$plan/readings/units.py"
git -C "$plan" add -A && git -C "$plan" commit -qm plan
assert_exit "nor one whose run changed the package" 1 python3 "$B/accept" "$plan" legacy-plan docs/p.md

echo "-- extract-comments"
RC=0
python3 "$B/extract-comments" "$T/runs" "$T/out" --seed 1 >/dev/null 2>&1 || RC=$?
assert_eq "exits 0" 0 "$RC"
comments=$(cat "$T/out/comments.md")
key=$(cat "$T/out/key.tsv")
runs=$(cat "$T/out/runs.tsv")
assert_contains "finds an added comment" "$comments" "Loop over the summaries"
assert_contains "finds an added docstring" "$comments" "Sum of the stored counts"
assert_contains "finds a comment in a new file the run committed" "$comments" "Added helper"
assert_contains "falls back when the code does not parse" "$comments" "Fixed the thing"
assert_not_contains "labels no entry with its run" "$comments" "A0-"
assert_eq "A0-1 yields exactly two comments: the '#' in a string is not one" \
    2 "$(grep -c $'\tA0-1\t' "$T/out/key.tsv")"
assert_contains "the docstring is recorded as one" "$key" $'\tdocstring'
assert_contains "the unparseable run is recorded as such" \
    "$(grep $'\tA0-4\t' "$T/out/key.tsv")" "unparsed"
assert_contains "a comment in a plan's python block is found, at its line in the plan" \
    "$key" $'A0-5\tdocs/plan.md\t10\t10\tcomment'
assert_contains "an indented block that does not parse still yields its docstring" \
    "$key" $'A0-5\tdocs/plan.md\t16\t17\tunparsed'
assert_not_contains "a comment in a non-python block is not one" "$comments" "not python"
assert_contains "runs.tsv counts added, code and comment lines, and labelled comments" \
    "$runs" $'A0-1\t7\t7\t2\t0\t-'
assert_contains "a plan's code lines are its python blocks' lines" \
    "$runs" $'A0-5\t19\t7\t3\t1\t-'
assert_contains "a run that changed nothing is still listed" "$runs" $'A0-2\t0\t0\t0\t0\t-'
assert_eq "one verdict row per comment" \
    "$(wc -l < "$T/out/key.tsv")" "$(wc -l < "$T/out/verdicts.tsv")"
assert_contains "each run's raw diff is kept for a later judge" \
    "$(cat "$T/out/diffs/A0-3.diff")" "Added helper"
python3 "$B/extract-comments" "$T/runs" "$T/again" --seed 1 >/dev/null 2>&1
assert_eq "the same seed gives the same order" \
    "$(cat "$T/out/comments.md")" "$(cat "$T/again/comments.md")"
python3 "$B/extract-comments" "$T/runs" "$T/stale" --stale 'keep this' >/dev/null 2>&1
stale=$(cat "$T/stale/runs.tsv")
assert_contains "--stale marks a run whose changed files still match" "$stale" $'A0-5\t19\t7\t3\t1\t1'
assert_contains "and clears one whose do not" "$stale" $'A0-1\t7\t7\t2\t0\t0'

# L0x-1: an execution that edits a plan's code block and adds a comment in the package.
printf '```python\n# plan comment, see spec §4.2\nx = 1\n```\n' >> "$exec_run/docs/p.md"
printf '\n# no longer keyed by row\n' >> "$exec_run/readings/runner.py"
python3 "$B/extract-comments" "$T/legacy" "$T/lout" --py-only --stale 'Keyed by station and row' >/dev/null 2>&1
assert_not_contains "--py-only leaves out a plan's code" "$(cat "$T/lout/comments.md")" "plan comment"
assert_contains "and keeps the package's" "$(cat "$T/lout/comments.md")" "no longer keyed by row"
assert_contains "--stale finds the comment left in the code" "$(cat "$T/lout/runs.tsv")" $'L0x-1\t6\t2\t1\t0\t1'
python3 "$B/extract-comments" "$T/legacy" "$T/lout2" >/dev/null 2>&1
assert_contains "a pointer to a spec section counts as a label" \
    "$(cat "$T/lout2/runs.tsv")" $'L0x-1\t6\t4\t2\t1\t-'
prose=$(bash "$B/setup-run" "$T/prose" L0p-1)
printf 'The comment saying the runner is keyed by station and row goes.\n' > "$prose/docs/p.md"
python3 "$B/extract-comments" "$T/prose" "$T/pout" --stale 'keyed by station and row' >/dev/null 2>&1
assert_contains "--stale does not read a plan's prose" "$(cat "$T/pout/runs.tsv")" $'L0p-1\t1\t0\t0\t0\t0'

echo "-- score"
S="$T/score"
mkdir -p "$S"
printf 'run\tadded\tcode\tcomment\tlabels\tstale\nA0-1\t10\t10\t2\t1\t1\nA0-2\t0\t0\t0\t0\t0\nA1-1\t5\t5\t1\t0\t-\n' > "$S/runs.tsv"
printf 'id\trun\tfile\tfirst\tlast\tkind\nc001\tA0-1\tx.py\t1\t1\tcomment\nc002\tA0-1\tx.py\t3\t3\tcomment\nc003\tA1-1\tx.py\t1\t1\tcomment\nc004\tA1-1\tx.py\t2\t2\tcomment\n' > "$S/key.tsv"
printf 'id\tcategory\nc001\tnarration\nc002\twhy\nc003\trestatement\nc004\tbloat\n' > "$S/verdicts.tsv"
table=$(python3 "$B/score" "$S")
assert_contains "tallies an arm across its runs" "$table" \
    "| A0 | 2 | 0.5 | 0.0 | 0.0 | 0.5 | 0.0 | 0.0 | 1, 0 | 20% | 1 | 1/2 |"
assert_contains "keeps arms apart, and counts bloat as bad" "$table" \
    "| A1 | 1 | 0.0 | 0.0 | 0.0 | 0.0 | 1.0 | 1.0 | 2 | 20% | 0 | - |"
assert_contains "names the runs that changed nothing" "$table" "no change: A0-2"
printf 'id\tcategory\nc001\tnarration\nc002\t\nc003\trestatement\nc004\tbloat\n' > "$S/verdicts.tsv"
assert_exit "an unjudged comment exits 2" 2 python3 "$B/score" "$S"
printf 'id\tcategory\nc001\tnarration\nc002\tvague\nc003\trestatement\nc004\tbloat\n' > "$S/verdicts.tsv"
assert_exit "an unknown category exits 2" 2 python3 "$B/score" "$S"
printf 'id\tcategory\nc001\tnarration\nc002\twhy\nc003\trestatement\nc004\tbloat\n' > "$S/verdicts.tsv"
printf 'run\tadded\tcode\tcomment\tlabels\tstale\nA0-1\t10\t10\t2\t1\t1\n' > "$S/runs.tsv"
assert_exit "a comment from a run missing from runs.tsv exits 2" 2 python3 "$B/score" "$S"

finish
````

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/scripts/test-baseline-tooling.sh | grep -c FAIL`
Expected: `15`. The first failure is `under the plan's commit message`: `setup-run` still defaults to the other scenarios' fixture and message, so the extraction cases, written against the legacy fixture, find nothing either.

- [ ] **Step 3: Delete what only the other scenarios use**

```bash
B=tests/baselines/writing-code-comments
git rm -rq "$B/fixture" "$B/overlays" "$B/scenarios" \
    "$B/prompts/agent.md" "$B/prompts/implementer.md" "$B/prompts/plan.md"
```

- [ ] **Step 4: Replace `setup-run`**

`tests/baselines/writing-code-comments/setup-run`:

```bash
#!/usr/bin/env bash
# Set up one baseline run: a fresh repository holding the legacy fixture, its
# starting point tagged baseline-base so extract-comments finds what the run
# added even after the run commits its own work. An execution run passes its
# plan as an overlay: it is committed on top of the fixture and becomes the
# starting point.
#
# Usage: setup-run RUNS_DIR LABEL [OVERLAY_DIR]   (prints the run's directory)
set -euo pipefail

USAGE="usage: setup-run RUNS_DIR LABEL [OVERLAY_DIR]"
HERE="$(cd "$(dirname "$0")" && pwd)"
[ $# -eq 2 ] || [ $# -eq 3 ] || { echo "$USAGE" >&2; exit 2; }
run="$1/$2"
[ ! -e "$run" ] || { echo "$run already exists" >&2; exit 1; }

commit() {
    git -C "$run" add -A
    git -C "$run" -c user.name=baseline -c user.email=baseline@localhost commit -qm "$1"
}

mkdir -p "$run"
cp -R "$HERE/legacy-fixture/." "$run/"
find "$run" -name __pycache__ -prune -exec rm -rf {} +
git -C "$run" init -q
commit fixture
if [ $# -eq 3 ]; then
    cp -R "$3/." "$run/"
    commit "plan: Phase 2, unattended import from the inbox"
fi
git -C "$run" tag baseline-base
cd "$run" && pwd
```

- [ ] **Step 5: Reduce `accept` to the legacy modes**

In `tests/baselines/writing-code-comments/accept`:

1. Replace the module docstring with:

```python
"""Check that one baseline run did its task, so a run that did not is replaced before judging.

Usage: accept RUN_DIR legacy-code
       accept RUN_DIR legacy-plan PLAN_PATH

`legacy-code` runs the run's own tests, then checks the legacy fixture's phase spec through the
interfaces the spec fixes: the calibration feature and its dependents gone, the new key, resume from
markers, the poison cap and the exit statuses. `legacy-plan` checks that the plan is committed, has
python code, covers the decisions, has at least five tasks, and that the run changed no code: a plan
run that implemented it would be scored as a plan, and a plan of fewer tasks means the fixture is too
small to test what it was built for.
Prints "ok", or the first check that failed, and exits 0 or 1.
"""
```

2. Delete everything from the line `CHECKS = r'''` up to, not including, the line `LEGACY_CHECKS = r"""`. That removes the old fixture's checks.
3. Rename `LEGACY_CHECKS = r"""` to `CHECKS = r"""`.
4. Replace `check_code`, `check_plan` and `main` with:

```python
def check_code(run):
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1", NO_COLOR="1", PYTHON_COLORS="0",
               PYTHONPATH=os.path.abspath(run))
    tests = subprocess.run([sys.executable, "-m", "unittest", "-q"], cwd=run, env=env,
                           capture_output=True, text=True)
    if tests.returncode != 0:
        return "the run's own tests fail"
    checks = subprocess.run([sys.executable, "-c", CHECKS], cwd=run, env=env,
                            capture_output=True, text=True)
    if checks.returncode != 0:
        lines = checks.stderr.strip().splitlines()
        return lines[-1] if lines else "checks failed"
    return None


def check_plan(run, plan):
    tracked = subprocess.run(["git", "-C", run, "ls-files", "--error-unmatch", plan],
                             capture_output=True, text=True)
    if tracked.returncode != 0:
        return f"{plan} is not committed"
    changed = subprocess.run(["git", "-C", run, "diff", "--quiet", "baseline-base", "--",
                              "readings", "tests"])
    if changed.returncode != 0:
        return "the plan run changed code"
    with open(os.path.join(run, plan), encoding="utf-8") as f:
        text = f.read()
    if len(re.findall(r"^\s*```+py(thon)?\s*$", text, re.M)) < 2:
        return "the plan has fewer than two python code blocks"
    found = len(re.findall(r"^#{2,4} Task \d+", text, re.M))
    if found < 5:
        return f"the plan has {found} tasks, fewer than 5"
    for name in ("readings/calibrate.py", "INBOX_DIR", "POISON_AFTER", "set_marker", "Summary",
                 "readings/cli.py"):
        if name not in text:
            return f"the plan never mentions {name}"
    return None


def main():
    args = sys.argv[1:]
    if len(args) == 2 and args[1] == "legacy-code":
        problem = check_code(args[0])
    elif len(args) == 3 and args[1] == "legacy-plan":
        problem = check_plan(args[0], args[2])
    else:
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        return 2
    print(problem or "ok")
    return 1 if problem else 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 6: Run the tooling test to verify it passes**

Run: `bash tests/scripts/test-baseline-tooling.sh | tail -1`
Expected: `OK`, after 48 `[PASS]` lines.

- [ ] **Step 7: Check that nothing else points at the deleted files**

Run: `git grep -n '[^-]fixture/\|/fixture"\|overlays\|scenarios/\|agent\.md\|implementer\.md\|prompts/plan\.md' -- tests hooks skills README.md`
Expected: no output. Before this task it matches `setup-run` and the tooling test. Plans and specs under `docs/superpowers/` keep their references: they are historical.

- [ ] **Step 8: Run the full suite and commit**

Run: `bash tests/run-tests.sh`. Expected: `all 11 test file(s) passed`.

```bash
git add -A tests/baselines/writing-code-comments tests/scripts/test-baseline-tooling.sh
git commit -m "test: keep only the legacy scenario in the code-comment baseline"
```

---

### Task 2: Micro-test the skill's wording

**Main session only.** It dispatches subagents and reads their output.

**Files:**
- Create: `tests/baselines/writing-code-comments/micro/task.md`, `micro/guidance.md`, `micro/skill-v1.md`, `micro/skill-v2.md`
- Create: `docs/superpowers/plans/2026-09-29-writing-code-comments.baseline/micro/` (results)

**Interfaces:**
- Produces: the chosen variant, V1 or V2, which Task 3 installs as `SKILL.md`.

The micro-test follows `superpowers:writing-skills`' "Micro-Test Wording Before Full Scenarios":
- one fresh-context sample per call, with the realistic context: the whole skill, not the contract alone;
- a no-guidance control;
- five reps per variant;
- every comment read by hand.

The task asks for one plan code block, written from a spec whose decisions carry rejected alternatives and measured numbers. That is the condition under which L0 argued its rulings in comments. Its domain, a log shipper, is in neither fixture nor the skill's example.

- [ ] **Step 1: Write the micro task**

`tests/baselines/writing-code-comments/micro/task.md`:

````markdown
{GUIDANCE}You are writing an implementation plan with superpowers:writing-plans, for a log-shipping agent. The plan's Task 2 creates `shipper/batch.py`. The spec's decisions section reads:

<spec>
### 4.1 Flush a batch by size, not by age

Age-based flushing at 5 s sent 41% of peak-hour batches under 8 KB, and the collector's per-request cost dominated. At peak a 512 KB batch fills in about 2 s, so flushing at 512 KB keeps p99 delivery under 9 s. Off-peak a batch could wait indefinitely; a 30 s ceiling bounds it.

### 4.2 Give up on a batch after five attempts, not retry forever

In 30 days of collector logs, no batch that failed five times later succeeded. Unbounded retries held the spool at 2 GB through the March outage. A batch given up on is moved to `dead/` for a person.

### 4.3 Resume from the offset file, not from the collector's acknowledgements

The collector acknowledges before its own write is durable, so an acknowledgement can outlive a collector crash. The offset file is written only after a 200 and an fsync.
</spec>

Write the code block for Task 2's implementation step: `shipper/batch.py`, with `MAX_BATCH_BYTES`, `MAX_BATCH_AGE_S`, `MAX_ATTEMPTS`, `should_flush(batch, now)`, `after_failure(batch)` (returns `"retry"` or `"dead"`), and `resume_offset(path)`. Write it as it would appear in the plan.

Reply with the python code block only.
````

`tests/baselines/writing-code-comments/micro/guidance.md` (it ends with one blank line):

````markdown
This skill is loaded in your session:

<skill name="dopamine:writing-code-comments">
{SKILL}
</skill>
````

- [ ] **Step 2: Write the two variants**

V2 is the full skill. V1 is the same skill without its `## Common mistakes` table: a table of bad comments could be echoed by the runs, and writing-skills warns that counter-examples can be.

`tests/baselines/writing-code-comments/micro/skill-v2.md`:

````markdown
---
name: writing-code-comments
description: Use when writing or editing a code comment, docstring or doc comment, including one inside a plan's code block
---

# Writing code comments

## Overview

A comment is read later by someone with the code but not the spec, plan or change behind it.

## The contract

> A comment states one of three things: **why** the code is this way — a constraint or a non-obvious reason; the **contract** of a public interface, in the language's standard doc-comment format; or a **warning** a reader needs before changing it. It gives its one reason as briefly as that reason allows. A design's argument — rejected alternatives, measurements behind a number — stays in the spec or the plan's prose. The story of the change goes in the commit message.

## Example

Spec: deduplicate webhook events by id, not payload hash; the provider re-sends events with new timestamps.

```python
def dedupe_key(event):
    # A re-sent event carries a new timestamp; only its id stays the same.
    return event["id"]
```

## Common mistakes

| The comment | Its home |
|---|---|
| Argues against an alternative the code never had | The spec |
| Recites the measurements behind a constant | The spec; the comment says what it guards |
| Says what the next line does | Nowhere |
````

`tests/baselines/writing-code-comments/micro/skill-v1.md` is `skill-v2.md` cut before `## Common mistakes`:

```bash
M=tests/baselines/writing-code-comments/micro
awk '/^## Common mistakes$/{exit} {print}' "$M/skill-v2.md" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > "$M/skill-v1.md"
```

Check: `awk '/^---$/ { s++; next } s >= 2' "$M/skill-v2.md" | wc -w` prints 199, and the same for `skill-v1.md` prints 148.

- [ ] **Step 3: Dispatch fifteen samples**

Fill three prompts from `task.md`:
- **V0:** `{GUIDANCE}` is empty.
- **V1:** `{GUIDANCE}` is `guidance.md` with `{SKILL}` replaced by the whole of `skill-v1.md`.
- **V2:** the same with `skill-v2.md`.

Save them as `.dopamine/run/baseline/micro/prompts/V0.md`, `V1.md` and `V2.md`. Dispatch fifteen `general-purpose` Agent calls, five per prompt, with no model override. Send them in one message, or in three messages of five if one message cannot hold fifteen. Save each reply verbatim as `.dopamine/run/baseline/micro/replies/V<v>-<n>.py.md`.

- [ ] **Step 4: Read every comment**

For each reply, list every comment and docstring in `.dopamine/run/baseline/micro/verdicts.md`. Put each under one of these:
- **ruling**: it argues against a rejected alternative, or recites the measurements behind a value;
- **restatement**: it says what the adjacent code visibly does;
- **narration**: it refers to the change or the process that produced it;
- **good**: a why, a contract or a warning stated once.

End each reply's entry with its four counts. End the file with a table: one row per variant, with the counts summed over its five replies, and a column listing the per-reply ruling counts.

The micro-test is not blind: the replies arrive labelled. GREEN is blind, and it is the gate.

- [ ] **Step 5: Choose the variant**

Apply these in order:

1. **The control must show the failure:** ruling comments in at least 2 of V0's 5 replies. If it does not, rewrite `task.md` once, making the task more tempting: give each decision a second measured number, and ask for the constants and functions in two code blocks. Rerun only V0. If V0 is still clean, record `Ruling: the micro-test's control shows no failure, so it cannot choose a wording; V2 goes to GREEN, which is the gate` in the ledger, and choose V2.
2. **A variant must fix it:** at most 1 ruling comment across its 5 replies, and restatement plus narration no higher than V0's.
3. **A variant must not suppress:** its good comments are at least half of V0's.
4. **Choose between them:**
   - If both variants pass 2 and 3, choose V1, because it is shorter and has no counter-examples to echo.
   - If one passes, choose it.
   - If neither passes, revise the contract's wording in both variants at the point the failing comments slipped through, and rerun V1 and V2. Allow at most two revisions. After a second failed revision, stop and report both attempts to the human.

Record the choice, and the reason for it, at the end of `verdicts.md`.

- [ ] **Step 6: Record and commit**

```bash
D=docs/superpowers/plans/2026-09-29-writing-code-comments.baseline/micro
mkdir -p "$D"
cp -R .dopamine/run/baseline/micro/prompts .dopamine/run/baseline/micro/replies \
      .dopamine/run/baseline/micro/verdicts.md "$D/"
git add tests/baselines/writing-code-comments/micro "$D"
git commit -m "test: micro-test the code-comment contract's wording"
```

---

### Task 3: The skill

**Files:**
- Create: `skills/writing-code-comments/SKILL.md`
- Create: `tests/skills/test-code-comments.sh`
- Modify: `tests/skills/test-skill-structure.sh` (the `BUDGETS` block)

**Interfaces:**
- Consumes: the variant chosen in Task 2 (`micro/skill-v1.md` or `micro/skill-v2.md`), and the ledger's note of it.
- Produces: `skills/writing-code-comments/SKILL.md`, whose `## The contract` section is a single blockquote.

- [ ] **Step 1: Write the failing content test**

`tests/skills/test-code-comments.sh`:

```bash
#!/usr/bin/env bash
# Content assertions for dopamine:writing-code-comments. The structure test
# checks frontmatter and budget; this checks the contract is the one the
# baseline was run against, and that the example cannot be copied into the
# baseline's own fixture.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

skill="$REPO_ROOT/skills/writing-code-comments/SKILL.md"
if [ ! -f "$skill" ]; then
    fail "skills/writing-code-comments/SKILL.md exists" "not found"
    finish
fi
body=$(cat "$skill")

echo "-- the contract"
contract=$(awk '/^## The contract$/{flag=1; next} /^## /{flag=0} flag' "$skill")
assert_contains "the contract is a blockquote, so it can be copied whole" "$contract" "> "
assert_contains "a comment may state why" "$contract" "**why**"
assert_contains "a comment may state a public interface's contract" "$contract" "**contract**"
assert_contains "a comment may state a warning" "$contract" "**warning**"
assert_contains "doc comments follow the language's own format" \
    "$contract" "standard doc-comment format"
assert_contains "one reason, briefly" "$contract" "as briefly as"
assert_contains "a design's argument has a home" "$contract" "the spec or the plan's prose"
assert_contains "the change's story has a home" "$contract" "commit message"

echo "-- what it leaves out"
assert_not_contains "no density clause to negotiate with" "$body" "density"
for word in station reading inbox POISON; do
    assert_not_contains "its example is not the baseline's fixture ($word)" "$body" "$word"
done
assert_eq "no supporting files" "SKILL.md" "$(ls "$REPO_ROOT/skills/writing-code-comments")"

finish
```

- [ ] **Step 2: Add the budget**

In `tests/skills/test-skill-structure.sh`, append these lines to the comment block directly above `BUDGETS=`:

```bash
# writing-code-comments is 200: it loads on most coding sessions, which is the
# frequently-loaded budget superpowers:writing-skills sets.
```

Then add `writing-code-comments:200` as a new entry in the `BUDGETS` string, on its own continuation line after `finishing-work:700`'s line:

```bash
BUDGETS="routing-documentation-updates:600 writing-claude-md:550 finishing-work:700
         writing-code-comments:200
         writing-living-documents:600
```

- [ ] **Step 3: Run both to verify they fail**

Run: `bash tests/skills/test-code-comments.sh | tail -2; bash tests/skills/test-skill-structure.sh | tail -1`
Expected:
- the content test fails on `skills/writing-code-comments/SKILL.md exists`;
- the structure test passes (`OK`), since no such skill exists yet.

- [ ] **Step 4: Install the chosen variant**

```bash
mkdir -p skills/writing-code-comments
cp tests/baselines/writing-code-comments/micro/skill-v<chosen>.md skills/writing-code-comments/SKILL.md
```

with `<chosen>` the variant Task 2 recorded, 1 or 2. If Task 2 revised the wording, the file already holds the revision.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bash tests/skills/test-code-comments.sh | tail -1; bash tests/skills/test-skill-structure.sh | grep writing-code-comments`
Expected: `OK`. The structure test shows `writing-code-comments: within its 200-word budget (199 words)` for V2 and `(148 words)` for V1, with every other `writing-code-comments` line `[PASS]`.

- [ ] **Step 6: Run the full suite and commit**

Run: `bash tests/run-tests.sh`. Expected: `all 12 test file(s) passed`.

```bash
git add skills/writing-code-comments tests/skills/test-code-comments.sh tests/skills/test-skill-structure.sh
git commit -m "feat: writing-code-comments skill"
```

---

### Task 4: The injection

**Files:**
- Modify: `hooks/session-start-context.md`
- Test: `tests/hooks/test-session-start.sh`

**Interfaces:**
- Consumes: the skill name `dopamine:writing-code-comments` from Task 3.
- Produces: the injection text GREEN's runs are given in Task 6.

- [ ] **Step 1: Write the failing test**

In `tests/hooks/test-session-start.sh`, directly after the assertion `names the skill loaded before writing to the instructions file` (it ends with the line `    "$ctx" "dopamine:writing-claude-md"`), add:

```bash
assert_contains "names the skill loaded before writing a code comment" \
    "$ctx" "dopamine:writing-code-comments"
assert_contains "including a comment in a plan's code" "$ctx" "plan's code block"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/hooks/test-session-start.sh | grep FAIL`
Expected: both new assertions FAIL.

- [ ] **Step 3: Add the paragraph**

In `hooks/session-start-context.md`, insert this paragraph, followed by a blank line, before the final paragraph (`At the end of any plan…`):

```markdown
Before writing or editing a code comment, including one in a plan's code block, load `dopamine:writing-code-comments`.
```

- [ ] **Step 4: Run it to verify it passes**

Run: `bash tests/hooks/test-session-start.sh | tail -4`
Expected: `the injection is within its 200-word budget (137 words)`, the prohibition check passes, then `OK`.

- [ ] **Step 5: Run the full suite and commit**

Run: `bash tests/run-tests.sh`. Expected: `all 12 test file(s) passed`.

```bash
git add hooks/session-start-context.md tests/hooks/test-session-start.sh
git commit -m "feat: name writing-code-comments in the session injection"
```

---

### Task 5: The exit gate

**Files:**
- Modify: `skills/finishing-work/SKILL.md` (`## Exit gate`)
- Modify: `tests/skills/test-skill-structure.sh` (finishing-work's exit-gate assertions and its budget)

The draft Phase 2 derived grep terms for this check from the narration comments RED found. There were none, so the check is judgment only.

- [ ] **Step 1: Write the failing test**

In `tests/skills/test-skill-structure.sh`, in the `finishing-work's exit gate` block, directly after the `historical records untouched` assertion, add:

```bash
    assert_contains "added comments meet the comment contract" \
        "$gate" "a why, a contract or a warning"
    assert_contains "the gate counts its own checks correctly" "$gate" "Six checks"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/skills/test-skill-structure.sh | grep FAIL`
Expected: both new assertions FAIL.

- [ ] **Step 3: Edit the gate**

In `skills/finishing-work/SKILL.md`, change `Five checks, run with` to `Six checks, run with`, and after item 5 add:

```markdown
6. **Comments added in the diff state a why, a contract or a warning** — `dopamine:writing-code-comments` holds the contract. Judged over the diff's added lines only.
```

- [ ] **Step 4: Raise finishing-work's budget, with its reason**

The skill was 699 of 700 words before this change, and is 725 after. In `tests/skills/test-skill-structure.sh`, append these lines to the budget comment block, after the `writing-code-comments is 200` lines from Task 3:

```bash
# finishing-work is raised from 700 to 730: its exit gate gains a sixth check,
# for comments added in the diff, and that check has to name the skill that
# holds the contract. Not licence to pad.
```

and change `finishing-work:700` to `finishing-work:730`.

- [ ] **Step 5: Run it to verify it passes**

Run: `bash tests/skills/test-skill-structure.sh | grep -E "finishing-work: within|FAIL|^OK"`
Expected: `finishing-work: within its 730-word budget (725 words)`, then `OK`, and no `FAIL`.

- [ ] **Step 6: Run the full suite and commit**

Run: `bash tests/run-tests.sh`. Expected: `all 12 test file(s) passed`.

```bash
git add skills/finishing-work/SKILL.md tests/skills/test-skill-structure.sh
git commit -m "feat: exit gate checks added comments against the contract"
```

---

### Task 6: GREEN — scenario L with the skill, judged pooled

**Main session only.**

**Files:**
- Create: `tests/baselines/writing-code-comments/prompts/session-context.md`
- Create: `docs/superpowers/plans/2026-09-29-writing-code-comments.baseline/green/` (results)
- Possibly modify: `skills/writing-code-comments/SKILL.md` (REFACTOR only)

**Interfaces:**
- Consumes:
  - `setup-run`, `accept`, `extract-comments` and `score` from Task 1;
  - `prompts/legacy-plan.md` and `prompts/legacy-exec.md`;
  - the skill from Task 3 and the injection from Task 4;
  - the L0 runs in `.dopamine/run/baseline/legacy/plans/` and `execs/`.

**Paths used below:**
- `B=tests/baselines/writing-code-comments`
- `G=.dopamine/run/baseline/green`
- `PLAN=docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md`, the path inside a run
- `SP=~/.claude/plugins/cache/claude-plugins-official/superpowers/6.4.1/skills`

- [ ] **Step 1: Write the session-context slot**

`tests/baselines/writing-code-comments/prompts/session-context.md` (it begins with one blank line):

````markdown

This context was injected at the start of your session:

<session-context>
{INJECTION}
</session-context>

Skills are files; to load one, read it. `dopamine:writing-code-comments` is at {SKILL_PATH}.
````

In it:
- `{INJECTION}` is the whole of `hooks/session-start-context.md`;
- `{SKILL_PATH}` is the absolute path of `skills/writing-code-comments/SKILL.md`.

Filled in, it is the `{LOADED_SKILL}` of every prompt below.

- [ ] **Step 2: Check the L0 runs are still there**

Run: `ls .dopamine/run/baseline/legacy/plans .dopamine/run/baseline/legacy/execs`
Expected: `L0p-1` to `L0p-5` and `L0x-1` to `L0x-5`. If any is missing, stop and report: the pool cannot be rebuilt from the committed results, which keep the runs' diffs but not their repositories.

- [ ] **Step 3: Five plan runs**

```bash
mkdir -p "$G/dispatched-prompts"
for n in 1 2 3 4 5; do bash "$B/setup-run" "$G/plans" "L1p-$n"; done
```

Dispatch five `general-purpose` Agent calls in one message, with no model override. Each prompt is `prompts/legacy-plan.md` with:
- `{RUN_DIR}` the run's absolute path;
- `{WRITING_PLANS}` the absolute path of `$SP/writing-plans/SKILL.md`;
- `{LOADED_SKILL}` the filled session-context slot.

Save each prompt as `$G/dispatched-prompts/L1p-<n>.md`.

- [ ] **Step 4: Check every plan run**

```bash
for r in "$G"/plans/L1p-*; do printf '%s %s\n' "$(basename "$r")" "$(python3 "$B/accept" "$r" legacy-plan "$PLAN")"; done
```

Expected: `ok` for every run.
- A run that is not `ok` is replaced: set up `L1p-6` and upward, dispatch it the same way, and move the failed run to `$G/failed/`.
- Record each replacement and its reason in the ledger.
- The five accepted runs, in label order, are numbered 1–5 for Step 5.

- [ ] **Step 5: Five executions, each from its own plan**

For accepted plan run *k*, with its label written `<Pk>`:

```bash
mkdir -p "$G/overlays/L1x-$k/docs/superpowers/plans"
cp "$G/plans/<Pk>/$PLAN" "$G/overlays/L1x-$k/$PLAN"
bash "$B/setup-run" "$G/execs" "L1x-$k" "$G/overlays/L1x-$k"
```

Record `L1x-k ← <Pk>` in the ledger. Dispatch five `general-purpose` Agent calls in one message, with no model override. Each prompt is `prompts/legacy-exec.md` with:
- `{RUN_DIR}`;
- `{EXECUTING_PLANS}` the absolute path of `$SP/executing-plans/SKILL.md`;
- `{LOADED_SKILL}` as in Step 3.

Save each prompt as `$G/dispatched-prompts/L1x-<k>.md`.

- [ ] **Step 6: Check every execution**

```bash
for r in "$G"/execs/L1x-*; do printf '%s %s\n' "$(basename "$r")" "$(python3 "$B/accept" "$r" legacy-code)"; done
```

Expected: `ok` for every run.
- A run that is not `ok` is replaced once from the same plan, as `L1x-6` and upward, and the failed run moves to `$G/failed/`.
- If the replacement fails too, the plan is unexecutable:
  1. Record that in the ledger.
  2. Keep its L1p run.
  3. Set up and accept one more plan run, and execute that run's plan in its place.
- Record every replacement and its reason in the ledger.

- [ ] **Step 7: Pool with L0, and extract**

```bash
cp -R .dopamine/run/baseline/legacy/plans/. "$G/plans/"
cp -R .dopamine/run/baseline/legacy/execs/. "$G/execs/"
STALE='Keyed by station and row|row numbers are stable'
python3 "$B/extract-comments" "$G/plans" "$G/out/plan" --seed 29 --stale "$STALE"
python3 "$B/extract-comments" "$G/execs" "$G/out/exec" --py-only --seed 29 --stale "$STALE"
```

Leave `$G/failed/` out of the pool: extraction reads only the top level of `plans/` and `execs/`.

- [ ] **Step 8: Judge, blind**

Open only `$G/out/plan/comments.md` and `$G/out/exec/comments.md`. **Do not open any `key.tsv`, `runs.tsv` or `diffs/`, or any run's plan, until every row of both `verdicts.tsv` files is filled.** Agents' final messages are one line, so there is nothing else to read.

Every entry is judged again, the L0 ones included, so that L0 and L1 are scored under one judgment. Give each entry one category:

| Category | The comment |
|---|---|
| `why` | Gives a reason, constraint or cause the code does not show |
| `contract` | Describes a public interface in the language's doc-comment format |
| `warning` | Tells a reader what breaks if they change something |
| `narration` | Refers to the change or the process that produced it: an earlier state ("now", "no longer", "renamed from", "was"), a task, phase or plan step, a review finding, round or ruling, or the absence of something removed |
| `bloat` | A why, contract or warning that argues rather than states: more than one reason where one carries it, a rejected alternative, enumerated defences, or more lines than the code it documents |
| `restatement` | Says what the adjacent code visibly does |

Tie-breaks, in order: anything narrating is `narration`; otherwise anything bloated is `bloat`. A bare pointer to a spec section is not narration by itself.

While judging, list in `$G/out/<stage>/ruling.txt`, one id per line, every `bloat` entry that argues against a rejected alternative or recites the measurements behind a value. Do this for each stage.

- [ ] **Step 9: Score, and apply the pass criteria**

```bash
for stage in plan exec; do
  python3 "$B/score" "$G/out/$stage" > "$G/out/$stage/score.md"
  cat "$G/out/$stage/score.md"
done
for stage in plan exec; do
  echo "$stage ruling comments per arm:"
  grep -Fwf "$G/out/$stage/ruling.txt" "$G/out/$stage/key.tsv" | cut -f2 | cut -d- -f1 | sort | uniq -c
done
```

The plan table has an `L0p` row and an `L1p` row; the exec table has `L0x` and `L1x`. GREEN passes when **all** of the following hold for **both** L1p and L1x:

1. **The failure is gone.** Across the arm's 5 runs, at most 1 ruling comment.
2. **Bad comments stay rare.** The bad-per-run counts sum to at most 2, a mean of 0.4 or less.
3. **Useful comments survive.** The arm's mean why + contract per run is at least half of the matching L0 arm's in this table.

Append the three verdicts, per arm, to `$G/out/plan/score.md`.

- [ ] **Step 10: REFACTOR if it failed, at most twice**

Whether a run loaded the skill cannot be observed: its final message is one line. So the first failed round begins with a diagnostic.

1. **Diagnose.** Set up and dispatch five plan runs, `L1d-1…5`, as in Step 3, but with `{LOADED_SKILL}` set to `micro/guidance.md` filled with the whole of `SKILL.md`: the skill preloaded, not reached through the injection. Accept them as in Step 4.
2. **Revise.** Read the failing comments. Then:
   - If the L1d runs are clean where L1p failed, the contract works and the injection did not get it loaded. Revise the injection's sentence.
   - Otherwise, revise the skill's wording where the comments slipped through.
   - Keep `tests/skills/test-code-comments.sh`, the structure test, the injection test and their budgets passing.
3. **Rerun.** Use fresh labels: `L2p-1…5`, and `L2x-1…5` executing the L2p plans. An L1x failure also reruns the plans, because the executions copy them.
4. **Rejudge.** Repeat Steps 3–9 with those labels. Extraction pools every run again, the L1d runs included, so the whole pool is judged blind once more. The criteria are applied to L2p and L2x.

After a second failed round, stop and report both attempts to the human.

- [ ] **Step 11: Record and commit**

```bash
D=docs/superpowers/plans/2026-09-29-writing-code-comments.baseline/green
mkdir -p "$D"
cp -R "$G/out/plan" "$G/out/exec" "$G/dispatched-prompts" "$D/"
bash tests/run-tests.sh
git add tests/baselines/writing-code-comments/prompts "$D" skills hooks
git commit -m "test: GREEN baseline for code-comment discipline"
```

- [ ] **Step 12: Report to the human**

- Both `score.md` tables, the three criteria per arm, and the ruling-comment counts.
- Every bad L1 comment, quoted, with its arm.
- How L0's verdicts moved between the legacy judging and this one.
- Any REFACTOR round: what the diagnostic showed, and what it changed.

---

### Task 7: README and version

**Files:**
- Modify: `README.md`
- Modify: `.claude-plugin/plugin.json`

- [ ] **Step 1: README**

- In the `## How it works` table, after the `dopamine:writing-claude-md` row, add:
  `| \`dopamine:writing-code-comments\` | What a code comment states — a why, a contract or a warning — and where a design's argument and a change's story go instead |`
- In the `SessionStart` hook row, change `~120 words` to `~140 words`.
- Under `## Known gaps`, add:
  `- **Implementers are not handed the comment contract.** The baseline found that implementers copy a plan's comments and add almost none of their own, so the injection points the plan's author at the skill instead; \`finishing-work\`'s exit gate is the backstop for comments written outside a plan.`

- [ ] **Step 2: Version**

In `.claude-plugin/plugin.json`, change `"version": "0.1.2"` to `"version": "0.1.3"`.

- [ ] **Step 3: Full suite and commit**

Run: `bash tests/run-tests.sh`. Expected: `all 12 test file(s) passed`.

```bash
git add README.md .claude-plugin/plugin.json
git commit -m "docs: describe writing-code-comments; bump version to 0.1.3"
```

- [ ] **Step 4: Close the unit of work**

Invoke `dopamine:finishing-work`, then `superpowers:finishing-a-development-branch`.
