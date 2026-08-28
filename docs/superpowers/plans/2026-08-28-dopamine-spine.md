# Dopamine Slice 1 — The Spine — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the dopamine plugin's spine — a per-repo artifact-map config, a `SessionStart` injection, a `PreToolUse` seal gate, the `seal-ledger` and `sweep-package` scripts, and the `sweep` skill with its three subagent prompts — so that what actually happened during a superpowers loop survives the workspace and drains back into the living documents at a cost that tracks the change.

**Architecture:** A standard Claude Code plugin: `.claude-plugin/plugin.json`, `hooks/` (bash entry points, one Python hook), `skills/` (two skills, colocated scripts), `tests/` (bash, python3 for JSON assertions). Every mechanism is driven by one per-repo file, `.dopamine/config`, that declares which paths hold which artifact tier — the plugin hard-codes no project's document set. Dopamine reads superpowers' artifacts and writes only its own.

**Tech Stack:** Bash 5, git, Python 3 (the seal gate and the tests' JSON assertions). No `jq`, no `node`, no `shellcheck` — none of them are present in the development environment and none may be introduced as a dependency.

**Spec:** `docs/superpowers/specs/2026-08-28-dopamine-design.md`

## Global Constraints

- **Never write anything under `.superpowers/`.** Spec §5: dopamine reads superpowers' artifacts and writes only its own. Everything dopamine creates lives in `.dopamine/` or beside the plan. A change that puts a file inside superpowers' workspace is wrong even if it works.
- **Every mechanism must be O(change), not O(project)** (spec §3). A script that reads whole living documents, or diffs the whole tree, fails this plan's purpose regardless of whether its tests pass.
- **Python 3 is the only runtime dependency beyond bash and git.** A hook that cannot find it exits 0 with a note on stderr — never non-zero, never blocking.
- **Exit-code contract for every script in this plan:** `0` success · `2` bad usage or invalid input · `3` no dopamine config in this repository.
- **The Iron Law of `superpowers:writing-skills` is deliberately waived** for the two skills here, per spec §10: no baseline pressure scenarios are run. Skill tests are therefore **structural** (frontmatter, required sections, word budget, referenced files exist), and skill *wording* follows the measured part of that skill — **Match the Form to the Failure**. Our baseline failure is wrong-shaped output, so guidance is written as a **positive recipe**, never as a prohibition list.
- **Word budgets, enforced by tests:** `hooks/session-start-context.md` ≤ 200 words; `skills/sweep/SKILL.md` ≤ 600 words; `skills/artifact-map/SKILL.md` ≤ 500 words.
- **No `@file` links in skills.** Cross-reference by name (`superpowers:subagent-driven-development`, `dopamine:artifact-map`); `@` force-loads and burns context.
- **Shell style:** every script starts `#!/usr/bin/env bash` and `set -euo pipefail`, prints a `usage:` line to stderr and exits 2 on wrong arguments, and carries a header comment saying *why* it exists, not just what it does.
- **The name `dopamine` is provisional** (spec §13). It appears in the plugin name, the `.dopamine/` directory and the `dopamine:` skill prefix. Do not spread it further than those three places.

---

### Task 1: Plugin scaffold and the artifact-map config resolver

The plugin manifest, the test harness, and `artifact-paths` — the single script that reads `.dopamine/config` and tells every other component which paths hold which tier. Scaffolding is folded in here because this is the first task whose deliverable needs it.

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `.gitignore`
- Create: `skills/sweep/scripts/artifact-paths`
- Create: `tests/helpers.sh`
- Create: `tests/run-tests.sh`
- Test: `tests/scripts/test-artifact-paths.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `skills/sweep/scripts/artifact-paths [--tier TIER] [REPO_ROOT]` — prints one TSV row per declared path, `<tier>\t<path>\t<present|absent>`. Exits `0` ok, `2` malformed config or bad usage, `3` no config. Valid tiers: `living`, `instructions`, `lessons`, `plans`. Also produces the test harness: `tests/helpers.sh` exporting `pass`, `fail`, `assert_eq`, `assert_contains`, `assert_exit`, and `finish`; and `tests/run-tests.sh` which runs every `tests/**/test-*.sh`.

- [ ] **Step 1: Write the failing test**

Create `tests/helpers.sh`:

```bash
#!/usr/bin/env bash
# Shared assertions for dopamine's test scripts. Source this, then call
# `finish` last: it sets the exit status from the failure count.
#
# Every assertion prints one line so a failing run says which case broke
# without the reader opening the test file.

FAILURES=0

pass() { echo "  [PASS] $1"; }

fail() {
    echo "  [FAIL] $1"
    shift
    for line in "$@"; do echo "      $line"; done
    FAILURES=$((FAILURES + 1))
}

assert_eq() {
    local description="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        pass "$description"
    else
        fail "$description" "expected: $expected" "actual:   $actual"
    fi
}

assert_contains() {
    local description="$1" haystack="$2" needle="$3"
    if printf '%s' "$haystack" | grep -qF -- "$needle"; then
        pass "$description"
    else
        fail "$description" "missing: $needle" "in: $haystack"
    fi
}

assert_not_contains() {
    local description="$1" haystack="$2" needle="$3"
    if printf '%s' "$haystack" | grep -qF -- "$needle"; then
        fail "$description" "unexpectedly present: $needle" "in: $haystack"
    else
        pass "$description"
    fi
}

# assert_exit DESCRIPTION EXPECTED_CODE COMMAND...
assert_exit() {
    local description="$1" expected="$2"
    shift 2
    local rc=0
    "$@" >/dev/null 2>&1 || rc=$?
    assert_eq "$description" "$expected" "$rc"
}

finish() {
    if [ "$FAILURES" -eq 0 ]; then
        echo "OK"
        exit 0
    fi
    echo "$FAILURES failure(s)"
    exit 1
}
```

Create `tests/run-tests.sh`:

```bash
#!/usr/bin/env bash
# Run every dopamine test script. One process per file so a crashing test
# cannot take the suite with it.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
failed=0
count=0

while IFS= read -r test; do
    count=$((count + 1))
    echo "=== ${test#"$SCRIPT_DIR"/}"
    if ! bash "$test"; then
        failed=$((failed + 1))
    fi
done < <(find "$SCRIPT_DIR" -name 'test-*.sh' -type f | sort)

echo
if [ "$failed" -eq 0 ]; then
    echo "all $count test file(s) passed"
    exit 0
fi
echo "$failed of $count test file(s) failed"
exit 1
```

Create `tests/scripts/test-artifact-paths.sh`:

```bash
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/scripts/test-artifact-paths.sh`
Expected: FAIL — every case errors because `skills/sweep/scripts/artifact-paths` does not exist.

- [ ] **Step 3: Create the plugin scaffold**

Create `.claude-plugin/plugin.json`:

```json
{
  "name": "dopamine",
  "description": "Documentation discipline for long-horizon work: seals superpowers' execution ledger and drains it back into the living documents at a cost that tracks the change",
  "version": "0.1.0",
  "author": {
    "name": "Wout Gijsbers"
  },
  "homepage": "https://github.com/Woutman/dopamine",
  "repository": "https://github.com/Woutman/dopamine",
  "license": "MIT",
  "keywords": [
    "documentation",
    "skills",
    "long-horizon",
    "superpowers",
    "sweep"
  ]
}
```

Create `.gitignore`:

```
# dopamine's own scratch: sweep diffs and other per-run artifacts.
# The sealed ledger and the sweep brief are NOT here — they are committed
# records that live beside their plan.
.dopamine/run/
```

- [ ] **Step 4: Write the artifact-paths script**

Create `skills/sweep/scripts/artifact-paths`:

```bash
#!/usr/bin/env bash
# Resolve this repository's artifact map: which paths hold which tier of
# document, and whether each one exists yet.
#
# The tiers are the artifact model (see the dopamine:artifact-map skill).
# Only `living` and `instructions` are ever re-read and re-verified by a
# sweep, so this file is what tells the sweep how much surface it owns.
# The plugin hard-codes no project's document set: a repository that has
# not adopted dopamine has no config, and every component stays inert.
#
# A declared document that is absent is a state, not an error. ARCHITECTURE.md
# before there is code to describe is reported `absent` with exit 0 — naming it
# once is how a pending technical brainstorm surfaces without nagging machinery.
#
# Usage: artifact-paths [--tier TIER] [REPO_ROOT]
# Output: one TSV row per declared path — <tier>\t<path>\t(present|absent)
# Exits:  0 ok · 2 malformed config or bad usage · 3 no dopamine config
set -euo pipefail

CONFIG_REL=".dopamine/config"
VALID_TIERS="living instructions lessons plans"

usage() {
    echo "usage: artifact-paths [--tier TIER] [REPO_ROOT]" >&2
    exit 2
}

tier_filter=""
if [ "${1:-}" = "--tier" ]; then
    [ $# -ge 2 ] || usage
    tier_filter=$2
    shift 2
fi
[ $# -le 1 ] || usage

root=${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}
[ -d "$root" ] || { echo "no such directory: $root" >&2; exit 2; }

config="$root/$CONFIG_REL"
[ -f "$config" ] || { echo "no dopamine config at $config" >&2; exit 3; }

trim() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

lineno=0
declared=0
while IFS= read -r raw || [ -n "$raw" ]; do
    lineno=$((lineno + 1))
    line=$(trim "${raw%%#*}")
    [ -n "$line" ] || continue

    case "$line" in
        *:*) ;;
        *) echo "$config:$lineno: not a 'tier: path' line: $line" >&2; exit 2 ;;
    esac

    tier=$(trim "${line%%:*}")
    path=$(trim "${line#*:}")

    case " $VALID_TIERS " in
        *" $tier "*) ;;
        *) echo "$config:$lineno: unknown tier '$tier' (valid: $VALID_TIERS)" >&2; exit 2 ;;
    esac

    [ -n "$path" ] || { echo "$config:$lineno: empty path for tier '$tier'" >&2; exit 2; }
    case "$path" in
        /*) echo "$config:$lineno: path must be relative to the repo root: $path" >&2; exit 2 ;;
        *..*) echo "$config:$lineno: path must be relative to the repo root and must not contain '..': $path" >&2; exit 2 ;;
    esac

    declared=$((declared + 1))
    if [ -n "$tier_filter" ] && [ "$tier" != "$tier_filter" ]; then
        continue
    fi

    if [ -e "$root/$path" ]; then state=present; else state=absent; fi
    printf '%s\t%s\t%s\n' "$tier" "$path" "$state"
done < "$config"

[ "$declared" -gt 0 ] || { echo "$config: declares no paths" >&2; exit 2; }
exit 0
```

- [ ] **Step 5: Make the scripts executable and run the tests**

Run:
```bash
chmod +x skills/sweep/scripts/artifact-paths tests/run-tests.sh tests/scripts/test-artifact-paths.sh
bash tests/scripts/test-artifact-paths.sh
```
Expected: PASS — every assertion, ending in `OK`.

- [ ] **Step 6: Verify the suite runner finds the test**

Run: `bash tests/run-tests.sh`
Expected: PASS, ending in `all 1 test file(s) passed`.

- [ ] **Step 7: Commit**

```bash
git add .claude-plugin/plugin.json .gitignore skills/sweep/scripts/artifact-paths tests/
git commit -m "feat: plugin scaffold and the artifact-map config resolver"
```

---

### Task 2: `seal-ledger`

Copy superpowers' per-plan ledger out of its short-lived workspace and into the plan's own directory, as an immutable dated record. This is the single highest-leverage change in the plugin (spec §4): without it the actuality record is created, used and destroyed.

**Files:**
- Create: `skills/sweep/scripts/seal-ledger`
- Test: `tests/scripts/test-seal-ledger.sh`

**Interfaces:**
- Consumes: nothing from Task 1 at runtime — `seal-ledger` reads superpowers' layout directly, so it works before a repo has a dopamine config.
- Produces: `skills/sweep/scripts/seal-ledger PLAN_FILE` — reads `<repo-root>/.superpowers/sdd/<plan-basename>/progress.md`, writes `<dirname PLAN_FILE>/<plan-basename>.ledger.md` whose first line matches `^# Sealed ledger — plan: .* — sealed: [0-9]{4}-[0-9]{2}-[0-9]{2}$`, and prints `created <path> (<n> lines)` or `updated <path> (<n> lines)`. Exits `0` ok, `2` bad usage, missing plan, missing ledger, or ledger-identity mismatch. **Task 3's seal gate depends on the output filename being exactly `<plan-basename>.ledger.md` in the plan's own directory.**

- [ ] **Step 1: Write the failing test**

Create `tests/scripts/test-seal-ledger.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

UNDER_TEST="$REPO_ROOT/skills/sweep/scripts/seal-ledger"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

# make_repo NAME -- a git repo with a plan; prints the repo path
make_repo() {
    local repo="$TEST_ROOT/$1"
    mkdir -p "$repo/docs/superpowers/plans"
    git init -q "$repo"
    printf '# A plan\n' > "$repo/docs/superpowers/plans/2026-08-28-widget.md"
    printf '%s\n' "$repo"
}

# write_ledger REPO FIRST_LINE -- creates the SDD workspace ledger
write_ledger() {
    local repo="$1" first="$2"
    local ws="$repo/.superpowers/sdd/2026-08-28-widget"
    mkdir -p "$ws"
    {
        printf '%s\n' "$first"
        printf '\n'
        printf 'Task 1: complete — abc1234\n'
        printf 'Ruling: kept the flat schema — nesting bought nothing — costs a migration if we were wrong\n'
    } > "$ws/progress.md"
    printf '%s\n' "$ws/progress.md"
}

echo "-- usage and missing inputs"
assert_exit "exits 2 with no arguments" 2 "$UNDER_TEST"
assert_exit "exits 2 with two arguments" 2 "$UNDER_TEST" a b
assert_exit "exits 2 when the plan file does not exist" 2 "$UNDER_TEST" "$TEST_ROOT/nope.md"

echo "-- a plan that was never executed under SDD"
repo=$(make_repo noledger)
plan="$repo/docs/superpowers/plans/2026-08-28-widget.md"
out=$("$UNDER_TEST" "$plan" 2>&1) && rc=0 || rc=$?
assert_eq "exits 2 when there is no ledger to seal" 2 "$rc"
assert_contains "names the path it looked for" "$out" ".superpowers/sdd/2026-08-28-widget/progress.md"

echo "-- a ledger belonging to a different plan"
repo=$(make_repo foreign)
plan="$repo/docs/superpowers/plans/2026-08-28-widget.md"
write_ledger "$repo" "# SDD ledger — plan: docs/superpowers/plans/2026-08-01-other.md" >/dev/null
out=$("$UNDER_TEST" "$plan" 2>&1) && rc=0 || rc=$?
assert_eq "exits 2 rather than sealing another plan's ledger" 2 "$rc"
assert_contains "says whose ledger it found" "$out" "2026-08-01-other"

echo "-- the happy path"
repo=$(make_repo happy)
plan="$repo/docs/superpowers/plans/2026-08-28-widget.md"
ledger=$(write_ledger "$repo" "# SDD ledger — plan: docs/superpowers/plans/2026-08-28-widget.md")
out=$("$UNDER_TEST" "$plan") && rc=0 || rc=$?
sealed="$repo/docs/superpowers/plans/2026-08-28-widget.ledger.md"
assert_eq "exits 0" 0 "$rc"
assert_eq "the sealed copy lands beside the plan" "yes" "$([ -f "$sealed" ] && echo yes || echo no)"
assert_contains "reports what it created" "$out" "created"

header=$(head -1 "$sealed")
if printf '%s' "$header" | grep -qE '^# Sealed ledger — plan: .* — sealed: [0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    pass "the header carries the plan path and the seal date"
else
    fail "the header carries the plan path and the seal date" "got: $header"
fi

assert_eq "the ledger body is copied verbatim below the header" \
    "$(cat "$ledger")" "$(tail -n +3 "$sealed")"

echo "-- nothing is written inside superpowers' directory"
assert_eq "the SDD workspace still holds only progress.md" \
    "progress.md" "$(ls "$repo/.superpowers/sdd/2026-08-28-widget")"

echo "-- re-sealing after the ledger grows"
printf 'Task 2: complete — def5678\n' >> "$ledger"
out=$("$UNDER_TEST" "$plan")
assert_contains "reports an update rather than a second file" "$out" "updated"
assert_contains "the sealed copy picks up the new line" "$(cat "$sealed")" "def5678"
assert_eq "there is still exactly one sealed ledger" 1 \
    "$(find "$repo/docs/superpowers/plans" -name '*.ledger.md' | wc -l | tr -d ' ')"

finish
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/scripts/test-seal-ledger.sh`
Expected: FAIL — `seal-ledger` does not exist.

- [ ] **Step 3: Write the seal-ledger script**

Create `skills/sweep/scripts/seal-ledger`:

```bash
#!/usr/bin/env bash
# Copy superpowers' per-plan ledger out of its short-lived workspace and into
# the plan's own directory, as an immutable dated record.
#
# The ledger at <repo>/.superpowers/sdd/<plan-basename>/progress.md is created by
# superpowers:subagent-driven-development to survive compaction, and destroyed by
# `rm -rf <workspace>` when that skill finishes. It is the one record of what
# actually happened during execution — the deviations from the plan, recorded as
# they happened — and it is the sweep's input. So it has to outlive the workspace.
#
# Dopamine reads superpowers' file and writes only its own: nothing under
# .superpowers/ is created, modified or removed here.
#
# Re-sealing is deliberate and idempotent. A sweep that slips past the end of the
# loop re-seals to pick up whatever the ledger gained in between, and there is
# still exactly one sealed copy.
#
# Usage:  seal-ledger PLAN_FILE
# Writes: <dirname PLAN_FILE>/<plan-basename>.ledger.md
# Exits:  0 ok · 2 bad usage, missing plan, missing ledger, or identity mismatch
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: seal-ledger PLAN_FILE" >&2; exit 2; }

plan=$1
[ -f "$plan" ] || { echo "no such plan file: $plan" >&2; exit 2; }

plan_dir=$(cd "$(dirname "$plan")" && pwd)
slug=$(basename "$plan" .md)
[ -n "$slug" ] && [ "$slug" != "." ] && [ "$slug" != ".." ] \
    || { echo "cannot derive a plan name from: $plan" >&2; exit 2; }

root=$(git -C "$plan_dir" rev-parse --show-toplevel 2>/dev/null) \
    || { echo "not inside a git repository: $plan" >&2; exit 2; }

ledger="$root/.superpowers/sdd/$slug/progress.md"
[ -f "$ledger" ] || {
    echo "no ledger at $ledger" >&2
    echo "  nothing to seal — this plan was not executed under superpowers:subagent-driven-development" >&2
    exit 2
}

# superpowers writes its ledger identity as the first line:
#   # SDD ledger — plan: <plan file path>
# Match on the plan's basename rather than the whole path: the recorded path may
# be relative to a different directory than the one we were invoked from, and a
# false mismatch here would block a legitimate seal.
first=$(head -1 "$ledger")
case "$first" in
    *"$slug"*) ;;
    *)
        echo "the ledger at $ledger names another plan:" >&2
        echo "  $first" >&2
        echo "  leave it alone and seal it from its own plan file" >&2
        exit 2
        ;;
esac

out="$plan_dir/$slug.ledger.md"
verb=created
[ -e "$out" ] && verb=updated

{
    printf '# Sealed ledger — plan: %s — sealed: %s\n' "$plan" "$(date +%F)"
    printf '\n'
    cat "$ledger"
} > "$out"

echo "$verb $out ($(wc -l < "$out" | tr -d ' ') lines)"
```

- [ ] **Step 4: Run the test to verify it passes**

Run:
```bash
chmod +x skills/sweep/scripts/seal-ledger
bash tests/scripts/test-seal-ledger.sh
```
Expected: PASS, ending in `OK`.

- [ ] **Step 5: Commit**

```bash
git add skills/sweep/scripts/seal-ledger tests/scripts/test-seal-ledger.sh
git commit -m "feat: seal-ledger copies the SDD ledger out of its doomed workspace"
```

---

### Task 3: The `PreToolUse` seal gate

The hook that makes workspace deletion impossible before a sealed copy exists. It does not ask *"is this superpowers?"* — provenance is not observable from a Bash command. It asks *"does a sealed copy of this ledger exist?"*, which is observable, and which is equally true of a human running the same `rm`.

**Files:**
- Create: `hooks/hooks.json`
- Create: `hooks/run-hook.cmd`
- Create: `hooks/seal-gate`
- Create: `hooks/seal_gate.py`
- Test: `tests/hooks/test-seal-gate.sh`

**Interfaces:**
- Consumes: Task 1's `.dopamine/config` format — specifically the `plans` tier, which is how the gate locates `<plans>/<slug>.ledger.md`. Consumes Task 2's output filename contract.
- Produces: `hooks/seal-gate` — a `PreToolUse` hook reading the event JSON on stdin. On deny it writes `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "..."}}` to stdout and exits 0. On allow it writes nothing and exits 0. Produces `hooks/run-hook.cmd`, the cross-platform wrapper Task 5's `session-start` also uses.

- [ ] **Step 1: Write the failing test**

Create `tests/hooks/test-seal-gate.sh`:

```bash
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
out=$(printf '%s' "$(event Bash "$repo" "rm -rf $ws")" \
    | (cd "$repo" && env PATH=/nonexistent bash "$UNDER_TEST") 2>&1) || RC=$?
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/hooks/test-seal-gate.sh`
Expected: FAIL — `hooks/seal-gate` and `hooks/hooks.json` do not exist.

- [ ] **Step 3: Write the hook entry points**

Create `hooks/run-hook.cmd` — a byte-for-byte copy of superpowers' polyglot wrapper, which is why hook scripts here are extensionless:

```bash
: << 'CMDBLOCK'
@echo off
REM Cross-platform polyglot wrapper for hook scripts.
REM On Windows: cmd.exe runs the batch portion, which finds and calls bash.
REM On Unix: the shell interprets this as a script (: is a no-op in bash).
REM
REM Hook scripts use extensionless filenames (e.g. "session-start" not
REM "session-start.sh") so Claude Code's Windows auto-detection -- which
REM prepends "bash" to any command containing .sh -- doesn't interfere.
REM
REM Usage: run-hook.cmd <script-name> [args...]

if "%~1"=="" (
    echo run-hook.cmd: missing script name >&2
    exit /b 1
)

set "HOOK_DIR=%~dp0"

if exist "C:\Program Files\Git\bin\bash.exe" (
    "C:\Program Files\Git\bin\bash.exe" "%HOOK_DIR%%~1" %2 %3 %4 %5 %6 %7 %8 %9
    exit /b %ERRORLEVEL%
)
if exist "C:\Program Files (x86)\Git\bin\bash.exe" (
    "C:\Program Files (x86)\Git\bin\bash.exe" "%HOOK_DIR%%~1" %2 %3 %4 %5 %6 %7 %8 %9
    exit /b %ERRORLEVEL%
)

where bash >nul 2>nul
if %ERRORLEVEL% equ 0 (
    bash "%HOOK_DIR%%~1" %2 %3 %4 %5 %6 %7 %8 %9
    exit /b %ERRORLEVEL%
)

REM No bash found - exit silently rather than error
exit /b 0
CMDBLOCK

# Unix: run the named script directly
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_NAME="$1"
shift
exec bash "${SCRIPT_DIR}/${SCRIPT_NAME}" "$@"
```

Create `hooks/seal-gate`:

```bash
#!/usr/bin/env bash
# Locate a Python 3 interpreter and hand it the seal gate.
#
# Python 3 is dopamine's only runtime dependency beyond bash and git. If none is
# present the gate exits 0 with a note on stderr rather than failing: the gate is
# a backstop, and a gate that cannot run must never block every Bash call in the
# session. Failing open loses the guarantee; failing closed loses the session.
set -u
export PYTHONUTF8=1

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

for cmd in python3 python "py -3"; do
    # shellcheck disable=SC2086
    if $cmd -c 'import sys; sys.exit(0 if sys.version_info[0] == 3 else 1)' >/dev/null 2>&1; then
        # shellcheck disable=SC2086
        exec $cmd "$SCRIPT_DIR/seal_gate.py"
    fi
done

echo "dopamine: no Python 3 interpreter found; the seal gate is inactive this session." >&2
exit 0
```

Create `hooks/hooks.json`:

```json
{
  "description": "dopamine — documentation discipline for long-horizon work",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start",
            "shell": "bash",
            "async": false
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" seal-gate",
            "shell": "bash",
            "async": false
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 4: Write the gate itself**

Create `hooks/seal_gate.py`:

```python
#!/usr/bin/env python3
"""PreToolUse gate: refuse to delete a superpowers SDD workspace whose ledger has
not been sealed.

The question this hook asks is NOT "is this superpowers?" — provenance is not
observable from a Bash command, and it is not the point. It asks "does a sealed
copy of this ledger exist?", which is observable, has no false positives on a
drained workspace, and correctly stops a human running the same rm, since that
destroys the same record.

Silent no-op unless all of these hold:
  * the tool is Bash,
  * the command deletes something,
  * a deleted path is a .superpowers/sdd/<slug> workspace,
  * the repository has a .dopamine/config declaring where plans live,
  * and <plans>/<slug>.ledger.md does not exist.

Known gap, accepted: a command that names the workspace only through a shell
variable (`rm -rf "$dir"`) carries no literal path, so the gate cannot see it.
superpowers' own Finish step writes the path literally, which is the case that
matters.
"""

import json
import os
import re
import subprocess
import sys

# A workspace path as it appears inside a shell command, with the surrounding
# quoting and separators excluded from the slug.
WORKSPACE_RE = re.compile(
    r"(?:[^\s'\";|&]*/)?\.superpowers/sdd/(?P<slug>[^/\s'\";|&]+)"
)
DELETE_RE = re.compile(r"(?:^|[;&|]|\s)(?:rm|rmdir|trash)(?:\s|$)")

SEAL_HINT = "skills/sweep/scripts/seal-ledger"


def read_event():
    try:
        return json.load(sys.stdin)
    except (ValueError, OSError):
        return None


def repo_root(cwd):
    try:
        result = subprocess.run(
            ["git", "-C", cwd, "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    root = result.stdout.strip()
    return root or None


def plans_dir(root):
    """Return the absolute plans directory from .dopamine/config, or None.

    None means this repository has not adopted dopamine, and every dopamine
    mechanism stays inert in it.
    """
    config = os.path.join(root, ".dopamine", "config")
    if not os.path.isfile(config):
        return None
    try:
        with open(config, encoding="utf-8") as handle:
            for raw in handle:
                line = raw.split("#", 1)[0].strip()
                if ":" not in line:
                    continue
                tier, _, path = line.partition(":")
                if tier.strip() == "plans" and path.strip():
                    return os.path.join(root, path.strip())
    except OSError:
        return None
    return None


def seal_command(root, plans, slug):
    plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT")
    script = os.path.join(plugin_root, SEAL_HINT) if plugin_root else "seal-ledger"
    return "{script} {plans}/{slug}.md".format(
        script=script,
        plans=os.path.relpath(plans, root),
        slug=slug,
    )


def deny(reason):
    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason,
            }
        },
        sys.stdout,
    )
    sys.stdout.write("\n")


