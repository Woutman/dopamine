# Dopamine Slice 3 — the authoring skills — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give dopamine the four recipes that *create* the documents slices 1 and 2 maintain — `brainstorm-design`, `brainstorm-architecture`, `writing-roadmaps` and `adopting-a-repo` — so a project can be started or adopted by the plugin rather than by hand.

**Architecture:** Four skills, no new hooks and no new product scripts. Two of them wrap `superpowers:brainstorming` with a scope and derive a living document from the spec it produces; the third breaks that design and architecture into phases sized for one superpowers loop; the fourth is the brownfield entry point, which writes `.dopamine/config` and dispatches one survey subagent per absent document so the repository's contents never enter the controller's context. Every recipe reads its output path from `.dopamine/config` through the existing `artifact-paths`, and every one of them states its output as a table of required slots rather than as prose about what to avoid.

**Tech Stack:** bash 5.3.9, Python 3.14.4, git 2.53.0. No `jq`, no `shellcheck` — neither is installed and neither may be introduced as a dependency. This slice adds no runtime dependency of its own: it ships markdown and tests.

**Spec:** `docs/superpowers/specs/2026-08-28-dopamine-design.md` — slice 3 of §12. The sections that bind this plan are §6 (artifact model), §7 (layer model, phase sizing, the brainstorm-wrapper contract), §8 (components), §9.4 (the form guidance) and §10 (accepted risks, including the terminal-state hazard).

**Predecessors:** `docs/superpowers/plans/2026-08-28-dopamine-spine.md` with its sealed ledger `…-dopamine-spine.ledger.md`, and `docs/superpowers/plans/2026-08-28-dopamine-claude-md-guard.md`.

## Precondition — which commit this branches from

**Branch from `main` with slice 2 merged.** Check before creating the worktree:

```bash
git -C <repo> fetch origin && git -C <repo> log --oneline origin/main -1
```

