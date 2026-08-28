# Dopamine Slice 2 — the `CLAUDE.md` guard — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `CLAUDE.md` an admission test — a vendored standard, a drift check that keeps it honest, a `PostToolUse` hook that carries it to the moment of the edit, and the gate that turns slice 1's recorded-but-unapplied promotions into decisions.

**Architecture:** A skill holds the test and the routing table; a vendored rule card holds Anthropic's standard with its sources; `refresh-rule-card` re-fetches the three source sections and diffs them against snapshots so vendoring cannot rot silently; a `PostToolUse` hook fires when an instructions-tier file is edited and returns the mechanically-known numbers plus a pointer to the skill as `additionalContext`. The sweep's discovery and verifier prompts are amended so a promotion is now gated rather than parked.

**Tech Stack:** bash 5.3.9, Python 3.14.4, git 2.53.0, curl 8.18.0 (with a wget fallback). No `jq`, no `shellcheck` — neither is installed and neither may be introduced as a dependency.

**Spec:** `docs/superpowers/specs/2026-08-28-dopamine-design.md` — slice 2 of §12. The sections that bind this plan are §6 (artifact model), §8 (components), §9.3 (the admission test), §9.6 (`LESSONS.md` and promotions), and §10 (accepted risks).

**Predecessor:** `docs/superpowers/plans/2026-08-28-dopamine-spine.md` and its sealed ledger `…-dopamine-spine.ledger.md`. Slice 1 is merged to `main` at `0b39bef`.

## Global Constraints

Every task's requirements implicitly include this section.

- **Nothing is ever written under `.superpowers/`.** Dopamine reads superpowers' artifacts and writes only its own (spec §5).
- **Every mechanism must be O(change), not O(project)** (spec §3). A mechanism whose cost grows with the size of the repository is rejected however well it performs on a small one.
- **Guidance is written as positive recipe, not prohibition** (spec §9.4). The baseline failure here is wrong-shaped output, and in head-to-head tests the prohibition arm produced *more* unwanted content than the no-guidance control. Say what the output is and where each thing goes; do not list what must not happen.
- **The Iron Law of `superpowers:writing-skills` is waived** (spec §10): no baseline pressure scenarios are run. Skill tests are therefore **structural** — frontmatter valid, description a trigger rather than a workflow summary, referenced files exist, no `@`-link force-loads, word budget holds.
- **The plugin hard-codes no project's document set.** Every path comes from `.dopamine/config` via `skills/sweep/scripts/artifact-paths`. Without that file every dopamine mechanism stays inert.
- **Hooks fail open.** A hook always exits 0. A hook that cannot run must never break the user's session.
- **Shell style, three ways:** `set -euo pipefail` for product scripts; `set -uo pipefail` (no `-e`) for test scripts, which exist to observe failures, tally them and exit non-zero on purpose; bare `set -u` for hook wrappers that must survive a broken environment.
- **Hook scripts use extensionless filenames** (`session-start`, not `session-start.sh`). Claude Code's Windows auto-detection prepends `bash` to any command containing `.sh`.
- **Never invent a value that must be confirmed.** Every URL, byte count and percentage in this plan was measured on 2026-08-28 and is reproduced verbatim; do not substitute a remembered one.
- **Tests are the gate.** `bash tests/run-tests.sh` must be green at the end of every task. Slice 1 landed 7 test files / 154 assertions; that count may grow but must never fall.

---

## Measured facts this plan rests on

All measured 2026-08-28. They are stated here once so no task has to re-derive them.

| Fact | Value |
|---|---|
| Best-practices page, raw markdown | `https://code.claude.com/docs/en/best-practices.md` — 40,068 bytes, `text/markdown` |
| Memory page, raw markdown | `https://code.claude.com/docs/en/memory.md` — 36,894 bytes, `text/markdown` |
| `### Write an effective CLAUDE.md` (best-practices) | 3,256 bytes, 459 words — **8.1%** of its page |
| `### When to add to CLAUDE.md` (memory) | 824 bytes, 125 words — 2.2% of its page |
| `### Write effective instructions` (memory) | 1,818 bytes, 234 words — 4.9% of its page |
| The three sections together | 5,898 bytes, **818 words** |

Two things follow, and both are load-bearing:

1. **The spec's figures check out.** It reported "39,879 and 36,982 bytes, of which the `CLAUDE.md` guidance is 8% and 7%". Today the pages measure 40,068 and 36,894 and the sections are 8.1% and 7.1%. The second page's `.md` form measured **36,982 bytes over the wire**, matching the spec exactly. The pages have drifted slightly since the spec was written, which is the drift `refresh-rule-card` exists to surface.
2. **Both pages serve raw markdown at `<url>.md`.** The HTML forms are 684 KB and 618 KB of JS-rendered app shell; the `.md` forms are ~40 KB of clean text. This is what makes a diff-based drift check possible at all. `refresh-rule-card` fetches the `.md` URLs and never parses HTML.

Confirmed against the live hooks reference (`https://code.claude.com/docs/en/hooks.md`) on the same date:

- `PostToolUse` input carries `tool_input.file_path`, **always absolute, with the platform's native separators** (backslashes on Windows).
- The output shape for context injection is `{"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": "…"}}`, delivered next to the tool result.
- **Known limit, quoted:** "Claude Code doesn't run a `PostToolUse` hook matching `Edit|Write` when a `Bash` command or a process outside Claude Code rewrites the same file." This becomes a README known gap in Task 6, not a bug to fix.

---

## File Structure

**Created:**

| Path | Responsibility |
|---|---|
| `skills/claude-md-guard/scripts/refresh-rule-card` | Fetch each declared source section, extract it fence-aware, diff against its snapshot, report drift |
| `skills/claude-md-guard/claude-md-best-practices.md` | The vendored standard, its distillation date, and the machine-readable `source:` lines |
| `skills/claude-md-guard/sources/*.md` | Byte-exact snapshots of the three source sections, generated by `refresh-rule-card --update` |
| `skills/claude-md-guard/SKILL.md` | When the guard fires, the test, the routing table, the verdict shape |
| `hooks/py-hook` | Shared Python-3 interpreter probe for every Python hook. Fails open |
| `hooks/claude_md_guard.py` | The `PostToolUse` guard: predicate, mechanical facts, `additionalContext` |
| `hooks/claude-md-guard-context.md` | The static half of the injected text, so its word budget is testable |
| `tests/scripts/test-refresh-rule-card.sh` | Extraction, drift, `--update`, exit codes — offline, via `file://` fixtures |
| `tests/skills/test-rule-card.sh` | The shipped card parses, names existing snapshots, carries the five standard elements |
| `tests/hooks/test-claude-md-guard.sh` | Predicate, silence, JSON shape, facts line, word budget |
| `tests/test-guard-end-to-end.sh` | A temp repo from config to injected verdict, plus the shipped card's integrity |

**Modified:**

| Path | Change |
|---|---|
| `hooks/seal-gate` | Becomes a two-line shim over `hooks/py-hook`. Its name and registration are unchanged |
| `hooks/hooks.json` | Gains a `PostToolUse` entry matching `Edit|Write` |
| `tests/skills/test-skill-structure.sh` | `BUDGETS` gains `claude-md-guard:500`; content assertions for the new skill |
| `skills/sweep/discovery-prompt.md` | A promotion is now gated by the guard instead of parked unapplied |
| `skills/sweep/verifier-prompt.md` | Discipline gains an **Ungated** finding |
| `README.md` | Component table, known gaps, requirements, status |

**One addition to the spec's sketched layout.** Spec §8 draws `skills/claude-md-guard/` with `SKILL.md`, the rule card and `scripts/refresh-rule-card`. This plan adds `sources/` — three byte-exact snapshots of the upstream sections. They are what makes "diffs, reports drift" mean anything: a drift check with no stored baseline can only re-read the pages and ask an agent whether they look different, which is the O(project) judgement call this project rejects. The snapshots turn drift detection into `diff`.

**Deliberately NOT modified:** `skills/sweep/SKILL.md`. It stands at **699 of its 700-word budget**, so any addition must first free words. The promotion contract belongs in `discovery-prompt.md` — the stage that actually judges promotions — so the sweep recipe needs no change at all. This is a ruling, not an oversight: if a later reviewer believes the recipe must mention the guard, the budget must be raised in the same change, with the reason recorded the way the 600→700 raise already is.

---

## Task order and parallelism

`1 → 2 → {3, 4} → 5 → 6`. Task 2 needs Task 1's extractor to generate byte-exact snapshots; Tasks 3 and 4 both need Task 2's card but not each other, and touch disjoint files (`skills/claude-md-guard/SKILL.md` + the structure test, versus `hooks/*` + the hook test), so they may run in parallel worktrees branched from the same commit. Tasks 5 and 6 are sequential and touch shared files.

---

## Task 1: `refresh-rule-card`

**Files:**
- Create: `skills/claude-md-guard/scripts/refresh-rule-card`
- Test: `tests/scripts/test-refresh-rule-card.sh`

**Interfaces:**
- Consumes: nothing from earlier tasks. `python3`, `diff`, and `curl` or `wget`.
- Produces: `refresh-rule-card [--update] [CARD]`. Reads `source: URL | HEADING | SNAPSHOT` lines from `CARD`. Exits **0** no drift · **1** drift, heading gone, or a snapshot that does not exist yet · **2** usage, or a card with no parseable sources · **3** a source could not be fetched. `--update` rewrites snapshots from what was fetched and still exits 1, because rewriting a snapshot does not re-distil the card body.