def main():
    event = read_event()
    if not isinstance(event, dict) or event.get("tool_name") != "Bash":
        return 0

    command = (event.get("tool_input") or {}).get("command") or ""
    if not DELETE_RE.search(command):
        return 0

    slugs = sorted({match.group("slug") for match in WORKSPACE_RE.finditer(command)})
    if not slugs:
        return 0

    root = repo_root(event.get("cwd") or os.getcwd())
    if root is None:
        return 0

    plans = plans_dir(root)
    if plans is None:
        return 0

    unsealed = [s for s in slugs if not os.path.isfile(os.path.join(plans, s + ".ledger.md"))]
    if not unsealed:
        return 0

    slug = unsealed[0]
    expected = os.path.relpath(os.path.join(plans, slug + ".ledger.md"), root)
    deny(
        "This deletes the SDD workspace for '{slug}', whose ledger is not sealed: "
        "{expected} does not exist.\n"
        "That ledger is the only record of what actually happened during execution, "
        "and it is the sweep's input. Deleting the workspace destroys it.\n"
        "Seal it first:\n"
        "  {command}\n"
        "Then run the dopamine:sweep skill. This deletion passes once the sealed "
        "copy exists.".format(
            slug=slug, expected=expected, command=seal_command(root, plans, slug)
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 5: Run the test to verify it passes**

Run:
```bash
chmod +x hooks/seal-gate hooks/run-hook.cmd
bash tests/hooks/test-seal-gate.sh
```
Expected: PASS, ending in `OK`. The `hooks.json` wiring assertions pass even though `hooks/session-start` does not exist yet — Task 5 creates it.

- [ ] **Step 6: Commit**

```bash
git add hooks/ tests/hooks/test-seal-gate.sh
git commit -m "feat: PreToolUse gate denies workspace deletion until the ledger is sealed"
```

---

### Task 4: `sweep-package`

Write the sweep's diff — scoped to the documents this repository declares — to a file, so the diff never enters the controller's context. Scoping is not tidiness: an unscoped branch diff is O(project), which is the cost this plugin exists to avoid.

**Files:**
- Create: `skills/sweep/scripts/sweep-package`
- Test: `tests/scripts/test-sweep-package.sh`

**Interfaces:**
- Consumes: Task 1's `artifact-paths`, invoked as a sibling in the same directory.
- Produces: `skills/sweep/scripts/sweep-package PLAN_FILE BASE HEAD [OUTFILE]` — writes `# Sweep package: BASE..HEAD` followed by `## Commits`, `## Files changed` and `## Diff` sections, all restricted to the `living`, `instructions` and `lessons` paths. Default OUTFILE is `<repo-root>/.dopamine/run/<plan-basename>-sweep-<base7>..<head7>.diff`. Prints `wrote <path> (<n> bytes)`. Exits `0` ok, `2` bad usage or bad revision, `3` no dopamine config.

- [ ] **Step 1: Write the failing test**

Create `tests/scripts/test-sweep-package.sh`:

```bash
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/scripts/test-sweep-package.sh`
Expected: FAIL — `sweep-package` does not exist.

- [ ] **Step 3: Write the sweep-package script**

Create `skills/sweep/scripts/sweep-package`:

```bash
#!/usr/bin/env bash
# Write the sweep's diff — commits, stat summary and the net diff — to a file the
# verifier reads in one call, so the diff never enters the controller's context.
#
# The diff is restricted to the documents this repository declares as swept
# surface. That restriction is the point, not an optimisation: an unscoped diff of
# a feature branch is O(project), which is exactly the cost this plugin exists to
# avoid. The `plans` tier is excluded — plans and sealed ledgers are immutable
# records, never swept.
#
# Output goes under .dopamine/run/, git-ignored, because dopamine writes only its
# own artifacts and never inside .superpowers/.
#
# Usage:  sweep-package PLAN_FILE BASE HEAD [OUTFILE]
# Default OUTFILE: <repo-root>/.dopamine/run/<plan-basename>-sweep-<base7>..<head7>.diff
# Exits:  0 ok · 2 bad usage or bad revision · 3 no dopamine config
set -euo pipefail

[ $# -ge 3 ] && [ $# -le 4 ] \
    || { echo "usage: sweep-package PLAN_FILE BASE HEAD [OUTFILE]" >&2; exit 2; }

plan=$1
base=$2
head_rev=$3
[ -f "$plan" ] || { echo "no such plan file: $plan" >&2; exit 2; }

here=$(cd "$(dirname "$0")" && pwd)
plan_dir=$(cd "$(dirname "$plan")" && pwd)
root=$(git -C "$plan_dir" rev-parse --show-toplevel 2>/dev/null) \
    || { echo "not inside a git repository: $plan" >&2; exit 2; }

git -C "$root" rev-parse --verify --quiet "$base" >/dev/null \
    || { echo "bad BASE: $base" >&2; exit 2; }
git -C "$root" rev-parse --verify --quiet "$head_rev" >/dev/null \
    || { echo "bad HEAD: $head_rev" >&2; exit 2; }

# Propagate artifact-paths' own exit code: 3 (no config) must not look like 2.
set +e
map=$("$here/artifact-paths" "$root")
map_rc=$?
set -e
[ "$map_rc" -eq 0 ] || exit "$map_rc"

paths=()
while IFS=$'\t' read -r tier path _state; do
    if [ "$tier" = "plans" ]; then
        continue
    fi
    paths+=("$path")
done <<< "$map"

[ "${#paths[@]}" -gt 0 ] || {
    echo "$root/.dopamine/config declares no swept documents (living, instructions or lessons)" >&2
    exit 2
}

if [ $# -eq 4 ]; then
    out=$4
else
    dir="$root/.dopamine/run"
    mkdir -p "$dir"
    printf '*\n' > "$dir/.gitignore"
    out="$dir/$(basename "$plan" .md)-sweep-$(git -C "$root" rev-parse --short "$base")..$(git -C "$root" rev-parse --short "$head_rev").diff"
fi

{
    echo "# Sweep package: ${base}..${head_rev}"
    echo "# Scoped to the documents declared in .dopamine/config"
    echo
    echo "## Commits"
    git -C "$root" log --oneline "${base}..${head_rev}" -- "${paths[@]}"
    echo
    echo "## Files changed"
    git -C "$root" diff --stat "${base}..${head_rev}" -- "${paths[@]}"
    echo
    echo "## Diff"
    git -C "$root" diff -U10 "${base}..${head_rev}" -- "${paths[@]}"
} > "$out"

echo "wrote $out ($(wc -c < "$out" | tr -d ' ') bytes)"
```

- [ ] **Step 4: Run the test to verify it passes**

Run:
```bash
chmod +x skills/sweep/scripts/sweep-package
bash tests/scripts/test-sweep-package.sh
```
Expected: PASS, ending in `OK`.

- [ ] **Step 5: Commit**

```bash
git add skills/sweep/scripts/sweep-package tests/scripts/test-sweep-package.sh
git commit -m "feat: sweep-package writes a diff scoped to the declared documents"
```

---

### Task 5: The `SessionStart` injection

The ~110 words that position dopamine relative to superpowers, injected at every session start — but only in a repository that has adopted dopamine. Every line is phrased as what dopamine *adds on top of* what superpowers already does, so an agent cannot read it as an instruction to keep a parallel log.

**Files:**
- Create: `hooks/session-start`
- Create: `hooks/session-start-context.md`
- Test: `tests/hooks/test-session-start.sh`

**Interfaces:**
- Consumes: `hooks/run-hook.cmd` from Task 3; the presence of `.dopamine/config` from Task 1.
- Produces: `hooks/session-start` — writes `{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "..."}}` when `CLAUDE_PLUGIN_ROOT` is set, `{"additional_context": "..."}` under Cursor, `{"additionalContext": "..."}` otherwise; writes nothing at all when the repository has no `.dopamine/config`. Always exits 0.

- [ ] **Step 1: Write the failing test**

Create `tests/hooks/test-session-start.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

UNDER_TEST="$REPO_ROOT/hooks/session-start"
CONTEXT_FILE="$REPO_ROOT/hooks/session-start-context.md"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

adopted="$TEST_ROOT/adopted"
mkdir -p "$adopted/.dopamine"
git init -q "$adopted"
printf 'living: docs/DESIGN.md\nplans: docs/superpowers/plans\n' > "$adopted/.dopamine/config"

plain="$TEST_ROOT/plain"
mkdir -p "$plain"
git init -q "$plain"

# field JSON PATH -- prints a dotted field, or "none"
field() {
    printf '%s' "$1" | FIELD="$2" python3 -c '
import json, os, sys
raw = sys.stdin.read().strip()
if not raw:
    print("none"); raise SystemExit
node = json.loads(raw)
for part in os.environ["FIELD"].split("."):
    if not isinstance(node, dict) or part not in node:
        print("none"); raise SystemExit
    node = node[part]
print(node)'
}

echo "-- inert where dopamine has not been adopted"
RC=0
out=$( (cd "$plain" && CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$UNDER_TEST") ) || RC=$?
assert_eq "exits 0" 0 "$RC"
assert_eq "injects nothing when there is no .dopamine/config" "" "$out"

echo "-- Claude Code shape"
out=$( (cd "$adopted" && CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$UNDER_TEST") )
ctx=$(field "$out" "hookSpecificOutput.additionalContext")
assert_eq "uses the nested hookSpecificOutput shape" \
    "SessionStart" "$(field "$out" "hookSpecificOutput.hookEventName")"
assert_not_contains "and not Cursor's flat shape" "$out" "additional_context"

echo "-- Cursor and SDK shapes"
out=$( (cd "$adopted" && CURSOR_PLUGIN_ROOT="$REPO_ROOT" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$UNDER_TEST") )
assert_not_contains "Cursor gets additional_context only" "$out" "hookSpecificOutput"
out=$( (cd "$adopted" && COPILOT_CLI=1 CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$UNDER_TEST") )
assert_not_contains "Copilot CLI gets the flat SDK shape" "$out" "hookSpecificOutput"

echo "-- what the injection actually says"
assert_contains "names the sweep skill, so the agent can find it" "$ctx" "sweep"
assert_contains "points at superpowers' existing ledger" "$ctx" "ledger"
assert_contains "names the living documents it governs" "$ctx" "living document"

words=$(wc -w < "$CONTEXT_FILE" | tr -d ' ')
if [ "$words" -le 200 ]; then
    pass "the injection is within its 200-word budget ($words words)"
else
    fail "the injection is within its 200-word budget" "got: $words words"
fi

echo "-- the injection is a conditional, not a prohibition"
if grep -qiE '\b(never|do not|don.t)\b' "$CONTEXT_FILE"; then
    fail "avoids prohibition form (spec 9.4: our failure is wrong-shaped output)" \
         "found a prohibition in $CONTEXT_FILE"
else
    pass "avoids prohibition form (spec 9.4: our failure is wrong-shaped output)"
fi

finish
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/hooks/test-session-start.sh`
Expected: FAIL — `hooks/session-start` does not exist.

- [ ] **Step 3: Write the injected text**

Create `hooks/session-start-context.md` — the spec §9.1 draft, adjusted only so it passes its own prohibition check by stating the positive form:

```markdown
**Documentation discipline (add-on to superpowers)**

This project has living documents — listed in `.dopamine/config` — that describe the present. **They change at one moment only: the sweep.** Superpowers' ledger already records what happened during execution; that record is the sweep's input, and it is the only journal you keep.

If you find yourself about to change a living document mid-execution, record it in the ledger instead and let the sweep place it.

At the end of any plan or ad-hoc unit of work, and before the workspace is cleaned up, invoke the `dopamine:sweep` skill.
```

- [ ] **Step 4: Write the hook**

Create `hooks/session-start`:

```bash
#!/usr/bin/env bash
# SessionStart hook for the dopamine plugin.
#
# Silent in a repository that has not adopted dopamine. With no .dopamine/config
# there are no living documents to name, and injecting instructions about
# documents that do not exist is how a plugin earns being disabled.
#
# The JSON shapes below mirror superpowers' session-start: Claude Code reads both
# additional_context and hookSpecificOutput without deduplication, so exactly one
# field is emitted per platform.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

root=$(git rev-parse --show-toplevel 2>/dev/null || true)
[ -n "$root" ] || exit 0
[ -f "$root/.dopamine/config" ] || exit 0

context_file="${PLUGIN_ROOT}/hooks/session-start-context.md"
[ -f "$context_file" ] || exit 0
content=$(cat "$context_file")

# Escape for JSON embedding using bash parameter substitution — each ${s//old/new}
# is a single C-level pass.
escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

escaped=$(escape_for_json "$content")

# printf rather than a heredoc: bash 5.3+ hangs on heredocs in this position.
if [ -n "${CURSOR_PLUGIN_ROOT:-}" ]; then
    printf '{\n  "additional_context": "%s"\n}\n' "$escaped" | cat
elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -z "${COPILOT_CLI:-}" ]; then
    printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  }\n}\n' "$escaped" | cat
else
    printf '{\n  "additionalContext": "%s"\n}\n' "$escaped" | cat
fi

exit 0
```

- [ ] **Step 5: Run the test to verify it passes**

Run:
```bash
chmod +x hooks/session-start
bash tests/hooks/test-session-start.sh
```
Expected: PASS, ending in `OK`.

- [ ] **Step 6: Commit**

```bash
git add hooks/session-start hooks/session-start-context.md tests/hooks/test-session-start.sh
git commit -m "feat: SessionStart injection, silent until a repo adopts dopamine"
```

---

### Task 6: The `artifact-map` reference skill

The artifact model in one place, pointed at by every recipe. Spec §8 calls for "a shared reference file… so the map itself has one home"; a reference skill is that file, and it can be cross-referenced by name (`dopamine:artifact-map`) instead of by a fragile relative path from a sibling skill's directory.

**Files:**
- Create: `skills/artifact-map/SKILL.md`
- Test: `tests/skills/test-skill-structure.sh`

Budgets live in one table inside the test (`BUDGETS`): `artifact-map:500 sweep:600`.

**Interfaces:**
- Consumes: nothing.
- Produces: `skills/artifact-map/SKILL.md`, and `tests/skills/test-skill-structure.sh`, which Task 7 extends. The structural test exports no functions; it walks `skills/*/SKILL.md` and applies the same checks to each, plus per-skill word budgets read from a table inside the test.

- [ ] **Step 1: Write the failing test**

Create `tests/skills/test-skill-structure.sh`:

```bash
#!/usr/bin/env bash
# Structural tests for every skill in the plugin.
#
# The Iron Law of superpowers:writing-skills — no skill without a failing
# pressure-scenario test first — is deliberately waived here (spec section 10).
# These tests therefore check structure and budget, not behaviour: frontmatter is
# valid, the description is a trigger rather than a workflow summary, referenced
# files exist, no @-link force-loads context, and the word budget holds.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

# skill-name:max-words
BUDGETS="artifact-map:500 sweep:600"

budget_for() {
    local name="$1" entry
    for entry in $BUDGETS; do
        if [ "${entry%%:*}" = "$name" ]; then
            printf '%s' "${entry#*:}"
            return 0
        fi
    done
    printf '%s' "0"
}

frontmatter_field() {
    FILE="$1" KEY="$2" python3 -c '
import os, sys
lines = open(os.environ["FILE"], encoding="utf-8").read().split("\n")
if not lines or lines[0].strip() != "---":
    print(""); raise SystemExit
for line in lines[1:]:
    if line.strip() == "---":
        break
    key, _, value = line.partition(":")
    if key.strip() == os.environ["KEY"]:
        print(value.strip()); raise SystemExit
print("")'
}

found=0
for skill_md in "$REPO_ROOT"/skills/*/SKILL.md; do
    [ -f "$skill_md" ] || continue
    found=$((found + 1))
    dir=$(dirname "$skill_md")
    name=$(basename "$dir")
    echo "-- $name"

    fm_name=$(frontmatter_field "$skill_md" name)
    assert_eq "$name: frontmatter name matches its directory" "$name" "$fm_name"

    desc=$(frontmatter_field "$skill_md" description)
    case "$desc" in
        "Use when"*) pass "$name: description starts with 'Use when'" ;;
        "") fail "$name: description starts with 'Use when'" "no description field" ;;
        *) fail "$name: description starts with 'Use when'" "got: $desc" ;;
    esac

    if [ "${#desc}" -le 500 ]; then
        pass "$name: description is under 500 characters (${#desc})"
    else
        fail "$name: description is under 500 characters" "got: ${#desc}"
    fi

    if printf '%s' "$desc" | grep -qE '(then|,) *(dispatch|write|run|review)'; then
        fail "$name: description states triggers, not the workflow" "got: $desc"
    else
        pass "$name: description states triggers, not the workflow"
    fi

    body=$(awk '/^---$/ { seen++; next } seen >= 2' "$skill_md")
    words=$(printf '%s' "$body" | wc -w | tr -d ' ')
    max=$(budget_for "$name")
    if [ "$max" = "0" ]; then
        fail "$name: has a declared word budget" "add it to BUDGETS in this test"
    elif [ "$words" -le "$max" ]; then
        pass "$name: within its $max-word budget ($words words)"
    else
        fail "$name: within its $max-word budget" "got: $words words"
    fi

    if grep -qE '^\s*@[a-zA-Z./]' "$skill_md"; then
        fail "$name: uses no @-link force-loads" "found an @ link"
    else
        pass "$name: uses no @-link force-loads"
    fi

    # Every relative markdown link and backticked sibling file must exist.
    missing=""
    while IFS= read -r ref; do
        [ -n "$ref" ] || continue
        [ -e "$dir/$ref" ] || missing="$missing $ref"
    done < <({
        grep -oE '\[[^]]*\]\(([a-zA-Z0-9._/-]+\.md)\)' "$skill_md" | sed -E 's/.*\((.*)\)/\1/'
        grep -oE '`[a-zA-Z0-9._-]+\.md`' "$skill_md" | tr -d '`'
    } | sort -u)
    if [ -z "$missing" ]; then
        pass "$name: every referenced file exists"
    else
        fail "$name: every referenced file exists" "missing:$missing"
    fi