- If `origin/main` contains slice 2 (PR #2, branch `dopamine-claude-md-guard`), branch from it. This is the intended base.
- If PR #2 has **not** merged, branch from `dopamine-claude-md-guard` instead and say so in the ledger. Do not branch from `0b39bef`: this plan edits `tests/skills/test-skill-structure.sh:22` and the README component table, which are the two lines slice 2 also rewrote, and branching from slice 1 guarantees a conflict in both.

---

## Measured facts this plan rests on

Measured 2026-08-28 in the slice-2 worktree, at `91fe9bd`. Stated once so no task re-derives them.

**Word counts here are body words**, the quantity `tests/skills/test-skill-structure.sh:80-81` actually measures: `awk '/^---$/ { seen++; next } seen >= 2'` piped to `wc -w`, which drops the frontmatter. A whole-file `wc -w` overstates a skill by roughly 36-40 words and is not the number any budget is checked against.

| Fact | Value |
|---|---|
| Suite baseline | **11 test files, 275 assertions, 0 failures** (`bash tests/run-tests.sh`) |
| `skills/artifact-map/SKILL.md` | **435** body words against a 500 budget (475 whole-file) |
| `skills/sweep/SKILL.md` | **699** body words against a 700 budget (737 whole-file) — one word of headroom |
| `skills/claude-md-guard/SKILL.md` | **432** body words against a 500 budget (468 whole-file) |
| `skills/sweep/discovery-prompt.md` | 863 words — no budget; only `SKILL.md` files are budgeted |
| `hooks/session-start-context.md` | 94 words, target under 200 |
| `BUDGETS` line | `tests/skills/test-skill-structure.sh:22` — `BUDGETS="artifact-map:500 sweep:700 claude-md-guard:500"` |

Two consequences, both load-bearing:

1. **A skill with no `BUDGETS` entry fails the suite.** `tests/skills/test-skill-structure.sh:83` fails `"$name: has a declared word budget"` when `budget_for` returns `0`. Every new skill directory must land with its budget in the same commit.
2. **An unused `BUDGETS` entry is inert.** `budget_for` is a lookup over a space-separated list; an entry naming a skill that does not exist yet is never matched and never asserted against. This is what lets Task 1 set the whole line once, so the four later tasks never touch a file slice 2 also rewrote.

Confirmed by reading the shipped code on the same date:

- `skills/sweep/scripts/artifact-paths` exits **3** with `no dopamine config at <path>` when `.dopamine/config` is absent, **2** on a malformed config, **0** otherwise, printing `<tier>\t<path>\t(present|absent)`. Valid tiers are exactly `living instructions lessons plans`.
- `tests/skills/test-skill-structure.sh:100` fails any skill containing an `@` preceded by line-start or whitespace and followed by `[a-zA-Z./]`. Write every cross-skill reference as `dopamine:<name>`, never as a path with an `@`.
- `tests/skills/test-skill-structure.sh:119-125` requires that every relative markdown link `[…](x.md)` and every backticked `` `*-prompt.md` `` in a `SKILL.md` resolve to a file **beside that SKILL.md**. A sibling prompt file must therefore be named `*-prompt.md` and must exist in the same commit that references it.
- `tests/skills/test-skill-structure.sh:74` fails a description matching `(then|,) *(dispatch|write|run|review)`. Descriptions state triggers only.

---

## Global Constraints

Every task's requirements implicitly include this section.

- **Nothing is ever written under `.superpowers/`.** Dopamine reads superpowers' artifacts and writes only its own (spec §5).
- **Every mechanism must be O(change), not O(project)** (spec §3), with exactly one sanctioned exception named in this slice: `adopting-a-repo`'s survey, which is O(project) once, at adoption, and must say so in its own text.
- **Guidance is written as positive recipe, not prohibition** (spec §9.4). The baseline failure being addressed is wrong-shaped output — documents that do get written, but come out accreted and narrative. `superpowers:writing-skills` reports that in head-to-head tests the prohibition arm produced *more* unwanted content than the no-guidance control. Say what the output IS, its parts, in order. Where a real exception exists, express it as a conditional on an observable predicate, never as a nuance clause appended to a rule.
- **The Iron Law of `superpowers:writing-skills` is waived** (spec §10): no baseline pressure scenarios are run. Skill tests are therefore **structural** — frontmatter valid, description a trigger rather than a workflow summary, referenced files exist, no `@`-link force-loads, word budget holds — plus content assertions that a named contract is present.
- **The plugin hard-codes no project's document set.** Every output path comes from `.dopamine/config` via `skills/sweep/scripts/artifact-paths`. A basename like `DESIGN.md` may be a **default** a recipe reaches for, never a requirement it enforces.
- **Nothing in this slice is heijmans-specific, or specific to any other project.** No example may name a real project's components, deployments or numbers.
- **Revise in place, never accrete.** A task that changes the README or the config comment deletes or rewrites what it supersedes rather than adding beside it.
- **Never invent a value that must be confirmed.** Every count, path and exit code in this plan was measured on 2026-08-28 and is reproduced verbatim; do not substitute a remembered one.
- **Tests are the gate.** `bash tests/run-tests.sh` must be green at the end of every task. The baseline is **11 files / 275 assertions**; that count may grow but must never fall.
- **Shell style, three ways:** `set -euo pipefail` for product scripts; `set -uo pipefail` (no `-e`) for test scripts, which exist to observe failures, tally them and exit non-zero on purpose; bare `set -u` for hook wrappers. This slice adds test scripts only.

---

## Design decisions this plan makes

These are rulings. Each is recorded here with its cost so a reviewer meets a decision rather than an oversight.

**1. `adopting-a-repo` covers greenfield too, not only brownfield.** Spec §8 describes it as *"Brownfield: reconstruct living documents from existing code"*, which leaves a gap: nothing writes `.dopamine/config` for a project with no code, and every other recipe needs the config to exist. Rather than invent a fifth skill or duplicate the config step into three recipes, `adopting-a-repo` owns "this repository has not adopted dopamine" in both cases, and branches on an observable predicate — *is there code here to read?* No code means adoption finishes at one file and points at `dopamine:brainstorm-design`. **Cost if wrong:** a skill whose name understates its scope; the description carries both triggers, so discovery still works.

**2. `artifact-paths` stays at `skills/sweep/scripts/artifact-paths`; the new skills reference it by that path.** It now serves five skills rather than one, which is an argument for promoting it to a plugin-level `scripts/`. Rejected: the move would touch a merged slice, `skills/sweep/SKILL.md`, `skills/sweep/scripts/sweep-package:39`, `skills/artifact-map/SKILL.md:24` and two test files, to save four skills a directory segment. Spec §8 also says scripts colocate with the skill they serve. **Cost if wrong:** four cross-skill path references that a later reorganisation must update; Task 5's chain test asserts they all spell the same path, so a rename breaks loudly.

**3. Which `living:` path is the design document is decided by basename, with a question as the fallback.** The config declares a flat `living:` tier and does not say which path plays which role. Each recipe takes the `living:` path whose basename matches the document it owns, and where no path matches, asks the human which declared path is meant rather than guessing or creating one. **Cost if wrong:** a project using different filenames pays one question per recipe, once. The escalation — a `role:` field in `.dopamine/config` — is recorded as a README known gap in Task 5, not built here.

**4. The `SessionStart` injection is not touched.** It is 94 always-loaded words whose subject is what happens *during* execution. The authoring skills are invoked deliberately, by name, at a project's start; a pointer to them would spend always-loaded context on something never discovered mid-session. **Cost if wrong:** an agent that does not know these skills exist must find them through their descriptions, which is the mechanism descriptions are for.

**5. Skill content assertions go in a new `tests/skills/test-authoring-skills.sh`, not in `test-skill-structure.sh`.** That file's own header calls it *"Structural tests for every skill in the plugin"*, and it is already 230 lines carrying three skills' content blocks. Four more would double it. The generic per-skill loop stays where it is — including the `BUDGETS` line, which Task 1 edits once. **Cost if wrong:** one more file in `tests/skills/`, which `run-tests.sh` discovers automatically.

**6. This slice does not derive dopamine's own `DESIGN.md` and `ARCHITECTURE.md`.** They are declared in `.dopamine/config` and absent, with a comment saying deriving them is a job for the plugin once it can do it. After this slice it can — but `brainstorm-design` stage 2 is an interactive brainstorm with a human, which is not something a plan task can execute. Task 5 revises that comment to point at the skill that now does the job. **Cost if wrong:** the two documents stay absent for one more session, reported by `artifact-paths` exactly as designed.

**7. Word budgets are ceilings set from slice 1 and 2 evidence, not targets.** A four-stage recipe with a subagent contract measured 737 words (`sweep`); a two-table reference measured 475 (`artifact-map`). The budgets below leave headroom above the drafts in this plan so a reviewer's addition does not require a budget change in the same breath — and, as `test-skill-structure.sh:17-21` already records, a budget calibrated against an incomplete draft is not evidence about a complete one. Coming in well under budget is a good outcome, never a reason to pad.

| Skill | Budget | Draft in this plan, measured | Headroom |
|---|---|---|---|
| `brainstorm-design` | 700 | 618 body words | 82 |
| `brainstorm-architecture` | 600 | 519 body words | 81 |
| `writing-roadmaps` | 750 | 670 body words | 80 |
| `adopting-a-repo` | 700 | 587 body words | 113 |

The drafts were measured, not estimated, and the budgets were then set above them. The alternative — fitting the budget to the draft — is how `sweep` reached **699 of 700**, which is why slice 2 could not add a sentence to it without first raising a number. A budget with no headroom converts every later correction into a second decision.

---

## File Structure

**Created:**

| Path | Responsibility |
|---|---|
| `skills/brainstorm-design/SKILL.md` | The wrapper contract in full, the system-scope framing, and `DESIGN.md`'s required slots |
| `skills/brainstorm-architecture/SKILL.md` | Assembly-scope framing and `ARCHITECTURE.md`'s required slots; points at the wrapper contract rather than restating it |
| `skills/writing-roadmaps/SKILL.md` | What a phase is, what orders phases, and `ROADMAP.md`'s required slots |
| `skills/adopting-a-repo/SKILL.md` | Writing the config, the code/no-code branch, the survey dispatch, and the read-versus-inferred contract |
| `skills/adopting-a-repo/survey-prompt.md` | What one survey subagent reads, how it separates read from inferred, and the findings file it returns |
| `tests/skills/test-authoring-skills.sh` | Content assertions for the four skills and the survey prompt |
| `tests/test-authoring-end-to-end.sh` | The chain between them: skill-name references resolve, the documented config executes, the two copies of it agree |

**Modified:**

| Path | Change |
|---|---|
| `tests/skills/test-skill-structure.sh:22` | `BUDGETS` gains all four entries, in one edit, in Task 1 |
| `README.md` | Component table gains four rows; Install points at the skill that writes the config; Known gaps gains the config-role gap; Status becomes complete |
| `.dopamine/config` | The header comment stops saying the derivation is impossible and names the skill that does it |
| `.claude-plugin/plugin.json` | Description and keywords cover authoring, not only sweeping |

**Deliberately NOT modified:** `hooks/session-start-context.md` (ruling 4), `skills/sweep/*` and `skills/claude-md-guard/*` (this slice adds no stage to the sweep and no destination to the guard), `skills/sweep/scripts/artifact-paths` (ruling 2), `hooks/hooks.json` (no new hook).

---

## Task order and parallelism

`1 → 2 → 3 → 4 → 5`, strictly sequential. Tasks 1-4 each append a section to `tests/skills/test-authoring-skills.sh`, and Tasks 2-4 each reference a skill name Task 1 established, so there is no parallel pair worth the worktree. Task 1 carries the shared edits — the `BUDGETS` line and the new test file's scaffold — so that only one task in this slice touches a file slice 2 also rewrote.

---

## Task 1: `brainstorm-design`

**Files:**
- Create: `skills/brainstorm-design/SKILL.md`
- Create: `tests/skills/test-authoring-skills.sh`
- Modify: `tests/skills/test-skill-structure.sh:22`

**Interfaces:**
- Consumes: `skills/sweep/scripts/artifact-paths` (exit 0 rows, exit 3 no config); the `dopamine:artifact-map` skill by name; `superpowers:brainstorming`.
- Produces: the skill name `dopamine:brainstorm-design`, referenced by all three later skills. The wrapper contract — inner-brainstorm scoping, the terminal-state resolution, spec-versus-living-document — lives here in full and is pointed at, not restated, by Task 2. `tests/skills/test-authoring-skills.sh` with `helpers.sh` sourced and `finish` last; later tasks insert their sections **before** the `finish` call.

**What this task is really solving.** Spec §10 names a drafting hazard: `superpowers:brainstorming`'s architectural path hard-terminates in *"the ONLY skill you invoke after brainstorming is writing-plans — never … any other implementation skill."* A project-scope brainstorm must not jump to an implementation plan. The resolution is not to contradict superpowers but to observe that its rule is about what follows a *finished* brainstorm: this one is not finished, because the wrapper is still running, and the project's implementation does still arrive through `writing-plans` — once per roadmap phase. Word it that way and the two skills agree.

- [ ] **Step 1: Write the failing test**

Create `tests/skills/test-authoring-skills.sh`:

```bash
#!/usr/bin/env bash
# Content assertions for slice 3's authoring skills.
#
# tests/skills/test-skill-structure.sh checks what every skill must have:
# valid frontmatter, a trigger-shaped description, a word budget, no @-link
# force-loads, resolvable references. This file checks what these four must
# SAY — the contracts a reader would lose if the text drifted while every
# structural check still passed.
#
# The Iron Law of superpowers:writing-skills is waived for this plugin
# (spec section 10), so nothing here is a pressure scenario.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

read_skill() {
    local name="$1" path="$REPO_ROOT/skills/$1/SKILL.md"
    if [ -f "$path" ]; then
        cat "$path"
    else
        fail "skills/$name/SKILL.md exists" "not found"
    fi
}

echo "-- brainstorm-design"
body=$(read_skill brainstorm-design)
assert_contains "it wraps superpowers' brainstorming rather than replacing it" \
    "$body" "superpowers:brainstorming"
assert_contains "it resolves the terminal-state clash with writing-plans" \
    "$body" "writing-plans"
assert_contains "it says the implementation still arrives one phase at a time" \
    "$body" "one roadmap phase at a time"
assert_contains "the spec survives the derivation rather than being superseded" \
    "$body" "frozen"
assert_contains "it reads its output path from the config" "$body" "artifact-paths"
assert_contains "an unadopted repository is routed, not guessed at" \
    "$body" "dopamine:adopting-a-repo"
assert_contains "it points at the artifact map rather than restating it" \
    "$body" "dopamine:artifact-map"
assert_contains "the document has a non-goals slot" "$body" "Not this"
assert_contains "the document has an open-questions slot" "$body" "Open questions"
assert_contains "it names the successor that answers what it defers" \
    "$body" "dopamine:brainstorm-architecture"

finish
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/skills/test-authoring-skills.sh`
Expected: FAIL — `[FAIL] skills/brainstorm-design/SKILL.md exists` followed by ten `[FAIL]` lines whose `in:` field is empty, then `11 failure(s)`.

- [ ] **Step 3: Add the budgets, all four at once**

`tests/skills/test-skill-structure.sh:22` currently reads:

```bash
BUDGETS="artifact-map:500 sweep:700 claude-md-guard:500"
```

Replace that single line with:

```bash
BUDGETS="artifact-map:500 sweep:700 claude-md-guard:500
         brainstorm-design:700 brainstorm-architecture:600
         writing-roadmaps:750 adopting-a-repo:700"
```

`budget_for` iterates `for entry in $BUDGETS`, unquoted, so newlines and leading spaces are word separators exactly as spaces are. Verify that before moving on:

```bash
bash -c 'B="a:1
   b:2"; for e in $B; do echo "[$e]"; done'
```
Expected: `[a:1]` then `[b:2]` — two entries, no whitespace inside either.

Leave the existing comment at lines 16-21 in place: it explains the `sweep` raise and is still true.

- [ ] **Step 4: Write the skill**

Create `skills/brainstorm-design/SKILL.md`:

```markdown
---
name: brainstorm-design
description: Use when a new project is starting, when a system has no DESIGN.md, or when what the project is for has changed enough that its design document no longer describes it
---

# Brainstorm a design

## Overview

A project-scope brainstorm, and the living document derived from what it produces.

`superpowers:brainstorming` is the engine — it asks the questions, proposes approaches and writes a dated spec. This recipe supplies the scope, and then does the part superpowers does not: turn that spec into `DESIGN.md`, a document that describes the **present** and is maintained by the sweep.

The spec is not superseded by it. A spec is dated intent, frozen at its date, never swept. `DESIGN.md` diverges from it as the project moves, exactly as shipped code diverges from the plan that built it.

**REQUIRED BACKGROUND:** Use dopamine:artifact-map — it decides what belongs in a living document and what is paid for on every read without earning it.

## The recipe

### 1. Locate the output

Run `skills/sweep/scripts/artifact-paths --tier living`. The design document is the declared path whose basename is `DESIGN.md`, present or absent. Where no declared path matches, ask which one is meant rather than creating a second.

Exit 3 means this repository has not adopted dopamine. Use dopamine:adopting-a-repo first — it writes the config, and where there is already code it reconstructs rather than brainstorms.

### 2. Brainstorm at system scope

Invoke `superpowers:brainstorming`. Its classification is **architectural**: a new project is never bounded, because bounded measures whether the flow being changed is already in the repository to read.

Supply the scope so its questions land at the right level — **what the system is for, who it serves, what it must do, what would make it a failure, and what it deliberately will not do.** Components are not this conversation; they are `dopamine:brainstorm-architecture`, and they are unanswerable until this one settles.

That skill ends by directing you to `superpowers:writing-plans` and no other skill. This recipe is still running — you are inside stage 2 of four — and its rule is kept where it applies: this project's implementation still arrives through `writing-plans`, one roadmap phase at a time.

### 3. Derive the document

`DESIGN.md` is the spec re-cast in the present tense, holding only what stays true as the project moves. Its slots, in order:

| Slot | Holds |
|---|---|
| **What this is** | One paragraph: what the system does, and for whom |
| **The problem** | What is wrong without it, measured wherever a number exists |
| **What it must do** | The requirements that decide whether it works |
| **The shape of the solution** | The approach taken, and the one or two rejected with the reason each was rejected |
| **Principles** | The constraints that override an agent's defaults on this project |
| **Not this** | What it deliberately does not do, so it is not proposed again |
| **Open questions** | What is unsettled, and who settles it |

The questions asked, the approaches surveyed and the record of who decided what stay in the spec. They are the dated account of one conversation; this document is the state of the system.

### 4. Name what is now pending

`ARCHITECTURE.md` is declared in the config and absent. Say so in one line and stop. It is dopamine:brainstorm-architecture's output, and it comes after this one because component boundaries follow from what the system is for.

## Outcomes

| At the end of stage 2 | This recipe produces |
|---|---|
| A spec at project scope | `DESIGN.md` at the declared path, and the spec left untouched |
| A design the human has not approved | Nothing written — the brainstorm has not finished |
| A `DESIGN.md` that already exists | Its slots revised in place: changed what changed, appended only what is genuinely new |
```

- [ ] **Step 5: Run both test files to verify they pass**

Run: `bash tests/skills/test-authoring-skills.sh && bash tests/skills/test-skill-structure.sh`
Expected: PASS on both. The structure file now reports `-- brainstorm-design` with its budget line reading `within its 700-word budget (N words)`. The draft in Step 4 measures **618** body words; a materially different N means the text was not transcribed as written.

- [ ] **Step 6: Run the full suite**

Run: `bash tests/run-tests.sh`
Expected: `all 12 test file(s) passed`.

- [ ] **Step 7: Commit**

```bash
git add skills/brainstorm-design/SKILL.md tests/skills/test-authoring-skills.sh tests/skills/test-skill-structure.sh
git commit -m "feat: brainstorm-design, the project-scope wrapper and DESIGN.md's slots"
```

---

## Task 2: `brainstorm-architecture`

**Files:**
- Create: `skills/brainstorm-architecture/SKILL.md`
- Modify: `tests/skills/test-authoring-skills.sh` — insert a section before `finish`

**Interfaces:**
- Consumes: `dopamine:brainstorm-design` as REQUIRED BACKGROUND for the wrapper contract; `skills/sweep/scripts/artifact-paths`; the `dopamine:artifact-map` tiers.
- Produces: the skill name `dopamine:brainstorm-architecture`, referenced by Tasks 3 and 4 and already referenced by Task 1's stage 4.

**Why this skill is shorter than Task 1's.** The two wrappers share their mechanical half: how the inner brainstorm is scoped, why its terminal instruction does not end the outer recipe, and how a living document relates to the spec. Restating that here would be the accretion this plugin exists to prevent, and a shared reference file for four sentences costs more to read than it saves. It is pointed at instead — and the pointer is doubly true, because `DESIGN.md` really does have to exist before this runs.

- [ ] **Step 1: Write the failing test**

Insert into `tests/skills/test-authoring-skills.sh`, immediately before the `finish` line:

```bash
echo "-- brainstorm-architecture"
body=$(read_skill brainstorm-architecture)
assert_contains "it points at the wrapper contract instead of restating it" \
    "$body" "dopamine:brainstorm-design"
assert_contains "the design document is its input" "$body" "DESIGN.md"
assert_contains "it reads its output path from the config" "$body" "artifact-paths"
assert_contains "the document says where state lives" "$body" "Where state lives"
assert_contains "the document says what failure looks like from outside" \
    "$body" "When it fails"
assert_contains "the document records the assemblies rejected" "$body" "Not this"
assert_contains "a number describing a run is cited, not copied in" \
    "$body" "sealed ledger"
assert_contains "it names the successor that orders the work" \
    "$body" "dopamine:writing-roadmaps"
assert_contains "a wrong requirement is a finding for the design, not a quiet re-decision" \
    "$body" "not something this brainstorm quietly redecides"
assert_contains "it points at the artifact map rather than restating it" \
    "$body" "dopamine:artifact-map"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/skills/test-authoring-skills.sh`
Expected: FAIL — `[FAIL] skills/brainstorm-architecture/SKILL.md exists` and ten empty-haystack failures; `11 failure(s)`. Task 1's ten assertions still pass above them.

- [ ] **Step 3: Write the skill**

Create `skills/brainstorm-architecture/SKILL.md`:

```markdown
---
name: brainstorm-architecture
description: Use when a design is settled and the components that realise it are not yet decided, when a system has no ARCHITECTURE.md, or when the assembly has changed enough that the document no longer matches the code
---

# Brainstorm an architecture

## Overview

The same wrapper as dopamine:brainstorm-design, one level down: it brainstorms **the assembly** and derives `ARCHITECTURE.md`.

**REQUIRED BACKGROUND:** Use dopamine:brainstorm-design — it holds the wrapper contract this recipe shares: how the inner brainstorm is scoped, why that skill's closing instruction does not end this one, and how a living document relates to the frozen spec it came from.

**REQUIRED BACKGROUND:** Use dopamine:artifact-map — it decides which numbers this document holds and which it cites from somewhere else.

The order is technical, not stylistic. Component boundaries follow from what the system is for, so `DESIGN.md` exists before this runs.

## The recipe

### 1. Locate the input and the output

`skills/sweep/scripts/artifact-paths --tier living` gives both. The architecture document is the declared path whose basename is `ARCHITECTURE.md`; `DESIGN.md` beside it is this brainstorm's input. Where no declared path matches either name, ask which is meant rather than creating a second.

An absent `DESIGN.md` stops this recipe: run dopamine:brainstorm-design and come back.

### 2. Brainstorm at assembly scope

Invoke `superpowers:brainstorming`, classification **architectural**, and supply the scope: **what the pieces are, what each one owns, how they talk to each other, where state lives, what happens when one of them fails, and what runs where.**

The design's requirements are the givens. A requirement that turns out to be wrong is a finding for `DESIGN.md` — take it back there and settle it, which is not something this brainstorm quietly redecides on its way past.

### 3. Derive the document

| Slot | Holds |
|---|---|
| **The assembly** | Each component in one line: what it owns, and what it must never own |
| **How they talk** | The interface between each pair, and which way the dependency points |
| **Where state lives** | Every store, and which component is authoritative for what in it |
| **When it fails** | What each failure looks like from outside, and what is retried, dropped or surfaced |
| **What runs where** | Processes, jobs, and the boundaries a deployment has to respect |
| **Not this** | Assemblies considered and rejected, with the reason each was rejected |

A number that describes the system now — a size limit, a timeout, a budget — belongs here as a bounded set, replaced when it changes. A number that describes one run belongs in the sealed ledger and is cited from here rather than copied into it.

### 4. Name what is now pending

`ROADMAP.md` is declared and absent. Say so in one line. It is dopamine:writing-roadmaps' output, and phase order is a question about technical dependency that only this document makes answerable.

## Outcomes

| At the end of stage 2 | This recipe produces |
|---|---|
| A settled assembly | `ARCHITECTURE.md` at the declared path, and the spec left untouched |
| A component the human wants to defer | The rest of the assembly, and the deferral as an open question naming what closes it |
| An `ARCHITECTURE.md` that already exists | Its slots revised in place against what the code now does |
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/skills/test-authoring-skills.sh && bash tests/skills/test-skill-structure.sh`
Expected: PASS on both; the structure file reports `brainstorm-architecture: within its 600-word budget (N words)`. The draft measures **519** body words.

- [ ] **Step 5: Run the full suite**

Run: `bash tests/run-tests.sh`
Expected: `all 12 test file(s) passed`.

- [ ] **Step 6: Commit**

```bash
git add skills/brainstorm-architecture/SKILL.md tests/skills/test-authoring-skills.sh
git commit -m "feat: brainstorm-architecture, the assembly-scope wrapper and ARCHITECTURE.md's slots"
```

---

## Task 3: `writing-roadmaps`

**Files:**
- Create: `skills/writing-roadmaps/SKILL.md`
- Modify: `tests/skills/test-authoring-skills.sh` — insert a section before `finish`

**Interfaces:**
- Consumes: both living documents by name; `skills/sweep/scripts/artifact-paths`; `dopamine:artifact-map`.
- Produces: the skill name `dopamine:writing-roadmaps`, already referenced by Task 2's stage 4 and referenced again by Task 4.

**The definition this task must carry, verbatim from spec §7.** `writing-plans` defines a task as *"the smallest unit that carries its own test cycle and is worth a fresh reviewer's gate"* and requires each plan to *"produce working, testable software on its own."* By analogy, **a phase is the smallest unit that makes one good plan** — independently valuable, independently verifiable, with exit criteria that are observations rather than assertions. That analogy is the whole skill; everything else is its consequences.

- [ ] **Step 1: Write the failing test**

Insert into `tests/skills/test-authoring-skills.sh`, immediately before the `finish` line:

```bash
echo "-- writing-roadmaps"
body=$(read_skill writing-roadmaps)
assert_contains "a phase is defined by analogy to a superpowers plan" \
    "$body" "smallest unit that makes one good plan"
assert_contains "it names the loop a phase maps onto" "$body" "superpowers:writing-plans"
assert_contains "both living documents are its inputs" "$body" "ARCHITECTURE.md"
assert_contains "order comes from dependency and from risk" "$body" "Risk"
assert_contains "each phase says what exists at the end" "$body" "Lands"
assert_contains "each phase says why it sits where it does" "$body" "Why here"
assert_contains "an exit criterion is observed, not asserted" \
    "$body" "Observations, not assertions"
assert_contains "external asks are named with the phase that needs them" \
    "$body" "critical path"
assert_contains "a closed phase is deleted rather than struck through" "$body" "deleted"
assert_contains "dates are excluded as a metric that moves without the system" \
    "$body" "Dates and durations"
assert_contains "it points at the artifact map rather than restating it" \
    "$body" "dopamine:artifact-map"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/skills/test-authoring-skills.sh`
Expected: FAIL — `[FAIL] skills/writing-roadmaps/SKILL.md exists` and eleven empty-haystack failures; `12 failure(s)`.

- [ ] **Step 3: Write the skill**

Create `skills/writing-roadmaps/SKILL.md`:

```markdown
---
name: writing-roadmaps
description: Use when a design and an architecture are settled and the order of the work is not yet decided, when a project has no ROADMAP.md, or when a phase has closed and what remains needs re-ordering
---

# Writing roadmaps

## Overview

`superpowers:writing-plans` breaks a spec into **tasks** sized for one execution loop. This breaks a design and an architecture into **phases** sized for one superpowers loop — and the loop is the unit: each phase is one spec, one plan, one execution, one sweep.

**A phase is the smallest unit that makes one good plan.** `writing-plans` requires a plan to produce working, testable software on its own; a phase inherits that requirement whole — independently valuable, independently verifiable.

**REQUIRED BACKGROUND:** Use dopamine:artifact-map — `ROADMAP.md` is a living document, re-read and re-verified at every phase close, and what that costs decides what is allowed into it.

## The recipe

### 1. Read the two inputs

`skills/sweep/scripts/artifact-paths --tier living`. `DESIGN.md` says what must exist; `ARCHITECTURE.md` says what depends on what. With either absent the phases would be guesses — run dopamine:brainstorm-design and dopamine:brainstorm-architecture first.

### 2. Order by dependency and risk, and say which one placed each phase

Two forces set the order, and every phase's position is one or the other:

- **Dependency** — B cannot be built until A exists.
- **Risk** — A carries an unknown that invalidates later work if it turns out badly, so it is proven early and cheaply. A vertical slice that proves a pattern with a hello-world is the standard shape: finding the pattern broken there costs a day, and finding it later, inside a half-built component, costs a week and does not say which half is at fault.

An order set by neither is a preference, and a preference does not survive contact with a schedule.

### 3. Write the phases

Each phase, in this order:

| Slot | Holds |
|---|---|
| **Lands** | What exists at the end that did not exist at the start |
| **Why here** | The dependency it satisfies, or the risk it retires |
| **Exit** | Observations, not assertions — what someone runs, and what they then see |

An exit criterion is something that happens: a command that returns, a number that lands inside a band, a run that completes, a page that loads. "The module is finished" is not one, because nothing observes it and so nothing can close it.

### 4. Name what the project cannot do for itself

Anything the work waits on from outside — an access grant, an approval, a decision by another team — gets a row: what is being asked, which phase needs it, and why it belongs to them. Asked early it is off the critical path; asked late it is the critical path.

### 5. Keep it consumed, not accumulated

A closed phase is **deleted**. Its outcome moves to where that outcome belongs: what changed the system goes to `DESIGN.md` or `ARCHITECTURE.md`, what a run measured stays in the sealed ledger and is cited. The sweep does this at each phase close, and it is why a roadmap describes the remaining work rather than growing into a history of the project.

## Outcomes

| The inputs hold | This recipe produces |
|---|---|
| A settled design and architecture | `ROADMAP.md`: what drives the order, the phases, and the external asks |
| An architecture still open on one component | The phases up to that question, and the question named as what unblocks the rest |
| A phase that has just closed | It is deleted and its outcome placed, and the remaining order re-decided if what closed changed it |

## Common mistakes

- **Dates and durations.** They change without the system changing, which is exactly the metric the artifact model excludes. Sequence is by dependency; a phase becomes available when its predecessors' exits are met.
- **Implementation detail inside a phase.** A phase names what lands, not how. The how is the spec and the plan that phase produces when it starts.
- **A phase whose exit nobody can observe.** It never closes, so it stays in the document, and the document stops describing the present.
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/skills/test-authoring-skills.sh && bash tests/skills/test-skill-structure.sh`
Expected: PASS on both; `writing-roadmaps: within its 750-word budget (N words)`. The draft measures **670** body words.

- [ ] **Step 5: Run the full suite**

Run: `bash tests/run-tests.sh`
Expected: `all 12 test file(s) passed`.

- [ ] **Step 6: Commit**

```bash
git add skills/writing-roadmaps/SKILL.md tests/skills/test-authoring-skills.sh
git commit -m "feat: writing-roadmaps, phases sized for one superpowers loop"
```

---

## Task 4: `adopting-a-repo`

**Files:**
- Create: `skills/adopting-a-repo/SKILL.md`
- Create: `skills/adopting-a-repo/survey-prompt.md`
- Modify: `tests/skills/test-authoring-skills.sh` — insert a section before `finish`

**Interfaces:**
- Consumes: all three skills from Tasks 1-3 by name; `dopamine:claude-md-guard` for anything bound for the instructions tier; `skills/sweep/scripts/artifact-paths` for verification after writing the config.
- Produces: the skill name `dopamine:adopting-a-repo`, already referenced by Task 1's stage 1. The config block inside its `SKILL.md` becomes an executable fixture in Task 5, so it must be a fenced block containing exactly the six declaration lines and nothing else — no comments, no prose, no blank first line.

**Two things this task must get right.**

1. **The `*-prompt.md` naming is load-bearing.** `tests/skills/test-skill-structure.sh:124` checks backticked `` `*-prompt.md` `` references resolve beside the `SKILL.md`. A sibling named `survey.md` would be referenced without ever being checked; named `survey-prompt.md` it is. Both files land in the same commit.
2. **The config block is copied, and copies drift.** The same six lines appear in `README.md`. Task 5 asserts the two are byte-identical, so write this one to match the README's existing block exactly, including its order.

- [ ] **Step 1: Write the failing test**

Insert into `tests/skills/test-authoring-skills.sh`, immediately before the `finish` line:

```bash
echo "-- adopting-a-repo"
body=$(read_skill adopting-a-repo)
assert_contains "adoption is named as the one O(project) cost, paid once" \
    "$body" "O(project)"
assert_contains "everything after adoption is O(change)" "$body" "O(change)"
assert_contains "it writes the config that every other component reads" \
    "$body" ".dopamine/config"
assert_contains "it verifies the config it wrote" "$body" "artifact-paths"
assert_contains "the no-code branch routes to the brainstorm instead" \
    "$body" "dopamine:brainstorm-design"
assert_contains "the survey is dispatched, not read into this session" \
    "$body" "survey-prompt.md"
assert_contains "what the code states and what it implies are never mixed" \
    "$body" "Reconstructed, unconfirmed"
assert_contains "the reason a component exists is named as unreadable from code" \
    "$body" "Code carries what, not why"
assert_contains "an instructions-tier candidate goes through the admission test" \
    "$body" "dopamine:claude-md-guard"
assert_contains "it points at the artifact map rather than restating it" \
    "$body" "dopamine:artifact-map"

echo "-- adopting-a-repo survey prompt"
survey="$REPO_ROOT/skills/adopting-a-repo/survey-prompt.md"
if [ -f "$survey" ]; then
    sbody=$(cat "$survey")
    assert_contains "the prompt documents its placeholders" "$sbody" "Placeholders:"
    assert_contains "which document is being surveyed decides what is read" \
        "$sbody" "{DOCUMENT}"
    assert_contains "a read fact carries the path it was read at" "$sbody" "path:line"
    assert_contains "an inference is labelled as one" "$sbody" "Inferred"
    assert_contains "a question the code cannot answer is returned, not answered" \
        "$sbody" "Questions"
    assert_contains "what was not read is reported too" "$sbody" "Not surveyed"
    assert_contains "the survey returns a file rather than prose" \
        "$sbody" "{FINDINGS_PATH}"
else
    fail "skills/adopting-a-repo/survey-prompt.md exists" "not found"
fi
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/skills/test-authoring-skills.sh`
Expected: FAIL — `[FAIL] skills/adopting-a-repo/SKILL.md exists`, ten empty-haystack failures, and `[FAIL] skills/adopting-a-repo/survey-prompt.md exists`; `12 failure(s)`.

- [ ] **Step 3: Write the survey prompt**

Create `skills/adopting-a-repo/survey-prompt.md`:

```markdown
# Adoption survey prompt

Fill the placeholders and dispatch one subagent per absent living document.

**Placeholders:** `{DOCUMENT}` `{FINDINGS_PATH}` `{REPO_ROOT}`

---

You are surveying `{REPO_ROOT}` so that a living document can be written from what its code actually does, rather than from what anyone remembers about it.

The document being written is **`{DOCUMENT}`**. That is what decides which parts of the repository you read.

| The document | What you read | What you leave alone |
|---|---|---|
| A design document | Entry points, the README, the public interface, the earliest commit messages | Internal call graphs |
| An architecture document | Module boundaries, the imports between them, where state is written, deployment and job definitions | Business rationale |
| A roadmap | The unfinished: TODO markers, stubs, unimplemented branches, skipped tests, configuration nothing reads yet | Anything already working |

## The two kinds of finding, which are never mixed

- **Read** — a fact the code states. It carries the `path:line` you read it at. *"`src/sync/client.py:41` authenticates app-only, not delegated."*
- **Inferred** — a claim the code implies but does not state. It carries what you read and the step you took from it. *"Inferred: the sync is one-way. Read: no module writes back to the source — nothing matches `post|patch|put` under `src/sync/`."*

The reason a component exists rather than a simpler one is almost never in the code. Where you cannot tell, that is itself a finding: name the question, and leave it unanswered.

## Bounding the read

You are the one O(project) read this project ever pays for, and that is still not a licence to read everything.

Start from the structure — the directory layout, the package or build manifest, the entry points — and follow only what `{DOCUMENT}` needs. Ten files read closely beat a hundred skimmed. Where several modules do the same kind of thing, read one properly and check that the others match its shape.

## What you return

Write `{FINDINGS_PATH}`, and nothing else: no summary in conversation, no draft of the document itself. It has exactly these sections.

### Read

One row per fact: the claim, and the `path:line` it came from.

### Inferred

One row per inference: the claim, what it was read from, and how confident — high where one reading fits, low where two do.

### Questions

One row per thing the code cannot answer, phrased so that a human can answer it in a sentence.

### Not surveyed

What you deliberately did not read, and why. This is what tells the next reader whether a gap in the finished document is a gap in the repository or a gap in this survey.
```

- [ ] **Step 4: Write the skill**

Create `skills/adopting-a-repo/SKILL.md`:

````markdown
---
name: adopting-a-repo
description: Use when dopamine is installed on a repository that has no .dopamine/config, when a project with existing code has no living documents, or when the documents it does have were never derived from what the code actually does
---

# Adopting a repo

## Overview

Adoption is the one **O(project)** thing dopamine does, and it happens once. Everything after it is **O(change)**.

That is the trade being made: read the repository properly a single time, so that no sweep ever has to.

**REQUIRED BACKGROUND:** Use dopamine:artifact-map — adoption is a placement exercise before it is a writing one, and the map is what decides where each thing found goes.

## The recipe

### 1. Declare the map

Write `.dopamine/config` at the repository root. It is the opt-in: without it every dopamine mechanism stays inert.

```
living: docs/DESIGN.md
living: docs/ARCHITECTURE.md
living: docs/ROADMAP.md
instructions: CLAUDE.md
lessons: docs/LESSONS.md
plans: docs/superpowers/plans
```

Declare the paths this project will use, not only the ones it already has — a declared document that does not exist is reported `absent`, which is how the remaining work stays visible without any machinery to nag about it. Confirm the paths with the human before writing: this is the file every other component reads.

Verify with `skills/sweep/scripts/artifact-paths`. Exit 0, with one row per declared path, means adoption can go on.

### 2. Decide whether there is anything to reconstruct

The source tree answers it.

- **There is code** → continue at stage 3. What it does is recoverable; why it does it, partly.
- **There is no code yet** → adoption is finished at one file. Say so, and use dopamine:brainstorm-design: there is nothing to reconstruct, and the documents come from a brainstorm instead.

### 3. Survey — one subagent per document, dispatched in parallel

For each absent `living:` document, dispatch one subagent with `survey-prompt.md`, naming which document it is surveying for. They read disjoint parts of the repository — entry points and history for the design, module boundaries and data flow for the architecture, unfinished work for the roadmap — so there is no shared expensive read that one pass would save.

Each returns a findings file. The repository's contents never enter this session.

### 4. Write, and mark what was inferred

Fill each document's slots from its findings file, using the recipe that owns that document: dopamine:brainstorm-design, dopamine:brainstorm-architecture, dopamine:writing-roadmaps. Their slot tables are the shape; the findings file is the content.

**Code carries what, not why.** A component's responsibilities are readable. The reason it exists rather than something simpler is not. So every claim lands in one of two places:

- **Read from the code** — in the body of the document, stated plainly.
- **Inferred** — in a `## Reconstructed, unconfirmed` section at the end of that document, stated as the inference it is.

That section is the handoff. Walk it with the human, move what they confirm into the body, and delete the section when it empties. A reconstruction that does not separate the two is a document nobody can trust and everybody re-derives.

### 5. Place what is not a living document

A survey turns up gotchas, dated observations and always-loaded rules. Route them: a dated observation to the lessons tier, an always-loaded rule to `CLAUDE.md` only if it survives dopamine:claude-md-guard's admission test, and anything derivable by reading the code nowhere at all.

## Outcomes

| The repository holds | Adoption produces |
|---|---|
| Code and no living documents | The config, the documents, and one `Reconstructed, unconfirmed` section per document |
| Code and documents that have drifted | The config, and each document's slots checked against the survey rather than rewritten from it |
| No code yet | The config alone, and the handoff to dopamine:brainstorm-design |
````

- [ ] **Step 5: Verify the config block is exactly the README's**

Run:

```bash
awk '/^living: docs\/DESIGN.md$/,/^plans: docs\/superpowers\/plans$/' skills/adopting-a-repo/SKILL.md > /tmp/a.txt
awk '/^living: docs\/DESIGN.md$/,/^plans: docs\/superpowers\/plans$/' README.md > /tmp/b.txt
diff /tmp/a.txt /tmp/b.txt && echo IDENTICAL
```
Expected: `IDENTICAL`, with no diff output. If they differ, fix this file — the README's block is the one already shipped.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `bash tests/skills/test-authoring-skills.sh && bash tests/skills/test-skill-structure.sh`
Expected: PASS on both; `adopting-a-repo: within its 700-word budget (N words)` — the draft measures **587** body words — and `adopting-a-repo: every referenced file exists`.

- [ ] **Step 7: Run the full suite**

Run: `bash tests/run-tests.sh`
Expected: `all 12 test file(s) passed`.

- [ ] **Step 8: Commit**

```bash
git add skills/adopting-a-repo/ tests/skills/test-authoring-skills.sh
git commit -m "feat: adopting-a-repo, the brownfield entry point and its survey contract"
```

---

## Task 5: the chain test, and the documents that describe the plugin

**Files:**
- Create: `tests/test-authoring-end-to-end.sh`
- Modify: `README.md`, `.dopamine/config`, `.claude-plugin/plugin.json`

**Interfaces:**
- Consumes: every skill from Tasks 1-4, plus the three that shipped in slices 1 and 2.
- Produces: nothing later depends on. This is the last task of the slice.

**What this test is for, and what it is not.** Each earlier task checked one skill against its own contract. This one checks the chain *between* them — the thing every unit test passes while the shipped plugin points at nothing. Rename a skill directory and every content assertion above still passes, because they all read the file by its own path. Three chains are checked: every `dopamine:<name>` reference resolves to a skill that exists; the config block documented in two places is one config; and that config actually executes under `artifact-paths`.

- [ ] **Step 1: Write the failing test**

Create `tests/test-authoring-end-to-end.sh`:

```bash
#!/usr/bin/env bash
# The authoring skills, end to end, offline.
#
# Every unit test above reads one file by its own path, so all of them keep
# passing after a rename that leaves the plugin pointing at nothing. This one
# checks the chains between the files: that every dopamine:<name> reference
# resolves, that the ordered hand-off from design to architecture to roadmap is
# unbroken, and that the config block the documentation shows a human is a config
# artifact-paths can actually read.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

echo "-- every dopamine:<skill> reference resolves to a skill that exists"
unresolved=""
while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    [ -f "$REPO_ROOT/skills/$ref/SKILL.md" ] || unresolved="$unresolved $ref"
done < <(grep -rhoE 'dopamine:[a-z][a-z-]*' "$REPO_ROOT/skills" "$REPO_ROOT/hooks" "$REPO_ROOT/README.md" \
    | sed 's/^dopamine://' | sort -u)
if [ -z "$unresolved" ]; then
    pass "every dopamine:<skill> reference resolves"
else
    fail "every dopamine:<skill> reference resolves" "unresolved:$unresolved"
fi

echo "-- the authoring order is an unbroken chain"
design="$REPO_ROOT/skills/brainstorm-design/SKILL.md"
arch="$REPO_ROOT/skills/brainstorm-architecture/SKILL.md"
road="$REPO_ROOT/skills/writing-roadmaps/SKILL.md"
adopt="$REPO_ROOT/skills/adopting-a-repo/SKILL.md"
assert_contains "design hands off to architecture" \
    "$(cat "$design")" "dopamine:brainstorm-architecture"
assert_contains "architecture hands off to the roadmap" \
    "$(cat "$arch")" "dopamine:writing-roadmaps"
assert_contains "architecture names the design as its predecessor" \
    "$(cat "$arch")" "dopamine:brainstorm-design"
assert_contains "the roadmap names both of its inputs" \
    "$(cat "$road")" "dopamine:brainstorm-architecture"
assert_contains "adoption reaches every authoring recipe" \
    "$(cat "$adopt")" "dopamine:writing-roadmaps"

echo "-- every root-relative reference to artifact-paths points at the real script"
# The sweep names it `scripts/artifact-paths`, relative to itself; every other
# skill names it from the repository root. Only that second form is checkable
# here, and it is the one a rename or a move would break.
spellings=$(grep -rhoE 'skills/[A-Za-z0-9_/-]*artifact-paths' "$REPO_ROOT/skills" | sort -u)
assert_eq "one root-relative spelling, and it is the shipped path" \
    "skills/sweep/scripts/artifact-paths" "$spellings"
assert_eq "and that path is executable" "yes" \
    "$([ -x "$REPO_ROOT/skills/sweep/scripts/artifact-paths" ] && echo yes || echo no)"

echo "-- the documented config is one config, in both places that show it"
extract_config() {
    awk '/^living: docs\/DESIGN.md$/,/^plans: docs\/superpowers\/plans$/' "$1"
}
from_skill=$(extract_config "$adopt")
from_readme=$(extract_config "$REPO_ROOT/README.md")
assert_eq "the skill's config block is non-empty" "6" "$(printf '%s\n' "$from_skill" | grep -c ':')"
assert_eq "the skill and the README show the same config" "$from_readme" "$from_skill"

echo "-- that config is one artifact-paths can read"
repo="$TEST_ROOT/project"
mkdir -p "$repo/.dopamine"
git init -q "$repo" 2>/dev/null
printf '%s\n' "$from_skill" > "$repo/.dopamine/config"
rows=$("$REPO_ROOT/skills/sweep/scripts/artifact-paths" "$repo" 2>/dev/null)
rc=$?
assert_eq "artifact-paths accepts the documented config" "0" "$rc"
assert_eq "it declares six paths" "6" "$(printf '%s\n' "$rows" | grep -c .)"
assert_eq "three of them are the living tier" "3" \
    "$(printf '%s\n' "$rows" | grep -c '^living')"
assert_eq "and all of them are absent in a fresh repository" "6" \
    "$(printf '%s\n' "$rows" | grep -c 'absent$')"

echo "-- every living document a config declares has a recipe that authors it"
for pair in "DESIGN.md:brainstorm-design" \
            "ARCHITECTURE.md:brainstorm-architecture" \
            "ROADMAP.md:writing-roadmaps"; do
    doc="${pair%%:*}"; owner="${pair#*:}"
    assert_contains "$doc is named by the recipe that produces it" \
        "$(cat "$REPO_ROOT/skills/$owner/SKILL.md")" "$doc"
done

echo "-- an unadopted repository is routed rather than guessed at"
bare="$TEST_ROOT/bare"
mkdir -p "$bare"
assert_exit "artifact-paths exits 3 with no config" 3 \
    "$REPO_ROOT/skills/sweep/scripts/artifact-paths" "$bare"
assert_contains "and the recipe that meets that exit names the way out" \
    "$(cat "$design")" "dopamine:adopting-a-repo"

finish
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/test-authoring-end-to-end.sh`
Expected: FAIL on `the skill and the README show the same config` only if the README block differs, and PASS on everything else — Tasks 1-4 have already landed the skills. **If every assertion passes on the first run, that is the expected result**, and it is not a reason to weaken the test: its value is regression, and its RED phase was the four tasks above. Record which assertions passed immediately in the task report.

- [ ] **Step 3: Revise the README**

Three edits, each replacing text rather than adding beside it.

Replace the component table (currently `README.md:21-29`) so its rows read, in this order — the seven existing rows unchanged, with the four authoring skills inserted before `dopamine:claude-md-guard`:

```markdown
| Piece | What it does |
|---|---|
| `.dopamine/config` | Declares which paths hold which artifact tier. The plugin hard-codes no project's document set |
| `SessionStart` hook | ~94 words positioning dopamine relative to superpowers. Silent in a repo with no config |
| `PreToolUse` seal gate | Denies deleting an SDD workspace whose ledger is not sealed |
| `PostToolUse` guard | Fires when a file in the `instructions` tier is edited. Reports its length against the 200-line target and hands the admission test to the agent |
| `dopamine:adopting-a-repo` | Writes the config, surveys existing code, and reconstructs the living documents — marking what was inferred |
| `dopamine:brainstorm-design` | Wraps superpowers' brainstorming at system scope and derives `DESIGN.md` |
| `dopamine:brainstorm-architecture` | The same at assembly scope, deriving `ARCHITECTURE.md` |
| `dopamine:writing-roadmaps` | Breaks the two into phases sized for one superpowers loop, producing `ROADMAP.md` |
| `dopamine:claude-md-guard` | The admission test, the routing table for what fails it, and the vendored standard behind both |
| `dopamine:sweep` | Seal → discovery → execution → verification, each of the last three stages its own subagent |
| `dopamine:artifact-map` | Where each kind of fact belongs, and why only two tiers are ever re-verified |
```

Replace the sentence at `README.md:33` — currently *"Add this repository as a Claude Code plugin, then create `.dopamine/config` in the project you want it to work on:"* — with:

```markdown
Add this repository as a Claude Code plugin, then run `dopamine:adopting-a-repo` in the project you want it to work on. It writes `.dopamine/config` and, where there is already code, reconstructs the living documents from it. To adopt by hand instead, the config is six lines:
```

Leave the fenced config block below it exactly as it is — Task 4's copy was written to match it, and Step 1's test asserts they stay equal.

Add one row to Known gaps, after the existing last bullet:

```markdown
- **The `living:` tier does not say which path plays which role.** The authoring recipes take the declared path whose basename matches the document they own — `DESIGN.md` for `dopamine:brainstorm-design`, and so on — and ask the human where no path matches. A project using different filenames therefore answers one question per recipe, once. A `role:` field in the config is the escalation if that proves annoying.
```

Replace the Status section (currently `README.md:68-70`) with:

```markdown
## Status

All three slices are built: the spine, the `CLAUDE.md` guard, and the authoring skills. The design they implement is `docs/superpowers/specs/2026-08-28-dopamine-design.md`.

This repository has not yet run its own authoring recipes on itself: `docs/DESIGN.md` and `docs/ARCHITECTURE.md` are declared in `.dopamine/config` and reported absent, which is the mechanism working rather than a gap in it.
```

- [ ] **Step 4: Revise the config comment**

`.dopamine/config` currently opens with a comment saying deriving those documents "is a job for this plugin once it can do it." It can now. Replace the comment block — the lines above `living: docs/DESIGN.md` — with:

```
# dopamine's own artifact map.
#
# DESIGN.md and ARCHITECTURE.md are declared and do not exist yet. Deriving them
# is `dopamine:brainstorm-design` and `dopamine:brainstorm-architecture`, which
# need a brainstorm with a human and so have not been run here yet.
# `artifact-paths` reports them absent, which is how that stays visible without
# any nagging machinery.
```

Leave the six declaration lines untouched.

- [ ] **Step 5: Revise the plugin manifest**

`.claude-plugin/plugin.json`'s description covers only the sweep. Replace the `description` value with:

```json
  "description": "Documentation discipline for long-horizon work: authors a project's living documents, then seals superpowers' execution ledger and drains it back into them at a cost that tracks the change",
```

and replace the `keywords` array with:

```json
  "keywords": [
    "documentation",
    "skills",
    "long-horizon",
    "superpowers",
    "sweep",
    "roadmap",
    "architecture"
  ]
```

Verify the file still parses:

```bash
python3 -c 'import json; json.load(open(".claude-plugin/plugin.json")); print("valid")'
```
Expected: `valid`.

- [ ] **Step 6: Run the chain test and the full suite**

Run: `bash tests/test-authoring-end-to-end.sh && bash tests/run-tests.sh`
Expected: `OK` from the chain test, then `all 13 test file(s) passed`. Record the total assertion count from the run — it must be **above 275**, the slice-2 baseline.

- [ ] **Step 7: Commit**

```bash
git add tests/test-authoring-end-to-end.sh README.md .dopamine/config .claude-plugin/plugin.json
git commit -m "feat: chain test for the authoring skills, and the docs that describe them"
```

---

## What this plan deliberately does not do

Named here so a reviewer meets a decision rather than a gap.

- **It does not run dopamine's own brainstorms.** Ruling 6. `docs/DESIGN.md` and `docs/ARCHITECTURE.md` stay absent and reported.
- **It does not add a stage to the sweep.** A newly authored living document is drained by the sweep exactly like any other declared `living:` path; nothing in slice 1 needs to know how the document came to exist.
- **It does not add a destination to `dopamine:claude-md-guard`.** `adopting-a-repo` routes through the guard's existing table rather than extending it.
- **It does not touch the `SessionStart` injection.** Ruling 4.
- **It ships no new product script and no new hook.** Every path it needs already exists, and adding a script to compute what `artifact-paths` already prints would be the accretion this plugin is against.