**Why this task comes first.** The snapshots in Task 2 must be byte-identical to what this extractor produces, or the very first drift check reports a difference that is an artefact of hand-transcription. Generating them with the tool removes that whole class of failure.

**The trap this task exists to get right.** The best-practices section contains a fenced markdown block whose body is an example `CLAUDE.md`:

    ```markdown CLAUDE.md theme={null}
    # Code style
    - Use ES modules (import/export) syntax, not CommonJS (require)

    # Workflow
    - Be sure to typecheck when you're done making a series of code changes
    ```

`# Code style` and `# Workflow` are depth-1 headings sitting inside the depth-3 section being extracted. A line-oriented extractor that does not track fence state stops at `# Code style` and silently captures a third of the section. The extractor must toggle on ``` and `~~~` and ignore any `#` line while a fence is open.

- [ ] **Step 1: Write the failing test**

Create `tests/scripts/test-refresh-rule-card.sh`. Note the four-backtick outer fence: the fixture it writes contains triple backticks.

````bash
#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

UNDER_TEST="$REPO_ROOT/skills/claude-md-guard/scripts/refresh-rule-card"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

# A source page shaped like the real one: the target section contains a fenced
# block whose body has depth-1 headings, and is followed by a sibling section
# that must not be captured.
write_page() {
    cat > "$1" <<'PAGE'
# Page title

## Configure your environment

Intro prose.

### Write an effective CLAUDE.md

Body line one.

```markdown CLAUDE.md theme={null}
# Code style
- Use ES modules

# Workflow
- Typecheck when done
```

Closing line of the section.

### Configure permissions

This belongs to the next section.
PAGE
}

# write_card CARD PAGE SNAPSHOT_REL
write_card() {
    printf 'source: file://%s | ### Write an effective CLAUDE.md | %s\n' "$2" "$3" > "$1"
}

page="$TEST_ROOT/page.md"
write_page "$page"
card="$TEST_ROOT/card.md"
write_card "$card" "$page" "sources/bp.md"

echo "-- bootstrap: no snapshot yet"
RC=0
out=$("$UNDER_TEST" "$card" 2>&1) || RC=$?
assert_eq "a missing snapshot is drift, not success" 1 "$RC"
assert_contains "and it says which snapshot is missing" "$out" "sources/bp.md"

RC=0
out=$("$UNDER_TEST" --update "$card" 2>&1) || RC=$?
assert_eq "--update still exits 1: the card body is not re-distilled by it" 1 "$RC"
assert_contains "it reports the snapshot as created" "$out" "CREATED"
assert_eq "the snapshot now exists" "yes" \
    "$([ -f "$TEST_ROOT/sources/bp.md" ] && echo yes || echo no)"

echo "-- the extraction boundary"
snap=$(cat "$TEST_ROOT/sources/bp.md")
assert_contains "captures the heading itself" "$snap" "### Write an effective CLAUDE.md"
assert_contains "captures body before the fence" "$snap" "Body line one."
assert_contains "does not stop at a depth-1 heading inside a fence" "$snap" "# Workflow"
assert_contains "captures body after the fence" "$snap" "Closing line of the section."
assert_not_contains "stops at the next same-depth heading" "$snap" "Configure permissions"
assert_not_contains "and does not reach into it" "$snap" "This belongs to the next section."
assert_not_contains "does not capture the preceding section" "$snap" "Intro prose."

echo "-- a clean re-run"
RC=0
out=$("$UNDER_TEST" "$card" 2>&1) || RC=$?
assert_eq "no drift exits 0" 0 "$RC"
assert_contains "and says so" "$out" "no drift"

echo "-- drift is detected and shown"
sed -i 's/Body line one./Body line one, amended upstream./' "$page"
RC=0
out=$("$UNDER_TEST" "$card" 2>&1) || RC=$?
assert_eq "drift exits 1" 1 "$RC"
assert_contains "it names the drifted snapshot" "$out" "DRIFT"
assert_contains "and prints the diff" "$out" "amended upstream"

RC=0
out=$("$UNDER_TEST" --update "$card" 2>&1) || RC=$?
assert_eq "--update after drift still exits 1" 1 "$RC"
assert_contains "and reports the rewrite" "$out" "UPDATED"
RC=0
"$UNDER_TEST" "$card" >/dev/null 2>&1 || RC=$?
assert_eq "the snapshot now matches, so the next run is clean" 0 "$RC"

echo "-- a heading that disappeared upstream"
sed -i 's/### Write an effective CLAUDE.md/### Write a good CLAUDE.md/' "$page"
RC=0
out=$("$UNDER_TEST" "$card" 2>&1) || RC=$?
assert_eq "a vanished heading is drift, not a crash" 1 "$RC"
assert_contains "and it is named as such" "$out" "HEADING-GONE"

echo "-- failure modes"
RC=0
"$UNDER_TEST" "$TEST_ROOT/does-not-exist.md" >/dev/null 2>&1 || RC=$?
assert_eq "a card that does not exist exits 2" 2 "$RC"

printf '# a card with no sources\n' > "$TEST_ROOT/empty-card.md"
RC=0
"$UNDER_TEST" "$TEST_ROOT/empty-card.md" >/dev/null 2>&1 || RC=$?
assert_eq "a card declaring no sources exits 2" 2 "$RC"

printf 'source: file:///nowhere.md | ### X\n' > "$TEST_ROOT/short-card.md"
RC=0
"$UNDER_TEST" "$TEST_ROOT/short-card.md" >/dev/null 2>&1 || RC=$?
assert_eq "a source line missing a field exits 2" 2 "$RC"

printf 'source: file://%s/absent.md | ### X | sources/x.md\n' "$TEST_ROOT" > "$TEST_ROOT/gone-card.md"
RC=0
"$UNDER_TEST" "$TEST_ROOT/gone-card.md" >/dev/null 2>&1 || RC=$?
assert_eq "a source that cannot be fetched exits 3" 3 "$RC"

echo "-- comments and blank lines are ignored"
{
    printf '# The card prose lives here and is not a source line.\n\n'
    printf 'source: file://%s | ### Write a good CLAUDE.md | sources/bp.md\n' "$page"
} > "$TEST_ROOT/prose-card.md"
mkdir -p "$TEST_ROOT/sources"
RC=0
"$UNDER_TEST" --update "$TEST_ROOT/prose-card.md" >/dev/null 2>&1 || RC=$?
assert_eq "prose around the source lines does not break parsing" 1 "$RC"

finish
````

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/scripts/test-refresh-rule-card.sh`
Expected: FAIL — every case, because `skills/claude-md-guard/scripts/refresh-rule-card` does not exist.

- [ ] **Step 3: Write the script**

Create `skills/claude-md-guard/scripts/refresh-rule-card` and `chmod +x` it.

```bash
#!/usr/bin/env bash
# Re-fetch the source sections behind the vendored CLAUDE.md rule card and report
# drift against the snapshots kept beside it.
#
# This runs off the edit path, never on it. Measured 2026-08-28: the two source
# pages are 40,068 and 36,894 bytes and the CLAUDE.md guidance is 8.1% and 7.1%
# of them — roughly 900 usable words inside ~19,000 tokens. Fetching them at the
# moment someone edits a CLAUDE.md would be the wrong mechanism. The card is
# vendored instead, and this script is what keeps vendoring honest.
#
# Usage: refresh-rule-card [--update] [CARD]
#   --update  rewrite each snapshot from what was fetched, so the diff can be
#             reviewed once and the card re-distilled against it
#   CARD      the rule card (default: the card beside this script's skill)
#
# The card declares its own sources, one per line:
#   source: <url> | <heading> | <snapshot path, relative to the card>
#
# Exits: 0 no drift
#        1 drift, a heading that vanished upstream, or a snapshot not yet created
#        2 usage, or a card that declares no parseable sources
#        3 a source could not be fetched
#
# --update exits 1 even when it succeeds: rewriting a snapshot does not
# re-distil the card body, and that is the work the diff is asking for.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_CARD="$SKILL_DIR/claude-md-best-practices.md"

usage() {
    echo "usage: refresh-rule-card [--update] [CARD]" >&2
    exit 2
}

update=0
if [ "${1:-}" = "--update" ]; then
    update=1
    shift
fi
[ $# -le 1 ] || usage

card=${1:-$DEFAULT_CARD}
[ -f "$card" ] || { echo "no rule card at $card" >&2; exit 2; }
card_dir=$(cd "$(dirname "$card")" && pwd)

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

trim() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

# fetch URL DEST — file:// is read directly rather than handed to curl, so the
# tests are hermetic and need no network and no curl file:// support.
fetch() {
    local url=$1 dest=$2
    case "$url" in
        file://*)
            cat "${url#file://}" > "$dest" 2>/dev/null
            ;;
        *)
            if command -v curl >/dev/null 2>&1; then
                curl -fsSL --max-time 30 "$url" -o "$dest"
            elif command -v wget >/dev/null 2>&1; then
                wget -q -O "$dest" "$url"
            else
                echo "neither curl nor wget is available" >&2
                return 1
            fi
            ;;
    esac
}