done

assert_eq "at least one skill was checked" "yes" "$([ "$found" -gt 0 ] && echo yes || echo no)"

echo "-- artifact-map content"
map="$REPO_ROOT/skills/artifact-map/SKILL.md"
if [ -f "$map" ]; then
    body=$(cat "$map")
    for tier in Living Instructions Append-mostly Immutable Consumed; do
        assert_contains "the map names the $tier tier" "$body" "$tier"
    done
    assert_contains "the map says which tiers are verified" "$body" "verified"
    assert_contains "the map routes a number describing a run to the ledger" "$body" "sealed ledger"
else
    fail "skills/artifact-map/SKILL.md exists" "not found"
fi

finish
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/skills/test-skill-structure.sh`
Expected: FAIL — no skills exist, so `at least one skill was checked` fails along with the artifact-map content checks.

- [ ] **Step 3: Write the artifact-map skill**

Create `skills/artifact-map/SKILL.md`:

```markdown
---
name: artifact-map
description: Use when deciding where a fact belongs — a lesson, a measured number, a decision, a constraint — or when a document is growing and it is not obvious which of them should hold what
---

# Artifact map

## Overview

Which tier a document belongs to decides how much it costs. **Only the first two tiers are ever re-read and re-verified**, so the discipline is to push content out of them wherever it legitimately can go.

The tiers are not tidiness. They are a cost model.

## The tiers

| Kind | Typical files | At sweep |
|---|---|---|
| **Living** — describes the present | `DESIGN.md`, `ARCHITECTURE.md`, `ROADMAP.md` | Drained **and verified** |
| **Instructions** — highest read frequency | `CLAUDE.md` | Drained, verified, **plus an admission test** |
| **Append-mostly** — dated observations, reached by grep | `LESSONS.md` | Drained, **never verified** |
| **Immutable** — intent and actuality | `specs/`, `plans/`, sealed ledgers, sweep briefs | Never touched |
| **Consumed** — deleted when discharged | handoffs | n/a |

This repository's own paths are declared in `.dopamine/config`; `skills/sweep/scripts/artifact-paths` prints them.

## Where each kind of fact goes

| The fact | Its home | Why |
|---|---|---|
| A number describing **the system now** — the current gate, the current cost | A living document, **replaced** on change, as a bounded set | It describes the present, so it is verified like everything else there |
| A number describing **a run** | The **sealed ledger**, cited by reference | It was true of one execution and stays true of it; restating it elsewhere is what makes figures drift |
| What we decided and why | Spec (what we meant) plus the **sealed ledger** (what we actually did) | The deviation between them is the decision archive |
| A dated observation that stays true — "we tried X, it failed because Y" | `LESSONS.md`, with the error text, symbol and version a future agent would grep for | Nothing consults it as current truth, so it never needs verifying |
| A prescription — "do not use X" | A living document or `CLAUDE.md` | A prescription **does** go stale, so it has to sit where staleness is checked |