# extract SRC HEADING — prints the section; exits 4 if the heading is not there.
#
# Fence-aware by necessity: the best-practices section contains a fenced example
# CLAUDE.md whose body has depth-1 headings (`# Code style`, `# Workflow`). An
# extractor that treats those as headings captures a third of the section and
# reports drift forever after.
extract() {
    SRC="$1" HEADING="$2" python3 - <<'PY'
import os
import sys

heading = os.environ["HEADING"].strip()
depth = len(heading) - len(heading.lstrip("#"))
out = []
capture = False
fence = None

with open(os.environ["SRC"], encoding="utf-8") as handle:
    for line in handle:
        stripped = line.strip()
        if stripped.startswith("```") or stripped.startswith("~~~"):
            marker = stripped[:3]
            if fence is None:
                fence = marker
            elif fence == marker:
                fence = None
        elif fence is None and stripped.startswith("#"):
            level = len(stripped) - len(stripped.lstrip("#"))
            if capture and level <= depth:
                break
            if not capture and stripped == heading:
                capture = True
        if capture:
            out.append(line)

if not capture:
    sys.exit(4)
sys.stdout.write("".join(out).rstrip() + "\n")
PY
}

drift=0
sources=0
lineno=0

while IFS= read -r raw || [ -n "$raw" ]; do
    lineno=$((lineno + 1))
    line=$(trim "$raw")
    case "$line" in
        source:*) ;;
        *) continue ;;
    esac

    pipes=${line//[^|]/}
    if [ "${#pipes}" -ne 2 ]; then
        echo "$card:$lineno: a source line needs 'url | heading | snapshot': $line" >&2
        exit 2
    fi

    rest=${line#source:}
    url=$(trim "${rest%%|*}")
    rest=${rest#*|}
    headline=$(trim "${rest%%|*}")
    snapshot=$(trim "${rest#*|}")

    if [ -z "$url" ] || [ -z "$headline" ] || [ -z "$snapshot" ]; then
        echo "$card:$lineno: a source line needs 'url | heading | snapshot': $line" >&2
        exit 2
    fi
    case "$snapshot" in
        /*|*..*) echo "$card:$lineno: snapshot must be relative to the card: $snapshot" >&2; exit 2 ;;
    esac

    sources=$((sources + 1))

    if ! fetch "$url" "$tmp/fetched.md"; then
        echo "FETCH-FAILED  $url" >&2
        exit 3
    fi

    rc=0
    extract "$tmp/fetched.md" "$headline" > "$tmp/section.md" || rc=$?
    if [ "$rc" -eq 4 ]; then
        echo "HEADING-GONE  $snapshot"
        echo "              '$headline' is no longer a heading at $url"
        drift=1
        continue
    fi
    [ "$rc" -eq 0 ] || exit "$rc"

    target="$card_dir/$snapshot"
    if [ ! -f "$target" ]; then
        if [ "$update" -eq 1 ]; then
            mkdir -p "$(dirname "$target")"
            cp "$tmp/section.md" "$target"
            echo "CREATED       $snapshot"
        else
            echo "NO-SNAPSHOT   $snapshot — run with --update to create it"
        fi
        drift=1
        continue
    fi

    if diff -u "$target" "$tmp/section.md" > "$tmp/diff.txt"; then
        echo "ok            $snapshot"
        continue
    fi

    drift=1
    if [ "$update" -eq 1 ]; then
        cp "$tmp/section.md" "$target"
        echo "UPDATED       $snapshot"
    else
        echo "DRIFT         $snapshot"
    fi
    sed -e 's/^/    /' "$tmp/diff.txt"
done < "$card"

if [ "$sources" -eq 0 ]; then
    echo "$card: declares no 'source:' lines" >&2
    exit 2
fi

if [ "$drift" -eq 0 ]; then
    echo "no drift in $sources source section(s)"
    exit 0
fi

if [ "$update" -eq 1 ]; then
    echo "$sources section(s) checked; snapshots rewritten — re-distil the card against the diffs above"
else
    echo "$sources section(s) checked; drift found — review the diffs, then re-run with --update"
fi
exit 1
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/scripts/test-refresh-rule-card.sh`
Expected: PASS, ending in `OK`.

- [ ] **Step 5: Run the whole suite**

Run: `bash tests/run-tests.sh`
Expected: every file passes. This adds one file to slice 1's seven.

- [ ] **Step 6: Commit**

```bash
git add skills/claude-md-guard/scripts/refresh-rule-card tests/scripts/test-refresh-rule-card.sh
git commit -m "feat: refresh-rule-card, the drift check behind the vendored standard"
```

---

## Task 2: The vendored rule card and its snapshots

**Files:**
- Create: `skills/claude-md-guard/claude-md-best-practices.md`
- Create: `skills/claude-md-guard/sources/best-practices-write-an-effective-claude-md.md`
- Create: `skills/claude-md-guard/sources/memory-when-to-add-to-claude-md.md`
- Create: `skills/claude-md-guard/sources/memory-write-effective-instructions.md`
- Test: `tests/skills/test-rule-card.sh`

**Interfaces:**
- Consumes: `skills/claude-md-guard/scripts/refresh-rule-card` from Task 1, including its `source: <url> | <heading> | <snapshot>` line format and its `--update` bootstrap.
- Produces: the card at `skills/claude-md-guard/claude-md-best-practices.md`, which Task 3's `SKILL.md` links to as `[claude-md-best-practices.md](claude-md-best-practices.md)` and Task 6's end-to-end test parses.

**The snapshots are captures, not documents.** They are byte-exact output of `refresh-rule-card`'s extractor and are never hand-edited — including the fact that the best-practices section ends on a sentence containing `@path/to/import`. That `@` lives in a snapshot, not in a `SKILL.md`, so the structure test's `@`-link check does not see it and must not be worked around.

**This task needs the network.** The three snapshots are generated by running `refresh-rule-card --update` against the live URLs, never hand-written — a transcribed snapshot differs from what the extractor produces and makes the first real drift check report a difference that is an artefact of typing. If the network is unavailable, report **BLOCKED** rather than writing the snapshots by hand.

**What the card is for.** It is the standard the guard applies. The skill holds the routing decision; the card holds the rules routed against. It is Anthropic's own guidance, distilled — not dopamine's opinion about `CLAUDE.md`.

- [ ] **Step 1: Write the failing test**

Create `tests/skills/test-rule-card.sh`:

```bash
#!/usr/bin/env bash
# The shipped rule card is a machine-readable artifact as well as a document:
# refresh-rule-card parses its source lines, and the guard skill links to it.
# These assertions are about the card that ships, not about a fixture.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

CARD="$REPO_ROOT/skills/claude-md-guard/claude-md-best-practices.md"

if [ ! -f "$CARD" ]; then
    fail "the rule card exists" "not found at $CARD"
    finish
fi

body=$(cat "$CARD")

echo "-- the standard the guard applies"
assert_contains "carries the per-line test verbatim" "$body" \
    "Would removing this cause Claude to make mistakes?"
assert_contains "carries the include column" "$body" "Include"
assert_contains "carries the exclude column" "$body" "Exclude"
assert_contains "carries the 200-line target" "$body" "200 lines"
assert_contains "routes sometimes-relevant content to a skill" "$body" "skill"
assert_contains "names the /doctor trim pass" "$body" "/doctor"
assert_contains "carries its distillation date" "$body" "2026-08-28"

echo "-- the machine-readable source lines"
mapfile -t sources < <(grep -E '^[[:space:]]*source:' "$CARD")
assert_eq "declares exactly three source sections" 3 "${#sources[@]}"

missing=""
notmd=""
for line in "${sources[@]}"; do
    trimmed=${line#*source:}
    url=$(printf '%s' "${trimmed%%|*}" | tr -d ' ')
    rest=${trimmed#*|}
    snap=$(printf '%s' "${rest#*|}" | tr -d ' ')
    case "$url" in
        https://code.claude.com/docs/en/*.md) ;;
        *) notmd="$notmd $url" ;;
    esac
    [ -f "$REPO_ROOT/skills/claude-md-guard/$snap" ] || missing="$missing $snap"
done
assert_eq "every source is a raw-markdown docs URL" "" "$notmd"
assert_eq "every declared snapshot exists" "" "$missing"

echo "-- the snapshots are real captures, not stubs"
for snap in "$REPO_ROOT"/skills/claude-md-guard/sources/*.md; do
    [ -f "$snap" ] || continue
    name=$(basename "$snap")
    first=$(head -1 "$snap")
    case "$first" in
        '###'*) pass "$name: opens with the heading it captured" ;;
        *) fail "$name: opens with the heading it captured" "got: $first" ;;
    esac
    bytes=$(wc -c < "$snap" | tr -d ' ')
    if [ "$bytes" -ge 500 ]; then
        pass "$name: is a whole section ($bytes bytes)"
    else
        fail "$name: is a whole section" "only $bytes bytes — a truncated extraction"
    fi
done

echo "-- the fenced example survived extraction"
bp="$REPO_ROOT/skills/claude-md-guard/sources/best-practices-write-an-effective-claude-md.md"
if [ -f "$bp" ]; then
    snap=$(cat "$bp")
    assert_contains "the fenced example CLAUDE.md is present" "$snap" "# Workflow"
    assert_contains "and so is the text after it" "$snap" "Keep it concise"
    assert_not_contains "extraction stopped at the next section" "$snap" "Configure permissions"
else
    fail "the best-practices snapshot exists" "not found"
fi

finish
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/skills/test-rule-card.sh`
Expected: FAIL with `the rule card exists … not found`.

- [ ] **Step 3: Write the card**

Create `skills/claude-md-guard/claude-md-best-practices.md`:

````markdown
# CLAUDE.md — the admission standard

Anthropic's own guidance on what belongs in a `CLAUDE.md`, distilled from the sections listed at the bottom. This file is the standard; `dopamine:claude-md-guard` is the routing decision made against it.

## The per-line test

For each line, ask: **"Would removing this cause Claude to make mistakes?"** If not, cut it.

Bloated `CLAUDE.md` files cause Claude to ignore your actual instructions. Two symptoms are worth memorising because they point in opposite directions:

- Claude keeps doing something you asked it not to, **despite a rule against it** — the file is probably too long and the rule is getting lost.
- Claude asks a question the file already answers — the phrasing is ambiguous rather than the file too long.

Treat `CLAUDE.md` like code: review it when things go wrong, prune it regularly, and test a change by observing whether behaviour actually shifts.

## What belongs, and what does not

| ✅ Include | ❌ Exclude |
|---|---|
| Bash commands Claude can't guess | Anything Claude can figure out by reading code |
| Code style rules that differ from defaults | Standard language conventions Claude already knows |
| Testing instructions and preferred test runners | Detailed API documentation (link to docs instead) |
| Repository etiquette (branch naming, PR conventions) | Information that changes frequently |
| Architectural decisions specific to your project | Long explanations or tutorials |
| Developer environment quirks (required env vars) | File-by-file descriptions of the codebase |
| Common gotchas or non-obvious behaviours | Self-evident practices like "write clean code" |

## When a line has earned its place

Add to `CLAUDE.md` when:

- Claude makes the same mistake a second time
- A code review catches something Claude should have known about this codebase
- You type the same correction into chat that you typed last session
- A new teammate would need the same context to be productive

## Where a line goes instead

`CLAUDE.md` loads at the start of every session, so only content that applies broadly earns a place in it. Everything else has a home:

| The candidate | Its home |
|---|---|
| Relevant only sometimes, or a multi-step procedure | A skill — loaded on demand, without bloating every conversation |
| True only of part of the tree | A path-scoped rule under `.claude/rules/`, loaded only for matching files |
| Detailed API documentation | The docs, linked |
| Derivable by reading the code | Cut. On a checked-in `CLAUDE.md`, `/doctor` proposes exactly these cuts |

## How the surviving lines are written

- **Size** — target under 200 lines per file. Longer files consume more context and reduce adherence.
- **Structure** — markdown headers and bullets. Claude scans structure the way readers do; organised sections beat dense paragraphs.
- **Specificity** — concrete enough to verify. "Use 2-space indentation", not "Format code properly". "Run `npm test` before committing", not "Test your changes". "API handlers live in `src/api/handlers/`", not "Keep files organized".
- **Consistency** — two rules that contradict each other leave Claude to pick one arbitrarily. Review the file, any nested files in subdirectories, and `.claude/rules/` periodically.
- **Emphasis** — if Claude keeps skipping one instruction, add IMPORTANT to that line alone. Emphasise many lines and none of them stands out.

## Sources

Distilled **2026-08-28** from the three sections below. `scripts/refresh-rule-card` re-fetches each one, extracts it, and diffs it against the snapshot in `sources/`, so drift in the upstream guidance is detected without anyone re-reading either page.

The canonical URL has already moved once — `anthropic.com/engineering/claude-code-best-practices` → 308 → `code.claude.com/docs/en/best-practices` — which is the kind of change the check exists to catch.

```
source: https://code.claude.com/docs/en/best-practices.md | ### Write an effective CLAUDE.md | sources/best-practices-write-an-effective-claude-md.md
source: https://code.claude.com/docs/en/memory.md | ### When to add to CLAUDE.md | sources/memory-when-to-add-to-claude-md.md
source: https://code.claude.com/docs/en/memory.md | ### Write effective instructions | sources/memory-write-effective-instructions.md
```

**Why vendored rather than fetched.** Measured 2026-08-28: the two pages are 40,068 and 36,894 bytes, and these three sections are 3,256 + 824 + 1,818 bytes of them — 8.1% and 7.1%, 818 words in total. Fetching whole pages on every `CLAUDE.md` edit would pay roughly 19,000 tokens for roughly 900 usable words, so the card is vendored and the drift check runs off the edit path instead.
````

- [ ] **Step 4: Generate the snapshots with the tool that will check them**

Run:

```bash
bash skills/claude-md-guard/scripts/refresh-rule-card --update
```

Expected: three `CREATED` lines, one per snapshot, then `snapshots rewritten` and **exit 1**. Exit 1 is correct here and is not a failure: `--update` always exits 1 because rewriting snapshots does not re-distil the card body.

If this step cannot reach the network, stop and report **BLOCKED**. Do not write the snapshot files by hand.

- [ ] **Step 5: Verify the check is now clean**

Run:

```bash
bash skills/claude-md-guard/scripts/refresh-rule-card; echo "exit=$?"
```

Expected: three `ok` lines, `no drift in 3 source section(s)`, `exit=0`.

This is the check that proves Task 1's extractor and these snapshots agree byte for byte. If it reports drift immediately after `--update`, the extractor is non-deterministic and that is a Task 1 defect — report it rather than working around it.

- [ ] **Step 6: Run the card test**

Run: `bash tests/skills/test-rule-card.sh`
Expected: PASS, ending in `OK`.

- [ ] **Step 7: Run the whole suite**

Run: `bash tests/run-tests.sh`
Expected: every file passes.

- [ ] **Step 8: Commit**

```bash
git add skills/claude-md-guard/claude-md-best-practices.md skills/claude-md-guard/sources tests/skills/test-rule-card.sh
git commit -m "feat: vendor the CLAUDE.md standard with drift-checkable source snapshots"
```

---

## Task 3: The `claude-md-guard` skill

**Files:**
- Create: `skills/claude-md-guard/SKILL.md`
- Modify: `tests/skills/test-skill-structure.sh` — the `BUDGETS` line, and a new content block

**Interfaces:**
- Consumes: `skills/claude-md-guard/claude-md-best-practices.md` (Task 2), linked as a relative markdown link so the structure test's reference-existence check verifies it.
- Produces: the skill name **`dopamine:claude-md-guard`**, which Task 4's injected context, Task 5's discovery prompt and Task 5's verifier prompt all name verbatim. Also the verdict shape `verdict: admit — <reason>` / `verdict: route <destination> — <reason>`, which Task 5's brief entries record.

**Three traps in the existing structure test, which runs against every skill automatically:**

1. **`BUDGETS` is a whitelist.** A skill with no entry fails `has a declared word budget`. Add `claude-md-guard:500`.
2. **The `@`-link check** fires on `(^|[[:space:]])@[a-zA-Z./]`. The body below contains no `@` at all; keep it that way. If a future edit needs to mention import syntax, wrap it in backticks — a backtick before the `@` is what lets it through.
3. **The description check** rejects a description matching `(then|,) *(dispatch|write|run|review)` — a description must state triggers, not summarise the workflow.

The body below is **432 words** against the 500-word budget, measured. That leaves room, but not licence to pad.

- [ ] **Step 1: Add the budget entry and the content assertions to the structure test**

In `tests/skills/test-skill-structure.sh`, change the `BUDGETS` line from:

```bash
BUDGETS="artifact-map:500 sweep:700"
```

to:

```bash
BUDGETS="artifact-map:500 sweep:700 claude-md-guard:500"
```

Then, immediately before the final `finish` call, add:

```bash
echo "-- claude-md-guard content"
guard="$REPO_ROOT/skills/claude-md-guard/SKILL.md"
if [ -f "$guard" ]; then
    body=$(cat "$guard")
    assert_contains "it asks the admission question, not only the staleness one" \
        "$body" "belong here"
    assert_contains "a rejected line is routed rather than dropped" "$body" "routed"
    assert_contains "the lessons tier is one of the destinations" "$body" "lessons tier"
    assert_contains "a path-scoped rule is one of the destinations" "$body" ".claude/rules/"
    assert_contains "it links the vendored standard" "$body" "claude-md-best-practices.md"
    assert_contains "it names the drift check" "$body" "refresh-rule-card"
    assert_contains "it gives the admit verdict shape" "$body" "verdict: admit"
    assert_contains "it gives the route verdict shape" "$body" "verdict: route"
    assert_contains "it points at the artifact map rather than restating it" \
        "$body" "dopamine:artifact-map"
else
    fail "skills/claude-md-guard/SKILL.md exists" "not found"
fi
```

- [ ] **Step 2: Run the structure test to verify it fails**

Run: `bash tests/skills/test-skill-structure.sh`
Expected: FAIL with `skills/claude-md-guard/SKILL.md exists … not found`.

- [ ] **Step 3: Write the skill**

Create `skills/claude-md-guard/SKILL.md`:

````markdown
---
name: claude-md-guard
description: Use when a line is about to be added to CLAUDE.md, when a sweep is draining into it, or when a recurring lesson is proposed for promotion to an always-loaded line
---

# CLAUDE.md guard

## Overview

`CLAUDE.md` is drained like a living document, and verified against one extra question.

1. **Is this still true?** — asked everywhere.
2. **Does this belong here at all?** — the admission test.

The second is the one that pays. A predecessor project carried 516 lines of `CLAUDE.md` that were not false; they were **misfiled**. Design rationale reads perfectly well there, and is then paid for on every session while duplicating the design document. Staleness checking would never have caught it.

**REQUIRED BACKGROUND:** Use dopamine:artifact-map — it holds the tier each destination below belongs to.

## When the guard fires

- **After an edit to an instructions-tier file.** The `PostToolUse` hook carries the file's numbers and points here.
- **During a sweep**, when discovery places a claim whose destination is the instructions tier.
- **On a promotion** — a lesson that has recurred, offered as an always-loaded line.

## The test

For each candidate line: **would removing it cause Claude to make mistakes?**

A line that survives is admitted. A line that does not is **routed** — it has a destination, and naming it is what makes the test a routing decision rather than a rejection. An agent holding a true fact with nowhere to put it will argue to keep it.

| The candidate | Its home |
|---|---|
| A command, convention or gotcha that holds across the whole project | Admitted |
| Relevant only sometimes, or a multi-step procedure | A skill, loaded on demand |
| True only of part of the tree | A path-scoped rule under `.claude/rules/` |
| A dated observation that stays true | The lessons tier |
| Design rationale, or anything a living document already states | That living document |
| Derivable by reading the code, or a standard practice | Cut |

The standard behind the table, with its sources and the measurements that justify vendoring it: [claude-md-best-practices.md](claude-md-best-practices.md).

## The verdict

One line per candidate, in the form a sweep brief records:

```
verdict: admit — <the include row it matches>
verdict: route <destination> — <one line of reason>
```

A routed promotion keeps its verdict in the brief. That is what stops the next recurrence re-litigating a decision already made.

## Keeping the card honest

`scripts/refresh-rule-card` re-fetches the three source sections and diffs them against the snapshots in `sources/`. Run it occasionally, off the edit path: the source pages are ~40 KB each and the guidance is under 8% of them, so fetching on every edit would pay ~19,000 tokens for ~900 usable words.
````

- [ ] **Step 4: Run the structure test to verify it passes**

Run: `bash tests/skills/test-skill-structure.sh`
Expected: PASS. Confirm the run reports `claude-md-guard: within its 500-word budget (432 words)`. A different word count means the body was altered in transcription — check it against the plan before continuing.

- [ ] **Step 5: Run the whole suite**

Run: `bash tests/run-tests.sh`
Expected: every file passes.

- [ ] **Step 6: Commit**

```bash
git add skills/claude-md-guard/SKILL.md tests/skills/test-skill-structure.sh
git commit -m "feat: the claude-md-guard skill — the admission test and its routing table"
```

---

## Task 4: The `PostToolUse` guard hook

**Files:**
- Create: `hooks/py-hook`, `hooks/claude-md-guard`, `hooks/claude_md_guard.py`, `hooks/claude-md-guard-context.md`
- Modify: `hooks/seal-gate` (becomes a shim), `hooks/hooks.json`
- Test: `tests/hooks/test-claude-md-guard.sh`

**Interfaces:**
- Consumes: `.dopamine/config`'s `instructions:` and `lessons:` tiers, parsed directly rather than through `artifact-paths` — a hook must not depend on a script in another skill's directory. The skill name `dopamine:claude-md-guard` from Task 3.
- Produces: nothing later tasks call. Task 6's end-to-end test drives `hooks/claude-md-guard` by path and asserts on its JSON.

### Design decisions this task implements

**The hook computes only what a script can know for certain.** It cannot render an admission verdict — that is a judgement. `superpowers:writing-skills` draws exactly this line: *"Mechanical constraints (if it's enforceable with regex/validation, automate it — save documentation for judgment calls)."* So the hook reports three mechanical facts — the file's line count against the 200-line target, what this working tree adds and removes since `HEAD`, and which path holds the lessons tier — and hands the judgement to the agent, pointed at the skill.

**The predicate is "an instructions-tier file was edited", and nothing narrower.** Not "the file grew": a `Write` overwrites the file before the hook fires, so there is no reliable per-edit delta to threshold on, and an edit that rewrites a line admits content just as an appended one does. A simple, observable predicate is testable; a clever one is not. The cost of the simple version is one short message on an edit that only deletes lines.

**The instructions tier comes from the config, never from the filename.** `hooks.json` matches `Edit|Write` broadly and the hook consults `.dopamine/config`. Claude Code's `if` field would allow `"Edit(CLAUDE.md)"` directly in `hooks.json`, and that is rejected: it hard-codes one project's document set into the plugin, which every other component avoids. A project that declares `instructions: AGENTS.md` is served correctly by the config-driven version and not at all by the other.

**Two output shapes, not three.** `hooks/session-start` branches three ways because Cursor documents a `additional_context` field for `SessionStart`. No Cursor-specific `PostToolUse` field name is documented, so this hook emits the nested Claude Code shape when `CLAUDE_PLUGIN_ROOT` is set and `COPILOT_CLI` is not, and the flat `additionalContext` shape otherwise. Inventing a third field name would be inventing a value that must be confirmed. This becomes a README known gap in Task 6.

**`py-hook` removes a duplicated fail-open probe.** The interpreter probe, the stdin drain and the exit-0 discipline in `hooks/seal-gate` are subtle and are now needed twice. They move into `hooks/py-hook`; `seal-gate` becomes a two-line shim that keeps its name, so `hooks.json`'s `PreToolUse` entry and the seal-gate tests' `UNDER_TEST` path are both unchanged. **Slice 1's seal-gate test file is the regression gate for this move** — it must pass with the same assertion count afterwards.

- [ ] **Step 1: Write the failing test**

Create `tests/hooks/test-claude-md-guard.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

UNDER_TEST="$REPO_ROOT/hooks/claude-md-guard"
CONTEXT_FILE="$REPO_ROOT/hooks/claude-md-guard-context.md"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

# make_repo NAME [--no-config|--no-instructions] -- prints the repo path
make_repo() {
    local repo="$TEST_ROOT/$1"
    mkdir -p "$repo/docs"
    git init -q "$repo" 2>/dev/null
    git -C "$repo" config user.email "test@example.com"
    git -C "$repo" config user.name "Test"
    printf '# Project\n\n- Run make test before committing.\n' > "$repo/CLAUDE.md"
    printf '# Lessons\n' > "$repo/docs/LESSONS.md"
    printf '# Design\n' > "$repo/docs/DESIGN.md"
    case "${2:-}" in
        --no-config) ;;
        --no-instructions)
            mkdir -p "$repo/.dopamine"
            printf 'living: docs/DESIGN.md\nplans: docs/superpowers/plans\n' \
                > "$repo/.dopamine/config"
            ;;
        *)
            mkdir -p "$repo/.dopamine"
            {
                printf 'living: docs/DESIGN.md\n'
                printf 'instructions: CLAUDE.md\n'
                printf 'lessons: docs/LESSONS.md\n'
                printf 'plans: docs/superpowers/plans\n'
            } > "$repo/.dopamine/config"
            ;;
    esac
    printf '%s\n' "$repo"
}

# event TOOL CWD FILE_PATH -- prints a PostToolUse event JSON
event() {
    TOOL="$1" CWD="$2" FP="$3" python3 -c '
import json, os
print(json.dumps({
    "hook_event_name": "PostToolUse",
    "cwd": os.environ["CWD"],
    "tool_name": os.environ["TOOL"],
    "tool_input": {"file_path": os.environ["FP"]},
    "tool_response": {"filePath": os.environ["FP"], "success": True},
}))'
}

# run_hook REPO EVENT_JSON -- sets RC and OUT
run_hook() {
    RC=0
    OUT=$(printf '%s' "$2" | (cd "$1" && CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$UNDER_TEST")) || RC=$?
}

# field JSON DOTTED_PATH -- prints the value, or "none"
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

keys() {
    printf '%s' "$1" | python3 -c '
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    print("none"); raise SystemExit
print(",".join(sorted(json.loads(raw).keys())))'
}

repo=$(make_repo adopted)

echo "-- the guard stays silent unless its predicate holds"
run_hook "$repo" "$(event Edit "$repo" "$repo/docs/DESIGN.md")"
assert_eq "a living-tier file exits 0" 0 "$RC"
assert_eq "and injects nothing" "" "$OUT"

run_hook "$repo" "$(event Edit "$repo" "$repo/docs/LESSONS.md")"
assert_eq "a lessons-tier file injects nothing" "" "$OUT"

run_hook "$repo" "$(event Bash "$repo" "")"
assert_eq "an event with no file_path injects nothing" "" "$OUT"

plain=$(make_repo plain --no-config)
run_hook "$plain" "$(event Edit "$plain" "$plain/CLAUDE.md")"
assert_eq "a repo with no .dopamine/config exits 0" 0 "$RC"
assert_eq "and injects nothing" "" "$OUT"

noinst=$(make_repo noinst --no-instructions)
run_hook "$noinst" "$(event Edit "$noinst" "$noinst/CLAUDE.md")"
assert_eq "a config with no instructions tier injects nothing" "" "$OUT"

run_hook "$repo" "$(event Edit "$repo" "$TEST_ROOT/outside.md")"
assert_eq "a file outside the declared set injects nothing" "" "$OUT"

echo "-- the verdict on an instructions-tier edit"
run_hook "$repo" "$(event Edit "$repo" "$repo/CLAUDE.md")"
assert_eq "exits 0" 0 "$RC"
ctx=$(field "$OUT" "hookSpecificOutput.additionalContext")
assert_eq "uses the nested PostToolUse shape" \
    "PostToolUse" "$(field "$OUT" "hookSpecificOutput.hookEventName")"
assert_contains "reports the file it is talking about" "$ctx" "CLAUDE.md"
assert_contains "reports the line count as a fact" "$ctx" "3 lines"
assert_contains "names the 200-line target" "$ctx" "200-line target"
assert_contains "names the lessons tier from the config" "$ctx" "docs/LESSONS.md"
assert_contains "carries the per-line test" "$ctx" "make mistakes"
assert_contains "points at the skill that holds the judgement" "$ctx" "dopamine:claude-md-guard"

echo "-- a Write is treated the same as an Edit"
run_hook "$repo" "$(event Write "$repo" "$repo/CLAUDE.md")"
assert_contains "Write also gets the verdict" \
    "$(field "$OUT" "hookSpecificOutput.additionalContext")" "make mistakes"

echo "-- growth since HEAD is reported when git can say"
git -C "$repo" add -A >/dev/null 2>&1
git -C "$repo" commit -q -m "init" >/dev/null 2>&1
run_hook "$repo" "$(event Edit "$repo" "$repo/CLAUDE.md")"
ctx=$(field "$OUT" "hookSpecificOutput.additionalContext")
assert_not_contains "a clean tree reports no delta" "$ctx" "since HEAD"
printf -- '- Prefer single tests.\n- Typecheck when done.\n' >> "$repo/CLAUDE.md"
run_hook "$repo" "$(event Edit "$repo" "$repo/CLAUDE.md")"
ctx=$(field "$OUT" "hookSpecificOutput.additionalContext")
assert_contains "a dirty tree reports what it adds" "$ctx" "since HEAD"
assert_contains "and the count is real" "$ctx" "adds 2"

echo "-- a second declared instructions path also fires"
printf 'instructions: CLAUDE.local.md\n' >> "$repo/.dopamine/config"
printf '# Local\n' > "$repo/CLAUDE.local.md"
run_hook "$repo" "$(event Edit "$repo" "$repo/CLAUDE.local.md")"
assert_contains "the second instructions path is matched too" \
    "$(field "$OUT" "hookSpecificOutput.additionalContext")" "CLAUDE.local.md"

echo "-- the flat shape for hosts that do not set CLAUDE_PLUGIN_ROOT"
RC=0
OUT=$(printf '%s' "$(event Edit "$repo" "$repo/CLAUDE.md")" \
    | (cd "$repo" && COPILOT_CLI=1 CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$UNDER_TEST")) || RC=$?
assert_eq "Copilot's top-level key is exactly additionalContext" "additionalContext" "$(keys "$OUT")"
assert_not_contains "and it is not the nested shape" "$OUT" "hookSpecificOutput"

echo "-- the injected text is budgeted and positively phrased"
words=$(wc -w < "$CONTEXT_FILE" | tr -d ' ')
if [ "$words" -le 175 ]; then
    pass "the injection is within its 175-word budget ($words words)"
else
    fail "the injection is within its 175-word budget" "got: $words words"
fi
if grep -qiE '\b(never|do not|don.t)\b' "$CONTEXT_FILE"; then
    fail "avoids prohibition form (spec 9.4: our failure is wrong-shaped output)" \
         "found a prohibition in $CONTEXT_FILE"
else
    pass "avoids prohibition form (spec 9.4: our failure is wrong-shaped output)"
fi
ctx_body=$(cat "$CONTEXT_FILE")
assert_contains "the injection routes rather than rejects" "$ctx_body" "routed"
assert_contains "and names a destination for a sometimes-relevant line" "$ctx_body" "skill"

echo "-- malformed input is a silent no-op, never a crash"
RC=0
OUT=$(printf 'not json at all' | (cd "$repo" && CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$UNDER_TEST")) || RC=$?
assert_eq "garbage on stdin exits 0" 0 "$RC"
assert_eq "and injects nothing" "" "$OUT"

RC=0
OUT=$(printf '{"tool_input": []}' | (cd "$repo" && CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$UNDER_TEST")) || RC=$?
assert_eq "a tool_input of the wrong type exits 0" 0 "$RC"
assert_eq "and injects nothing" "" "$OUT"

finish
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/hooks/test-claude-md-guard.sh`
Expected: FAIL — `hooks/claude-md-guard` does not exist.

- [ ] **Step 3: Create the shared interpreter probe**

Create `hooks/py-hook` and `chmod +x` it:

```bash
#!/usr/bin/env bash
# Locate a Python 3 interpreter and hand it the named hook script.
#
# Python 3 is dopamine's only runtime dependency beyond bash and git. If none is
# present, the hook exits 0 with a note on stderr rather than failing: a hook that
# cannot run must never break the session it exists to help. Failing open loses
# the guarantee; failing closed loses the session.
#
# Usage: py-hook <script.py>
set -u
export PYTHONUTF8=1

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-}"

if [ -z "$TARGET" ]; then
    echo "py-hook: missing script name" >&2
    exit 0
fi

for cmd in python3 python "py -3"; do
    # shellcheck disable=SC2086
    if $cmd -c 'import sys; sys.exit(0 if sys.version_info[0] == 3 else 1)' >/dev/null 2>&1; then
        # shellcheck disable=SC2086
        exec $cmd "$SCRIPT_DIR/$TARGET"
    fi
done

# Drain whatever the caller wrote to stdin before bailing out: nothing past this
# point reads it, and leaving it unread hands the caller a broken pipe on its own
# write instead of a clean, silent no-op. A bash builtin, not `cat`: this branch
# runs precisely when the environment is too broken to trust an external command
# to resolve at all.
IFS= read -r -d '' _ 2>/dev/null

echo "dopamine: no Python 3 interpreter found; ${TARGET%.py} is inactive this session." >&2
exit 0
```

- [ ] **Step 4: Reduce `hooks/seal-gate` to a shim and confirm slice 1 still passes**

Replace the whole of `hooks/seal-gate` with:

```bash
#!/usr/bin/env bash
# The PreToolUse seal gate. Its interpreter probe is shared with every other
# Python hook in this plugin and lives in py-hook; this file keeps its name
# because hooks.json registers it and the gate's tests invoke it by this path.
#
# "$BASH" is the absolute path of the shell already running this script, so the
# hand-off needs neither a PATH lookup nor an executable bit on py-hook.
set -u
exec "${BASH:-bash}" "$(cd "$(dirname "$0")" && pwd)/py-hook" seal_gate.py
```

Run: `bash tests/hooks/test-seal-gate.sh`
Expected: PASS, with the **same number of assertions as before the change**. Record that count before and after. If any assertion changes, revert the shim and report the failure — slice 1's gate is shipped, reviewed behaviour and this task is not licensed to change it.

- [ ] **Step 5: Write the guard's context template**

Create `hooks/claude-md-guard-context.md`. This is 146 words, measured:

```markdown
**CLAUDE.md admission test (dopamine)**

Two questions decide whether a line stays. *Is it still true?* — and the one that catches more: *does it belong here at all?* This file loads at the start of every session, so every line in it is paid for in every session.

For each line this edit added, ask: **would removing it cause Claude to make mistakes?** If the answer is no, it has a better home:

- Relevant only sometimes, or a multi-step procedure → a skill.
- True only of part of the tree → a path-scoped rule.
- A dated observation that stays true → the lessons tier.
- Design rationale a living document already carries → that document.
- Derivable by reading the code → cut it.

Content that fails the test is routed, not discarded. The full standard, its sources and the verdict shape: `dopamine:claude-md-guard`.
```

- [ ] **Step 6: Write the hook**

Create `hooks/claude_md_guard.py` (no executable bit — `py-hook` runs it):

```python
#!/usr/bin/env python3
"""PostToolUse guard: after an edit to an instructions-tier file, return the
admission test as additionalContext.

The hook renders no verdict, because a verdict is a judgement and this is a
shell-invoked script. It reports what a script can know for certain — the file's
length against the 200-line target, what this working tree adds and removes since
HEAD, and which path holds the lessons tier — and hands the judgement to the
agent, pointed at dopamine:claude-md-guard. superpowers:writing-skills draws that
line explicitly: automate the mechanical constraint, save documentation for the
judgement call.

Silent no-op unless all of these hold:
  * the tool call carries a tool_input.file_path,
  * a repository root resolves from the event's cwd,
  * .dopamine/config declares at least one `instructions:` path,
  * and the edited file is one of them.

Why additionalContext rather than a warning or a block: a hook that exits 0 sends
stderr to the debug log only and Claude never sees it, so a plain warning changes
nothing; exit 2 shows stderr to Claude framed as a blocking error, which an
admission test is not. additionalContext arrives beside the tool result with no
error framing. Escalation to exit 2 remains available if it proves ignorable.

Known gap, accepted: Claude Code does not fire a PostToolUse hook matching
Edit|Write when a Bash command rewrites the same file, so `cat >> CLAUDE.md`
bypasses this guard. The sweep's own draining of the instructions tier is the
backstop for that path.
"""

import json
import os
import subprocess
import sys

TARGET_LINES = 200
CONTEXT_FILE = "claude-md-guard-context.md"


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


def declared(root, tier):
    """Every path declared for one tier in .dopamine/config, repo-relative.

    An empty list means this repository has not adopted dopamine, or has not
    declared that tier, and the guard stays inert either way.
    """
    config = os.path.join(root, ".dopamine", "config")
    paths = []
    try:
        with open(config, encoding="utf-8") as handle:
            for raw in handle:
                line = raw.split("#", 1)[0].strip()
                if ":" not in line:
                    continue
                name, _, path = line.partition(":")
                if name.strip() == tier and path.strip():
                    paths.append(path.strip())
    except OSError:
        return []
    return paths


def same_file(a, b):
    return os.path.normcase(os.path.realpath(a)) == os.path.normcase(os.path.realpath(b))


def line_count(path):
    try:
        with open(path, "rb") as handle:
            return sum(1 for _ in handle)
    except OSError:
        return None


def worktree_delta(root, relpath):
    """(added, removed) for this path against HEAD, or None if git cannot say."""
    try:
        result = subprocess.run(
            ["git", "-C", root, "diff", "HEAD", "--numstat", "--", relpath],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if result.returncode != 0:
        return None
    for row in result.stdout.splitlines():
        parts = row.split("\t")
        # A binary file reports "-" for both counts; only digits are usable.
        if len(parts) >= 3 and parts[0].isdigit() and parts[1].isdigit():
            return int(parts[0]), int(parts[1])
    return None


def facts(root, relpath, abspath):
    lines = line_count(abspath)
    if lines is None:
        return None
    sentence = "`{path}` is {lines} lines against the {target}-line target".format(
        path=relpath, lines=lines, target=TARGET_LINES
    )
    delta = worktree_delta(root, relpath)
    if delta is not None and (delta[0] or delta[1]):
        sentence += "; this working tree adds {a} and removes {r} since HEAD".format(
            a=delta[0], r=delta[1]
        )
    sentence += "."
    lessons = declared(root, "lessons")
    if lessons:
        sentence += " The lessons tier here is `{path}`.".format(path=lessons[0])
    return sentence


def context_text():
    here = os.path.dirname(os.path.abspath(__file__))
    try:
        with open(os.path.join(here, CONTEXT_FILE), encoding="utf-8") as handle:
            return handle.read().strip()
    except OSError:
        return None


def emit(context):
    """Claude Code reads the nested shape; other hosts read the flat one.

    No Cursor-specific PostToolUse field name is documented, so Cursor receives
    the flat shape rather than an invented one.
    """
    if os.environ.get("CLAUDE_PLUGIN_ROOT") and not os.environ.get("COPILOT_CLI"):
        payload = {
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "additionalContext": context,
            }
        }
    else:
        payload = {"additionalContext": context}
    json.dump(payload, sys.stdout)
    sys.stdout.write("\n")


def main():
    event = read_event()
    if not isinstance(event, dict):
        return 0

    tool_input = event.get("tool_input")
    if not isinstance(tool_input, dict):
        return 0
    file_path = tool_input.get("file_path")
    if not isinstance(file_path, str) or not file_path:
        return 0

    root = repo_root(event.get("cwd") or os.getcwd())
    if root is None:
        return 0

    for relpath in declared(root, "instructions"):
        candidate = os.path.join(root, relpath)
        if not same_file(candidate, file_path):
            continue
        body = context_text()
        if body is None:
            return 0
        line = facts(root, relpath, candidate)
        emit(line + "\n\n" + body if line else body)
        return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 7: Create the guard's wrapper**

Create `hooks/claude-md-guard` and `chmod +x` it:

```bash
#!/usr/bin/env bash
# The PostToolUse admission-test hook. See py-hook for the interpreter probe and
# the reason every dopamine hook fails open.
set -u
exec "${BASH:-bash}" "$(cd "$(dirname "$0")" && pwd)/py-hook" claude_md_guard.py
```

- [ ] **Step 8: Register the hook**

In `hooks/hooks.json`, add a `PostToolUse` entry as a sibling of the existing `SessionStart` and `PreToolUse` entries, inside the `"hooks"` object:

```json
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" claude-md-guard",
            "shell": "bash",
            "async": false
          }
        ]
      }
    ]
```

Then confirm the file is still valid JSON with all three events registered:

```bash
python3 -c "import json;d=json.load(open('hooks/hooks.json'));print(sorted(d['hooks']))"
```

Expected: `['PostToolUse', 'PreToolUse', 'SessionStart']`

- [ ] **Step 9: Run the guard test to verify it passes**

Run: `bash tests/hooks/test-claude-md-guard.sh`
Expected: PASS, ending in `OK`.

- [ ] **Step 10: Run the whole suite**

Run: `bash tests/run-tests.sh`
Expected: every file passes, including `test-seal-gate.sh` at its original assertion count.

- [ ] **Step 11: Commit**

```bash
git add hooks/py-hook hooks/seal-gate hooks/claude-md-guard hooks/claude_md_guard.py \
        hooks/claude-md-guard-context.md hooks/hooks.json tests/hooks/test-claude-md-guard.sh
git commit -m "feat: PostToolUse admission-test hook, over a shared fail-open probe"
```

---

## Task 5: Close the slice-1 seam — promotions become gated

**Files:**
- Modify: `skills/sweep/discovery-prompt.md` — the **Promotions** section
- Modify: `skills/sweep/verifier-prompt.md` — the **Discipline** verdict
- Modify: `tests/skills/test-skill-structure.sh` — assertions in the existing `-- sweep content` block

**Interfaces:**
- Consumes: the skill name `dopamine:claude-md-guard` and the verdict shape `verdict: admit` / `verdict: route <destination>` from Task 3.
- Produces: nothing later tasks call. Task 6 asserts these two prompts name the guard.

**What this closes.** Slice 1 shipped `discovery-prompt.md` saying, verbatim: *"A promotion is a proposal. Until this project has the `CLAUDE.md` admission guard, record it and leave it unapplied."* That sentence names a condition which this slice satisfies. Leaving it in place would leave the plugin permanently declining to apply its own promotions — a producer's prose describing a contract the consumer now honours differently, which is exactly the seam defect this project exists to prevent.

**`skills/sweep/SKILL.md` is not touched.** It sits at 699 of 700 words, and the promotion contract belongs in the prompt that judges promotions. See the File Structure section for the full ruling.

- [ ] **Step 1: Add the failing assertions**

In `tests/skills/test-skill-structure.sh`, inside the existing `-- sweep content` block, in the `if [ -f "$discovery" ]` branch, add after the existing discovery assertions:

```bash
        assert_contains "a promotion is put through the admission test" \
            "$dbody" "dopamine:claude-md-guard"
        assert_contains "an admitted promotion becomes an Edit" "$dbody" "verdict: admit"
        assert_contains "a routed promotion records where it went instead" \
            "$dbody" "verdict: route"
        assert_not_contains "the promotion is no longer parked unapplied" \
            "$dbody" "leave it unapplied"
```

and in the `if [ -f "$verifier" ]` branch, after the existing verifier assertions:

```bash
        assert_contains "an ungated promotion is a finding" "$vbody" "Ungated"
        assert_contains "the verifier knows promotions carry a verdict" "$vbody" "verdict"
```

- [ ] **Step 2: Run the structure test to verify it fails**

Run: `bash tests/skills/test-skill-structure.sh`
Expected: FAIL on the four discovery assertions and the two verifier assertions.

- [ ] **Step 3: Rewrite the discovery prompt's Promotions section**

In `skills/sweep/discovery-prompt.md`, replace the whole `### Promotions` section — both paragraphs, including the sentence beginning "A promotion is a proposal" — with:

```markdown
### Promotions

A claim that has recurred: you found a near-identical entry already in the append-mostly tier. A lesson learned twice is evidence that one always-loaded line would have prevented the second occurrence. Give the line you propose for the instructions tier, and the two occurrences that justify it.

Then put it through the admission test. Load the dopamine:claude-md-guard skill by name and record its verdict on the entry, in the form that skill gives:

- **`verdict: admit`** — the promotion also becomes an **Edit** against the instructions-tier path, located and quoted like every other edit.
- **`verdict: route <destination>`** — the claim stays where it is. The recorded verdict and its reason are what stop the next recurrence re-litigating a decision already made.

A promotion carrying no verdict is an incomplete entry.
```

- [ ] **Step 4: Add the Ungated finding to the verifier prompt**

In `skills/sweep/verifier-prompt.md`, in the `## 2. Discipline` list, add this bullet immediately after the **No number describing a run** bullet and before the **Historical records untouched** bullet:

```markdown
- **Promotions were gated.** Every promotion in the brief carries a verdict from the admission test. A hunk that adds a line to the instructions tier and traces to no entry with `verdict: admit` is an **Ungated** finding — and so is a promotion the brief records as routed whose proposed line appears in the instructions tier anyway.
```

- [ ] **Step 5: Run the structure test to verify it passes**

Run: `bash tests/skills/test-skill-structure.sh`
Expected: PASS. Confirm `sweep: within its 700-word budget` still reports **699 words** — `skills/sweep/SKILL.md` must not have been touched.

- [ ] **Step 6: Run the whole suite**

Run: `bash tests/run-tests.sh`
Expected: every file passes.

- [ ] **Step 7: Commit**

```bash
git add skills/sweep/discovery-prompt.md skills/sweep/verifier-prompt.md tests/skills/test-skill-structure.sh
git commit -m "feat: a sweep promotion is now gated by the admission test, not parked"
```

---

## Task 6: End-to-end chain, and the README

**Files:**
- Create: `tests/test-guard-end-to-end.sh`
- Modify: `README.md`

**Interfaces:**
- Consumes: every artifact from Tasks 1–5.
- Produces: the slice's exit evidence.

**What the end-to-end test is for, and what it is not.** The unit tests check each piece against its own contract. This one checks the **chain of names between them**, which no unit test can see: the hook names a skill, the skill links a card, the card names snapshots, the snapshots are what the extractor produces. Rename any one of those and every unit test still passes while the shipped plugin points at nothing. It runs entirely offline.

- [ ] **Step 1: Write the failing test**

Create `tests/test-guard-end-to-end.sh`:

```bash
#!/usr/bin/env bash
# The guard, end to end, offline.
#
# Each unit test checks one component against its own contract. This one checks
# the chain of names between them: the hook names a skill, the skill links a card,
# the card names snapshots, and the extractor round-trips those snapshots. Rename
# any link in that chain and every unit test still passes while the shipped plugin
# points at nothing.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

GUARD_DIR="$REPO_ROOT/skills/claude-md-guard"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

echo "-- a repository adopts dopamine, and an edit to its instructions file is met"
repo="$TEST_ROOT/project"
mkdir -p "$repo/docs" "$repo/.dopamine"
git init -q "$repo" 2>/dev/null
git -C "$repo" config user.email "test@example.com"
git -C "$repo" config user.name "Test"
{
    printf 'living: docs/DESIGN.md\n'
    printf 'instructions: CLAUDE.md\n'
    printf 'lessons: docs/LESSONS.md\n'
    printf 'plans: docs/superpowers/plans\n'
} > "$repo/.dopamine/config"
printf '# Project\n\n- Run make test before committing.\n' > "$repo/CLAUDE.md"
printf '# Lessons\n' > "$repo/docs/LESSONS.md"

evt=$(CWD="$repo" FP="$repo/CLAUDE.md" python3 -c '
import json, os
print(json.dumps({
    "hook_event_name": "PostToolUse",
    "cwd": os.environ["CWD"],
    "tool_name": "Edit",
    "tool_input": {"file_path": os.environ["FP"]},
}))')

RC=0
out=$(printf '%s' "$evt" | (cd "$repo" && CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$REPO_ROOT/hooks/claude-md-guard")) || RC=$?
assert_eq "the guard exits 0" 0 "$RC"

ctx=$(printf '%s' "$out" | python3 -c '
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    print(""); raise SystemExit
print(json.loads(raw).get("hookSpecificOutput", {}).get("additionalContext", ""))')
assert_contains "a verdict arrived" "$ctx" "make mistakes"

echo "-- the chain of names holds"
named_skill=$(printf '%s' "$ctx" | grep -o 'dopamine:[a-z-]*' | head -1)
assert_eq "the injection names the guard skill" "dopamine:claude-md-guard" "$named_skill"
assert_eq "and that skill exists in the plugin" "yes" \
    "$([ -f "$GUARD_DIR/SKILL.md" ] && echo yes || echo no)"

linked=$(grep -oE '\[[^]]*\]\(([a-zA-Z0-9._/-]+\.md)\)' "$GUARD_DIR/SKILL.md" \
    | sed -E 's/.*\((.*)\)/\1/' | sort -u)
assert_eq "the skill links exactly one sibling document" "claude-md-best-practices.md" "$linked"
assert_eq "and that document exists" "yes" \
    "$([ -f "$GUARD_DIR/$linked" ] && echo yes || echo no)"

named_script=$(grep -o 'refresh-rule-card' "$GUARD_DIR/SKILL.md" | head -1)
assert_eq "the skill names the drift check" "refresh-rule-card" "$named_script"
assert_eq "and the script exists and is executable" "yes" \
    "$([ -x "$GUARD_DIR/scripts/refresh-rule-card" ] && echo yes || echo no)"

echo "-- the shipped card, extractor and snapshots agree, with no network"
# The whole card is rebuilt in a scratch directory, with each shipped snapshot
# copied in and named as its own source. Snapshot paths resolve relative to the
# card, so the copy is what keeps this test from writing into the plugin it is
# testing. Extracting a section from a file that *is* that section must return the
# file unchanged, so a clean run proves the shipped snapshots are exactly what the
# shipped extractor produces -- the property that makes the real drift check
# trustworthy.
mkdir -p "$TEST_ROOT/card/sources"
cp "$GUARD_DIR"/sources/*.md "$TEST_ROOT/card/sources/"
local_card="$TEST_ROOT/card/claude-md-best-practices.md"
: > "$local_card"
count=0
while IFS= read -r line; do
    trimmed=${line#*source:}
    snap=$(printf '%s' "${trimmed#*|}" | sed 's/.*|//' | tr -d ' ')
    [ -f "$GUARD_DIR/$snap" ] || { fail "declared snapshot exists" "missing: $snap"; continue; }
    heading=$(head -1 "$GUARD_DIR/$snap")
    printf 'source: file://%s | %s | %s\n' "$TEST_ROOT/card/$snap" "$heading" "$snap" >> "$local_card"
    count=$((count + 1))
done < <(grep -E '^[[:space:]]*source:' "$GUARD_DIR/claude-md-best-practices.md")

assert_eq "the card declares three sources" 3 "$count"

RC=0
out=$("$GUARD_DIR/scripts/refresh-rule-card" "$local_card" 2>&1) || RC=$?
assert_eq "the extractor round-trips every shipped snapshot" 0 "$RC"
assert_contains "and says so" "$out" "no drift"

echo "-- the sweep now gates promotions on the guard"
disc="$REPO_ROOT/skills/sweep/discovery-prompt.md"
assert_contains "discovery names the guard" "$(cat "$disc")" "dopamine:claude-md-guard"
assert_not_contains "and no longer parks promotions" "$(cat "$disc")" "leave it unapplied"
assert_contains "the verifier can find an ungated promotion" \
    "$(cat "$REPO_ROOT/skills/sweep/verifier-prompt.md")" "Ungated"

echo "-- all three hook events are registered"
events=$(python3 -c "
import json
print(','.join(sorted(json.load(open('$REPO_ROOT/hooks/hooks.json'))['hooks'])))")
assert_eq "SessionStart, PreToolUse and PostToolUse" \
    "PostToolUse,PreToolUse,SessionStart" "$events"

finish
```

- [ ] **Step 2: Run the test to verify it fails, then passes**

Run: `bash tests/test-guard-end-to-end.sh`

If Tasks 1–5 are complete this passes on the first run, which is expected for an integration test written last. Before accepting a first-run pass, **break one link and confirm the test notices**: temporarily rename `skills/claude-md-guard/claude-md-best-practices.md`, re-run, confirm the `that document exists` assertion fails, then rename it back and re-run. A test that has never been seen to fail is not yet a test.

- [ ] **Step 3: Update the README**

In `README.md`, add two rows to the component table, after the `PreToolUse seal gate` row:

```markdown
| `PostToolUse` guard | Fires when a file in the `instructions` tier is edited. Reports its length against the 200-line target and hands the admission test to the agent |
| `dopamine:claude-md-guard` | The admission test, the routing table for what fails it, and the vendored standard behind both |
```

In the **Requirements** section, after the existing paragraph, add:

```markdown
`skills/claude-md-guard/scripts/refresh-rule-card` also needs **curl or wget**, and network access. It is a maintenance script that runs off the edit path; nothing else in the plugin makes a network request.
```

In **Known gaps**, add these two bullets:

```markdown
- **A `CLAUDE.md` rewritten by a Bash command does not fire the guard.** Claude Code runs a `PostToolUse` hook matching `Edit|Write` only for those tools, so `cat >> CLAUDE.md` bypasses the admission test. The sweep's own draining of the instructions tier is the backstop, and `FileChanged` is the escalation if this proves common.
- **Only Claude Code's `PostToolUse` output shape is documented.** The guard emits the nested `hookSpecificOutput` shape there and a flat `additionalContext` object everywhere else. Cursor documents its own field name for `SessionStart` but not for `PostToolUse`, so it receives the flat shape rather than an invented one.
```

Replace the whole **Status** section with:

```markdown
## Status

Slices 1 and 2 of three. The authoring skills — `brainstorm-design`, `brainstorm-architecture`, `writing-roadmaps` and `adopting-a-repo` — are not built yet; see `docs/superpowers/specs/2026-08-28-dopamine-design.md` §12.
```

- [ ] **Step 4: Run the whole suite**

Run: `bash tests/run-tests.sh`
Expected: every file passes. The suite is now **11 files**: slice 1's seven, plus `test-refresh-rule-card.sh`, `test-rule-card.sh`, `test-claude-md-guard.sh` and `test-guard-end-to-end.sh`.

- [ ] **Step 5: Confirm the shipped card is genuinely current**

Run:

```bash
bash skills/claude-md-guard/scripts/refresh-rule-card; echo "exit=$?"
```

Expected: `no drift in 3 source section(s)`, `exit=0`.

This needs the network. If it reports drift, the upstream guidance changed between Task 2 and now — record what changed in the ledger, re-distil the card body against the diff, and re-run `--update`. Do not silence it.

- [ ] **Step 6: Commit**

```bash
git add tests/test-guard-end-to-end.sh README.md
git commit -m "feat: end-to-end chain test for the guard, and README for slice 2"
```

---

## Definition of done

- `bash tests/run-tests.sh` green across 11 files.
- `bash skills/claude-md-guard/scripts/refresh-rule-card` exits 0 against the live sources.
- Editing a `CLAUDE.md` in a repo with a `.dopamine/config` produces an admission-test verdict beside the tool result; editing one in a repo without that file produces nothing.
- `skills/sweep/discovery-prompt.md` no longer contains the string `leave it unapplied`.
- `skills/sweep/SKILL.md` is byte-identical to its state at `0b39bef`.

## Deliberately out of scope

- **A `PreToolUse` block on `CLAUDE.md` edits.** The spec chooses `additionalContext` and says why: exit 2 frames an admission test as a blocking error, which it is not. Escalation stays available and unspent.
- **Applying the guard to nested or user-scope `CLAUDE.md` files.** The tier is whatever `.dopamine/config` declares. A project wanting `~/.claude/CLAUDE.md` guarded would need a path outside the repo, which the config format does not express, and no project has asked.
- **A consolidation pass over the lessons tier.** Rejected in spec §9.6: duplicates cost one extra grep hit, staleness costs nothing there, and the pass would be O(file) with almost nothing to buy.
- **Anything from slice 3.** `brainstorm-design`, `brainstorm-architecture`, `writing-roadmaps` and `adopting-a-repo` are a separate plan.