## Common mistakes

- **Filing a prescription as a lesson.** "We tried X on 2026-08-28 and it failed because Y" stays true forever. "Do not use X" stops being true when the library is fixed. Only the first shape earns the never-verified tier.
- **Letting a run's number into a living document.** It then has to be defended at every sweep, and it will drift from the run that produced it.
- **Putting design rationale in `CLAUDE.md`.** It reads perfectly well there and is paid for on every session while duplicating the design document.
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/skills/test-skill-structure.sh`
Expected: PASS. The `sweep` budget entry is unused until Task 7 — the loop only checks skills that exist.

- [ ] **Step 5: Commit**

```bash
git add skills/artifact-map/SKILL.md tests/skills/test-skill-structure.sh
git commit -m "feat: artifact-map reference skill and structural skill tests"
```

---

### Task 7: The `sweep` skill and its three subagent prompts

Dopamine's own execution→verification cycle. It borrows superpowers' shape — brief, fresh implementer, fresh reviewer that does not trust the report — and owns every part of it. Written as a **positive recipe**: our baseline failure is wrong-shaped output, and prohibition form measurably backfires on that failure (spec §9.4).

**Files:**
- Create: `skills/sweep/SKILL.md`
- Create: `skills/sweep/discovery-prompt.md`
- Create: `skills/sweep/implementer-prompt.md`
- Create: `skills/sweep/verifier-prompt.md`
- Modify: `tests/skills/test-skill-structure.sh` (append a sweep-content section before `finish`)

**Interfaces:**
- Consumes: `skills/sweep/scripts/seal-ledger` (Task 2), `skills/sweep/scripts/sweep-package` (Task 4), `skills/sweep/scripts/artifact-paths` (Task 1), and `dopamine:artifact-map` (Task 6).
- Produces: the `dopamine:sweep` skill, referenced by name from the SessionStart injection.

- [ ] **Step 1: Write the failing test**

Append to `tests/skills/test-skill-structure.sh`, immediately before the final `finish` line:

```bash
echo "-- sweep content"
sweep="$REPO_ROOT/skills/sweep/SKILL.md"
if [ -f "$sweep" ]; then
    body=$(cat "$sweep")
    assert_contains "the recipe seals before it drains" "$body" "seal-ledger"
    assert_contains "discovery covers every document in one pass" "$body" "discovery-prompt.md"
    assert_contains "execution works from the brief alone" "$body" "implementer-prompt.md"
    assert_contains "verification runs against a scoped package" "$body" "sweep-package"
    assert_contains "the verifier prompt is referenced" "$body" "verifier-prompt.md"
    assert_contains "the fix loop is capped" "$body" "two rounds"
    assert_contains "nothing to drain is a legitimate outcome" "$body" "nothing to drain"
    assert_contains "it points at the artifact map rather than restating it" "$body" "dopamine:artifact-map"

    discovery="$REPO_ROOT/skills/sweep/discovery-prompt.md"
    if [ -f "$discovery" ]; then
        dbody=$(cat "$discovery")
        for kind in Edits Negatives Promotions; do
            assert_contains "the brief defines the $kind entry kind" "$dbody" "$kind"
        done
        assert_contains "an edit entry is located and quoted" "$dbody" "quoted"
        assert_contains "discovery reads documents only along grep terms" "$dbody" "grep"
        assert_contains "discovery does not read documents in bulk" "$dbody" "in bulk"
    else
        fail "skills/sweep/discovery-prompt.md exists" "not found"
    fi

    verifier="$REPO_ROOT/skills/sweep/verifier-prompt.md"
    if [ -f "$verifier" ]; then
        vbody=$(cat "$verifier")
        for verdict in Placement Discipline "Drain completeness"; do
            assert_contains "the verifier returns a $verdict verdict" "$vbody" "$verdict"
        done
        assert_contains "the verifier re-derives its own grep terms" "$vbody" "independently"
        assert_contains "the verifier does not trust the report" "$vbody" "not trust"
        assert_contains "a listed location the diff never touches is Missing" "$vbody" "Missing"
    else
        fail "skills/sweep/verifier-prompt.md exists" "not found"
    fi

    impl="$REPO_ROOT/skills/sweep/implementer-prompt.md"
    if [ -f "$impl" ]; then
        ibody=$(cat "$impl")
        assert_contains "the implementer changes what changed" "$ibody" "Change what changed"
        assert_contains "the implementer leaves historical records alone" "$ibody" "historical"
    else
        fail "skills/sweep/implementer-prompt.md exists" "not found"
    fi
else
    fail "skills/sweep/SKILL.md exists" "not found"
fi
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/skills/test-skill-structure.sh`
Expected: FAIL — `skills/sweep/SKILL.md exists` and the three prompt checks all fail.

- [ ] **Step 3: Write the sweep skill**

Create `skills/sweep/SKILL.md`:

```markdown
---
name: sweep
description: Use when a superpowers plan or an ad-hoc unit of work is finished and before its workspace is cleaned up, or when a living document has fallen behind what the code now does
---

# Sweep

## Overview

A sweep carries what actually happened during one unit of work back into the documents that describe the present.

Its inputs are the **sealed ledger** and the **unit's diff** — never the documents in bulk. It reaches into a document only along grep terms derived from those two inputs. That is the whole cost argument: a sweep's work tracks the change, not the size of the project.

**REQUIRED BACKGROUND:** Use dopamine:artifact-map — which tier a fact belongs to decides where every edit lands.

## The recipe

Seal, then drain. Four stages, in order.

### 1. Seal

Run `scripts/seal-ledger PLAN_FILE`. It copies superpowers' ledger out of its workspace and into the plan's own directory. Until it has run, the seal gate refuses to let the workspace be deleted.

If the unit had no ledger — ad-hoc work, or `superpowers:executing-plans` — say so in one line and run discovery from the diff and this conversation instead. That is a weaker input, and naming it is how the reader knows.

### 2. Discovery — one subagent, every document at once

Dispatch one subagent with `discovery-prompt.md`. One pass covers every living document: the ledger is read once, and per-document discovery would re-read it once per document for no gain.

Its output is **the sweep brief**, written beside the sealed ledger as `<plans>/<plan-basename>.sweep.md`.

### 3. Execution — one implementer, from the brief alone

Dispatch one implementer with `implementer-prompt.md`. Sweep edits are many small same-shape changes across files — one brief listing every file and its change, landing as one diff.

### 4. Verification — a fresh subagent that does not trust the report

Run `scripts/sweep-package PLAN_FILE BASE HEAD`, then dispatch a fresh subagent with `verifier-prompt.md`. It returns three verdicts: **Placement**, **Discipline**, and **Drain completeness**.

**Fix loop: at most two rounds.** An entry that fails review twice is usually a defect in the brief — a mis-located claim, or a document state discovery misread — not an implementer needing a stronger model. Return to whoever dispatched the sweep, naming which entries failed and the pattern they share, and let them rule. A failure parked silently leaves the living documents wrong with nothing to signal it.

## What a finished sweep leaves

Four dated siblings beside the plan: the **spec** (what we meant to build), the **plan** (how we meant to build it), the **sealed ledger** (what actually happened), and the **brief** (what that changed in the documents).

The brief is the record. Discovery writes it, execution annotates outcomes onto it, verification appends its verdicts. Nothing else is written: a separate drain record would restate the ledger, which is the failure this plugin exists to prevent.

## Outcomes

| The ledger holds | The sweep produces |
|---|---|
| Entries with living-document consequence | A brief of edits, negatives and promotions, and a verified diff |
| No drainable entries | A brief of negatives only, and the sentence "nothing to drain" |
| A declared document that does not exist | It is reported absent, and it is not created |

**"Nothing to drain" is a finished sweep**, not a skipped one. It is a conclusion about the ledger, reached by reading it, and the negatives are what show it was reached.
```

- [ ] **Step 4: Write the discovery prompt**

Create `skills/sweep/discovery-prompt.md`:

```markdown
# Sweep discovery prompt

Fill the placeholders and dispatch one subagent with the result.

**Placeholders:** `{SEALED_LEDGER}` `{DIFF_PACKAGE}` `{CONFIG_MAP}` `{BRIEF_PATH}` `{SPEC}` `{PLAN}`

---

You are writing a **sweep brief**: the located, checkable list of changes that carry one unit of work into this project's living documents.

## Your inputs, and their order

1. `{SEALED_LEDGER}` — what actually happened during execution: rulings, deviations, parked findings. Read it in full. It is the one unreconstructable record.
2. `{DIFF_PACKAGE}` — what the code now does.
3. `{CONFIG_MAP}` — the output of `artifact-paths`: which paths hold which tier, and which are absent.
4. `{SPEC}` and `{PLAN}` — read only to resolve a claim you cannot place from the first two.

**You do not read the living documents in bulk.** From the ledger and the diff, derive a list of **grep terms** — the symbols, filenames, numbers, component names and phrases a claim would be written with — and reach into the documents only along those terms. A document you have grepped six times you have still not read, and that is the intended cost.

Read the destination section before writing any entry there. That is how you decide append-or-merge, and it is also how recurrence surfaces for free.

## The output

Write `{BRIEF_PATH}`. It has exactly these sections.

### Grep terms

The terms you derived, and the input each came from. This is what the verifier re-derives independently, so it has to be visible.

### Edits

One per change. Each is:

- **File and line** — `docs/DESIGN.md:214`
- **Current text, quoted** — verbatim, enough to locate it unambiguously
- **The change required** — the replacement text, or the text to add and exactly where

A located, quoted entry is what makes a sweep reviewable at all. An unlocated instruction cannot be verified by anyone, including you.

### Negatives

Every location you checked and deliberately left alone, with the reason. A negative is a first-class entry: it is the evidence that coverage happened, and it is what stops the next sweep re-checking the same ground.

Historical records — specs, plans, sealed ledgers, previous briefs — are left alone by rule. A grep hit inside one is a negative, never an edit.

### Promotions

A claim that has recurred: you found a near-identical entry already in the append-mostly tier. A lesson learned twice is evidence that one always-loaded line would have prevented the second occurrence. Give the `CLAUDE.md` line you propose, and the two occurrences that justify it.

A promotion is a proposal. Until this project has the `CLAUDE.md` admission guard, record it and leave it unapplied.

## Where each fact goes

Follow the artifact map. The two that decide most entries:

- A number that describes **the system now** goes into a living document, **replacing** the previous value. A number that describes **a run** stays in the sealed ledger and is cited from there.
- A dated observation that will stay true goes to the append-mostly tier, carrying the error text, symbol or version a future agent would grep for. A prescription goes where staleness is checked.

## When there is nothing to drain

Write the brief with its grep terms and its negatives, and say so in one sentence. A ledger of clean task completions and no deviations legitimately produces no edits. That is a finished sweep, and the negatives are what show you reached the conclusion rather than assumed it.
```

- [ ] **Step 5: Write the implementer and verifier prompts**

Create `skills/sweep/implementer-prompt.md`:

```markdown
# Sweep implementer prompt

**Placeholders:** `{BRIEF_PATH}`

---

Read `{BRIEF_PATH}` and make every change in its **Edits** section. The brief is your whole instruction set: it is located and quoted precisely so you do not have to reconstruct anything.

## How each edit lands

**Change what changed.** Where the brief quotes current text, that text is replaced — the document should read afterwards as though the new state had always been the case. Append only where the brief says the thing is genuinely new.

**Land it in the tier the brief names.** If an entry's destination is the append-mostly tier, it goes there whole, under the heading the brief names, created if it does not exist yet.

**Leave historical records alone.** Specs, plans, sealed ledgers and previous briefs are immutable. If an edit's location turns out to be inside one, do not make it — record it as a discrepancy instead.

## A brief entry you cannot carry out

If the quoted text is not at the given location, or the document does not say what the brief claims, **stop on that entry and record the discrepancy**: the entry, the location, and what you found there instead. Then continue with the rest. A mis-located entry is a defect in the brief, and reporting it is how the fix loop learns that.

Do not go looking for the right place yourself. Searching the document to repair an entry is how a sweep becomes O(project).

## What you return

Annotate `{BRIEF_PATH}` in place: mark each edit `applied` or `discrepancy: <what you found>`. Then report the files you touched and the count of each outcome. Do not restate the diff — a reviewer reads it separately.
```

Create `skills/sweep/verifier-prompt.md`:

```markdown
# Sweep verifier prompt

**Placeholders:** `{BRIEF_PATH}` `{DIFF_PACKAGE}` `{SEALED_LEDGER}` `{CONFIG_MAP}`

---

You are verifying one sweep. **Do not trust the implementer's report.** Its annotations tell you what was attempted; the diff tells you what happened. Where they disagree, the diff is right.

Read `{DIFF_PACKAGE}` — it is already scoped to this project's declared documents — and `{BRIEF_PATH}`.

Return three verdicts, each ✅ / ❌ / ⚠️ with the specific findings under it.

## 1. Placement

Every brief entry has a matching hunk, and the diff contains nothing else.

- A listed location the diff never touches is a **Missing** finding.
- A hunk no brief entry accounts for is an **Unrequested** finding.
- A hunk that lands somewhere other than the brief's location is **Misplaced**.

## 2. Discipline

- **Changed what changed.** A hunk that appends a new paragraph where the brief quoted existing text to replace is a finding, even when the added text is true.
- **Right tier.** Check each change against `{CONFIG_MAP}` and the artifact map.
- **No number describing a run entered a living document.** A figure produced by one execution belongs in the sealed ledger and is cited from there. This is the single most common way these documents start drifting.
- **Historical records untouched.** Any hunk inside a spec, plan, sealed ledger or previous brief is a finding.

## 3. Drain completeness

This is the verdict that has no equivalent in a code review, and it is why you were given the ledger.

A code reviewer can be diff-scoped because a human-approved plan is the completeness authority. Here the brief was written minutes ago by an agent with no such gate, so whether the drain is complete is genuinely open.

So: read `{SEALED_LEDGER}` and **derive your own grep terms independently**, before you look at the brief's list. Then check that every ledger entry is either drained by a brief entry, or explicitly ruled in the brief to have no living-document consequence. A ledger entry that appears in neither is an **Undrained** finding — name it and quote the ledger line.

Compare your terms with the brief's afterwards. A term you derived that the brief did not is where an Undrained finding usually hides.

## Scope

Verify this sweep. Do not review the code the unit produced, do not crawl documents no brief entry and no ledger entry points at, and do not propose improvements to prose that is correct.
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `bash tests/skills/test-skill-structure.sh`
Expected: PASS, ending in `OK` — including the sweep skill's 600-word budget.

- [ ] **Step 7: Run the whole suite**

Run: `bash tests/run-tests.sh`
Expected: PASS, `all 6 test file(s) passed`.

- [ ] **Step 8: Commit**

```bash
git add skills/sweep/SKILL.md skills/sweep/discovery-prompt.md skills/sweep/implementer-prompt.md skills/sweep/verifier-prompt.md tests/skills/test-skill-structure.sh
git commit -m "feat: the sweep skill and its discovery, implementer and verifier prompts"
```

---

### Task 8: End-to-end smoke test, self-adoption, and README

Prove the spine works as one mechanism rather than six passing units: an unsealed workspace is denied, sealing changes that, and the resulting package is scoped. Then adopt dopamine in its own repository and document it.

**Files:**
- Create: `tests/test-spine-end-to-end.sh`
- Create: `.dopamine/config`
- Create: `README.md`

**Interfaces:**
- Consumes: everything from Tasks 1–7.
- Produces: nothing other components depend on.

- [ ] **Step 1: Write the failing test**

Create `tests/test-spine-end-to-end.sh`:

```bash
#!/usr/bin/env bash
# The spine as one mechanism: config, gate, seal, package.
#
# Each unit is tested on its own elsewhere. What this file checks is the
# handover between them — that the filename seal-ledger writes is the filename
# the gate looks for, and that the gate's answer actually changes when it does.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

SEAL="$REPO_ROOT/skills/sweep/scripts/seal-ledger"
PACKAGE="$REPO_ROOT/skills/sweep/scripts/sweep-package"
GATE="$REPO_ROOT/hooks/seal-gate"

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

repo="$TEST_ROOT/project"
mkdir -p "$repo/docs/superpowers/plans" "$repo/src" "$repo/.dopamine"
git init -q "$repo"
git -C "$repo" config user.email dev@example.com
git -C "$repo" config user.name "Dev"

printf 'living: docs/DESIGN.md\nliving: docs/ARCHITECTURE.md\nlessons: docs/LESSONS.md\nplans: docs/superpowers/plans\n' \
    > "$repo/.dopamine/config"
plan="$repo/docs/superpowers/plans/2026-08-28-widget.md"
printf '# Widget plan\n' > "$plan"
printf 'The widget is synchronous.\n' > "$repo/docs/DESIGN.md"
printf 'no lessons yet\n' > "$repo/docs/LESSONS.md"
printf 'def widget(): pass\n' > "$repo/src/widget.py"
git -C "$repo" add -A
git -C "$repo" commit -qm "before"
BASE=$(git -C "$repo" rev-parse HEAD)

# The unit of work: code changed, and so did a living document.
printf 'The widget is asynchronous.\n' > "$repo/docs/DESIGN.md"
printf 'def widget(): await go()  # SOURCE_ONLY\n' > "$repo/src/widget.py"
git -C "$repo" add -A
git -C "$repo" commit -qm "make the widget async"
HEAD_REV=$(git -C "$repo" rev-parse HEAD)

# superpowers' workspace and ledger, as subagent-driven-development leaves them.
ws="$repo/.superpowers/sdd/2026-08-28-widget"
mkdir -p "$ws"
{
    printf '# SDD ledger — plan: docs/superpowers/plans/2026-08-28-widget.md\n\n'
    printf 'Task 1: complete — %s\n' "$(git -C "$repo" rev-parse --short HEAD)"
    printf 'Ruling: made the widget async — the sync call blocked the batch — costs a caller migration if wrong\n'
} > "$ws/progress.md"

gate_decision() {
    CWD="$repo" CMD="$1" python3 -c '
import json, os
print(json.dumps({"hook_event_name": "PreToolUse", "cwd": os.environ["CWD"],
                  "tool_name": "Bash", "tool_input": {"command": os.environ["CMD"]}}))' \
    | (cd "$repo" && "$GATE") | python3 -c '
import json, sys
raw = sys.stdin.read().strip()
print(json.loads(raw)["hookSpecificOutput"]["permissionDecision"] if raw else "none")'
}

echo "-- before sealing"
assert_eq "the gate denies deleting an unsealed workspace" \
    "deny" "$(gate_decision "rm -rf .superpowers/sdd/2026-08-28-widget")"

echo "-- sealing"
out=$("$SEAL" "$plan") && rc=0 || rc=$?
assert_eq "seal-ledger succeeds" 0 "$rc"
sealed="$repo/docs/superpowers/plans/2026-08-28-widget.ledger.md"
assert_eq "the sealed ledger lands where the gate looks for it" \
    "yes" "$([ -f "$sealed" ] && echo yes || echo no)"
assert_contains "and it carries the ruling that would otherwise have died" \
    "$(cat "$sealed")" "the sync call blocked the batch"

echo "-- after sealing"
assert_eq "the same deletion now passes" \
    "none" "$(gate_decision "rm -rf .superpowers/sdd/2026-08-28-widget")"

echo "-- the sweep's input"
out=$("$PACKAGE" "$plan" "$BASE" "$HEAD_REV") && rc=0 || rc=$?
assert_eq "sweep-package succeeds" 0 "$rc"
pkg=${out#wrote }
pkg=${pkg%% (*}
body=$(cat "$pkg")
assert_contains "the package carries the living document's change" "$body" "asynchronous"
assert_not_contains "and not the source file the sweep does not own" "$body" "SOURCE_ONLY"

echo "-- the ledger outlived the workspace"
rm -rf "$ws"
assert_eq "the sealed copy survives workspace deletion" \
    "yes" "$([ -f "$sealed" ] && echo yes || echo no)"

finish
```

- [ ] **Step 2: Run the test to verify it fails, then passes**

Run: `bash tests/test-spine-end-to-end.sh`
Expected: PASS on the first run — every component it exercises was built in Tasks 1–5. If it fails, the failure is a real handover defect between components (most likely the sealed-ledger filename contract between Task 2 and Task 3); fix the component, not the test.

- [ ] **Step 3: Adopt dopamine in its own repository**

Create `.dopamine/config`:

```
# dopamine's own artifact map.
#
# DESIGN.md and ARCHITECTURE.md are declared and do not exist yet: deriving them
# from the spec is a job for this plugin once it can do it. `artifact-paths`
# reports them absent, which is how that pending work stays visible without any
# nagging machinery.
living: docs/DESIGN.md
living: docs/ARCHITECTURE.md
living: docs/ROADMAP.md
instructions: CLAUDE.md
lessons: docs/LESSONS.md
plans: docs/superpowers/plans
```

Run: `bash skills/sweep/scripts/artifact-paths`
Expected: six TSV rows, exit 0, with `docs/DESIGN.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `CLAUDE.md` and `docs/LESSONS.md` reported `absent` and `docs/superpowers/plans` reported `present`.

- [ ] **Step 4: Write the README**

Create `README.md`:

```markdown
# dopamine

A Claude Code plugin that sits beside [superpowers](https://github.com/obra/superpowers) and operates one level above it. Superpowers plans and executes a change; dopamine carries **what actually happened** back into the documents that describe the project.

> The name is provisional.

## The problem

A predecessor project accumulated 5,186 lines across six documents for roughly thirty modules. The reported cost was not the line count — it was that every phase ran slower than the last, and the end-of-development document sweep took several times longer than any other activity.

That sweep is expensive because it is a reconstruction task whose input grows with the project: re-read the documents, work out what happened, work out what is now false. Keeping documents tidy does not touch it. A perfectly written 400-line design document still has to be fully re-read and fully re-verified at every phase close.

**Dopamine's target is a sweep whose cost tracks the change, not the project.** Every mechanism here answers one question: is it O(change) or O(project)?

## How it works

Superpowers already keeps a per-plan ledger at `.superpowers/sdd/<plan>/progress.md` — rulings, deviations, parked findings, recorded as they happen. It is the one genuinely unreconstructable record, and superpowers deletes it when the plan finishes.

Dopamine seals that ledger before it dies, and drains it into the living documents along grep terms derived from the ledger and the diff — never by re-reading the documents in bulk.

| Piece | What it does |
|---|---|
| `.dopamine/config` | Declares which paths hold which artifact tier. The plugin hard-codes no project's document set |
| `SessionStart` hook | ~110 words positioning dopamine relative to superpowers. Silent in a repo with no config |
| `PreToolUse` seal gate | Denies deleting an SDD workspace whose ledger is not sealed |
| `dopamine:sweep` | Seal → discovery → execution → verification, each stage its own subagent |
| `dopamine:artifact-map` | Where each kind of fact belongs, and why only two tiers are ever re-verified |

## Install

Add this repository as a Claude Code plugin, then create `.dopamine/config` in the project you want it to work on:

```
living: docs/DESIGN.md
living: docs/ARCHITECTURE.md
living: docs/ROADMAP.md
instructions: CLAUDE.md
lessons: docs/LESSONS.md
plans: docs/superpowers/plans
```

A declared document that does not exist yet is reported `absent`, not as an error. Without this file every dopamine mechanism stays inert, so installing the plugin changes nothing until a project opts in.

## Requirements

bash, git, and **Python 3** — used by the seal gate and by the tests. If no Python 3 is found the gate prints one line to stderr and exits 0: a gate that cannot run must not block every command in the session.

## Known gaps

- **A deletion that names the workspace only through a shell variable** (`rm -rf "$dir"`) carries no literal path, so the gate cannot see it. Superpowers' own finish step writes the path literally, which is the case that matters.
- **`git clean -fdx` destroys the workspace** without naming it. Out of the gate's scope by design — matching on it would deny a command most repositories run for unrelated reasons.
- **No ledger outside `subagent-driven-development`.** `executing-plans` and ad-hoc work have none, so the sweep falls back to reconstruction there.

## Tests

```bash
bash tests/run-tests.sh
```

## Status

Slice 1 of three. The `CLAUDE.md` admission guard and the authoring skills (`brainstorm-design`, `brainstorm-architecture`, `writing-roadmaps`, `adopting-a-repo`) are not built yet — see `docs/superpowers/specs/2026-08-28-dopamine-design.md` §12.
```

- [ ] **Step 5: Run the whole suite one last time**

Run: `bash tests/run-tests.sh`
Expected: PASS, `all 7 test file(s) passed`.

- [ ] **Step 6: Commit**

```bash
git add tests/test-spine-end-to-end.sh .dopamine/config README.md
git commit -m "feat: end-to-end spine test, self-adoption and README"
```

---

## Notes for the executor

**This plan builds the tool that would normally sweep this plan.** When you finish, the spine exists — so seal this plan's own ledger with the script you just built, and if `docs/DESIGN.md` still does not exist, say so rather than creating it: deriving the living documents from the spec is slice 3's job, and doing it by hand here would be exactly the accretion this plugin exists to prevent.

**Three decisions made while writing this plan, in case a reviewer disagrees:**

1. **The config is line-oriented (`tier: path`), not JSON or TOML.** No JSON parser is available in bash and `jq` is not installed. A line-oriented file is greppable, needs no dependency, and its keys *are* the artifact model.
2. **The seal gate finds the sealed ledger through the config's `plans` key**, rather than through a marker file dropped inside `.superpowers/sdd/<slug>/`. The marker was the simpler mechanism, and it writes into superpowers' directory — which spec §5 forbids.
3. **The artifact map is a reference skill (`dopamine:artifact-map`), not a loose file.** Spec §8 asks for "a shared reference file… so the map itself has one home"; a skill satisfies that and can be cross-referenced by name rather than by a relative path from a sibling skill's directory.

**One value to confirm before publishing:** `.claude-plugin/plugin.json` names `Wout Gijsbers` as author with no email. Add one if it should be there.
