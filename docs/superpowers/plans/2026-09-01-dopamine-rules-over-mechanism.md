# Dopamine — rules over mechanism Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace dopamine's two Python hooks and its four-stage sweep subagent pipeline with skills that state the rules, deleting roughly 1,500 lines and leaving superpowers as the workhorse.

**Architecture:** Nothing in the artifact model changes. What changes is where the rules live: two hooks and three shell scripts are deleted, the four sweep prompt files collapse into one prose recipe with an exit gate, and the document schemas — today buried in three authoring skills and loaded only at document *creation* — move into per-document files that both the authoring skill and the sweep load. Three skills are renamed to satisfy superpowers' verb-first rule. `SessionStart` is the only surviving hook, so Python stops being a runtime dependency and the plugin becomes bash + git.

**Tech Stack:** bash, git, markdown. Python 3 is retained by the **test suite only** (JSON and frontmatter parsing in `tests/`), never by shipped code.

**Spec:** `docs/superpowers/specs/2026-09-01-dopamine-rules-over-mechanism-design.md`

## Global Constraints

- **The `plans:` tier is immutable and is not touched by this plan.** Most references to `artifact-map`, `claude-md-guard` and `dopamine:sweep` live in `docs/superpowers/plans/*.md`. A sealed plan records what was true on its date; renaming inside it would be this project's own violation. **The stale names there are correct and stay.** Every `grep`/`sed` in this plan is scoped to `skills/`, `hooks/`, `tests/`, `README.md`, `.claude-plugin/` and `.dopamine/` — never `docs/`.
- **`docs/superpowers/specs/` is immutable too.** Both spec files stay byte-identical.
- **Skill names are verb-first or gerund** (`superpowers:writing-skills`). Frontmatter `name` must equal the directory name.
- **Every skill `description` starts with `Use when`**, is under 500 characters, and states triggers only — never a workflow summary.
- **No `@`-links in skill bodies.** They force-load context. Use `dopamine:<skill-name>` for skills and relative markdown links for sibling files.
- **Cross-plugin file references use `${CLAUDE_PLUGIN_ROOT}`.** A skill runs with the *user's* repository as its working directory, so a plugin-relative path like `skills/foo/bar.md` does not resolve.
- **Guidance is stated as a positive template, never as a prohibition.** `writing-skills` measured prohibition-form guidance performing worse than a no-guidance control on shaping failures. Slot tables are the correct form.
- **The commit-message prefix stays `sweep:`** even though the skill is renamed, so `git log --grep='^sweep:'` keeps working across the rename.
- **The RED phase is waived** for skill authoring (spec §8, Ruling 1): validation is manual. The shell tests in `tests/` are structural and content assertions, not pressure scenarios — but they are still written **before** the change they check, and watched to fail.
- **`bash tests/run-tests.sh` must exit 0 at the end of every task**, not just at the end of the plan.
- **Renames use `git mv`**, so history follows the file.

---

## File Structure

**Deleted (13 files, ~1,500 lines):**

| Path | Lines | Why |
|---|---|---|
| `hooks/seal-gate` | 21 | Wrapper for the deleted gate |
| `hooks/seal_gate.py` | 158 | Sealing is one `cp` named in a skill |
| `hooks/claude-md-guard` | 13 | Wrapper for the deleted guard |
| `hooks/claude_md_guard.py` | 199 | Its routing table was always the payload, and that is a skill |
| `hooks/claude-md-guard-context.md` | 15 | The guard's injected text |
| `hooks/py-hook` | 44 | Interpreter probe with no Python hooks left to probe for |
| `skills/sweep/scripts/artifact-paths` | 87 | A six-line config does not need an 87-line parser when the consumer is an LLM |
| `skills/sweep/scripts/seal-ledger` | 73 | Replaced by one `cp` |
| `skills/sweep/scripts/sweep-package` | 89 | Verification is now a self-review checklist on the diff |
| `skills/sweep/discovery-prompt.md` | 72 | No handoff, so no handoff brief |
| `skills/sweep/implementer-prompt.md` | 27 | Same |
| `skills/sweep/verifier-prompt.md` | 47 | Two of its three verdicts policed pipeline seams; the third becomes the exit gate |
| `tests/hooks/test-seal-gate.sh` | 124 | Subject deleted |
| `tests/hooks/test-claude-md-guard.sh` | 197 | Subject deleted |
| `tests/scripts/test-artifact-paths.sh` | 114 | Subject deleted |
| `tests/scripts/test-seal-ledger.sh` | 129 | Subject deleted |
| `tests/scripts/test-sweep-package.sh` | 95 | Subject deleted |

**Created (5 files):**

| Path | Responsibility |
|---|---|
| `skills/writing-living-documents/SKILL.md` | General rules for writing into a living document; pointers to the three schemas |
| `skills/writing-living-documents/design-schema.md` | `DESIGN.md`'s slots |
| `skills/writing-living-documents/architecture-schema.md` | `ARCHITECTURE.md`'s slots |
| `skills/writing-living-documents/roadmap-schema.md` | `ROADMAP.md`'s slots, and a phase's three |
| `tests/skills/test-living-documents.sh` | Content assertions for the new skill and its three schemas |

**Renamed (3 skills):**

| From | To |
|---|---|
| `skills/artifact-map/` | `skills/routing-documentation-updates/` |
| `skills/claude-md-guard/` | `skills/writing-claude-md/` |
| `skills/sweep/` | `skills/finishing-work/` |

**Modified:** `hooks/hooks.json`, `hooks/session-start-context.md`, `.dopamine/config`, `.claude-plugin/plugin.json`, `README.md`, the four authoring `SKILL.md` files, `skills/writing-claude-md/claude-md-best-practices.md`, and eight test files.

**Survives untouched:** `hooks/session-start`, `hooks/run-hook.cmd` (still the registered entry point for `SessionStart`), `skills/writing-claude-md/scripts/refresh-rule-card`, `skills/writing-claude-md/sources/`, `skills/adopting-a-repo/survey-prompt.md`, `tests/helpers.sh`, `tests/run-tests.sh`.

**Task order and why:** hooks first (self-contained, unblocks the Python-dependency claim); then the two renames (so the new `finishing-work` recipe can reference the new names); then the schemas; then the `artifact-paths` prose replacement (so its deletion in Task 6 breaks nothing); then the sweep replacement; then the three documents that describe all of it.

---

### Task 1: Retire the two Python hooks

**Files:**
- Delete: `hooks/seal-gate`, `hooks/seal_gate.py`, `hooks/claude-md-guard`, `hooks/claude_md_guard.py`, `hooks/claude-md-guard-context.md`, `hooks/py-hook`
- Delete: `tests/hooks/test-seal-gate.sh`, `tests/hooks/test-claude-md-guard.sh`
- Modify: `hooks/hooks.json` (all 44 lines → SessionStart only)
- Modify: `tests/test-guard-end-to-end.sh:20-54` (the PostToolUse invocation) and `:120-125` (the hook-event assertion)
- Modify: `tests/test-spine-end-to-end.sh:16` and `:54-80` (the gate)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: a `hooks/` directory containing exactly `session-start`, `session-start-context.md` and `run-hook.cmd`. Later tasks assume `hooks.json` registers `SessionStart` only.

- [ ] **Step 1: Write the failing assertion — only SessionStart is registered**

In `tests/test-guard-end-to-end.sh`, replace the final block (currently lines 120–125):

```bash
echo "-- SessionStart is the only hook event left"
events=$(python3 -c "
import json
print(','.join(sorted(json.load(open('$REPO_ROOT/hooks/hooks.json'))['hooks'])))")
assert_eq "SessionStart, and nothing that fires on every tool call" \
    "SessionStart" "$events"

echo "-- no hook shells out to a Python interpreter"
if [ -e "$REPO_ROOT/hooks/py-hook" ]; then
    fail "py-hook is gone, so Python is not a runtime dependency" "hooks/py-hook still exists"
else
    pass "py-hook is gone, so Python is not a runtime dependency"
fi
leftover=$(find "$REPO_ROOT/hooks" -name '*.py' | sed "s|$REPO_ROOT/||")
assert_eq "no Python hook scripts remain" "" "$leftover"
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bash tests/test-guard-end-to-end.sh`
Expected: FAIL — three failures, `expected: SessionStart / actual: PostToolUse,PreToolUse,SessionStart`, `hooks/py-hook still exists`, and two `.py` paths listed.

- [ ] **Step 3: Replace `hooks/hooks.json` with the SessionStart-only manifest**

Write the whole file:

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
    ]
  }
}
```

- [ ] **Step 4: Delete the hooks and their unit tests**

```bash
git rm hooks/seal-gate hooks/seal_gate.py \
       hooks/claude-md-guard hooks/claude_md_guard.py \
       hooks/claude-md-guard-context.md hooks/py-hook \
       tests/hooks/test-seal-gate.sh tests/hooks/test-claude-md-guard.sh
```

- [ ] **Step 5: Remove the guard invocation from `tests/test-guard-end-to-end.sh`**

Delete everything from `echo "-- a repository adopts dopamine, and an edit to its instructions file is met"` through `assert_contains "a verdict arrived" "$ctx" "make mistakes"` (currently lines 20–54) — the fixture repo, the `evt` event JSON, the hook invocation and the verdict assertion. Then replace the two assertions that referenced the deleted `$ctx` (currently lines 56–60) with:

```bash
echo "-- the chain of names holds"
assert_eq "the guard skill exists in the plugin" "yes" \
    "$([ -f "$GUARD_DIR/SKILL.md" ] && echo yes || echo no)"
```

`GUARD_DIR` is already defined at line 16 and is used by the card block below; reuse it rather than adding a second variable for the same path.

Also update the file's header comment: the chain it checks now starts at the skill, not at the hook. Replace the third and fourth comment lines with:

```bash
# Each unit test checks one component against its own contract. This one checks
# the chain of names between them: the skill links a card, the card names
# snapshots, and the extractor round-trips those snapshots. Rename any link in
# that chain and every unit test still passes while the shipped plugin points at
# nothing.
```

Leave the `-- the shipped card, extractor and snapshots agree` block and the `-- the sweep now gates promotions on the guard` block exactly as they are; Tasks 3 and 6 rewrite them.

- [ ] **Step 6: Remove the gate from `tests/test-spine-end-to-end.sh`**

Delete the `GATE=` line (currently line 16), the whole `gate_decision()` function (lines 54–63), and both gate blocks:

```bash
echo "-- before sealing"
assert_eq "the gate denies deleting an unsealed workspace" \
    "deny" "$(gate_decision "rm -rf .superpowers/sdd/2026-08-28-widget")"
```

and

```bash
echo "-- after sealing"
assert_eq "the same deletion now passes" \
    "none" "$(gate_decision "rm -rf .superpowers/sdd/2026-08-28-widget")"
```

The seal and package blocks stay — those scripts still exist until Task 6. Update the header comment's first line to `# The spine as one mechanism: config, seal, package.` and drop the clause `and that the gate's answer actually changes when it does` from the sentence that follows.

- [ ] **Step 7: Run the whole suite**

Run: `bash tests/run-tests.sh`
Expected: PASS — `all 12 test file(s) passed`.

- [ ] **Step 8: Commit**

```bash
git add -A hooks tests
git commit -m "refactor: delete the seal gate and the CLAUDE.md guard hooks

Sealing is one cp named in a skill; the guard's routing table was always
the payload, and that is a skill. With both gone py-hook has nothing to
probe for, so Python stops being a runtime dependency.

Spec: docs/superpowers/specs/2026-09-01-dopamine-rules-over-mechanism-design.md"
```

---

### Task 2: Rename `artifact-map` → `routing-documentation-updates`

**Files:**
- Rename: `skills/artifact-map/SKILL.md` → `skills/routing-documentation-updates/SKILL.md`
- Modify: `skills/routing-documentation-updates/SKILL.md` (frontmatter, title, the `artifact-paths` sentence, a new destination section)
- Modify: `skills/brainstorm-design/SKILL.md:16`, `skills/brainstorm-architecture/SKILL.md:14`, `skills/writing-roadmaps/SKILL.md:14`, `skills/adopting-a-repo/SKILL.md:14`, `skills/claude-md-guard/SKILL.md:17`, `skills/sweep/SKILL.md:14`, `skills/sweep/discovery-prompt.md:23,38`, `skills/sweep/verifier-prompt.md:9`
- Modify: `tests/skills/test-skill-structure.sh` (BUDGETS, and the `-- artifact-map content` block)
- Modify: `tests/skills/test-authoring-skills.sh` (five `dopamine:artifact-map` needles)

**Interfaces:**
- Consumes: `hooks.json` from Task 1 (untouched here).
- Produces: the skill name `dopamine:routing-documentation-updates`, referenced by every skill written in Tasks 4–6. `skills/artifact-map/` no longer exists.

- [ ] **Step 1: Write the failing assertions**

In `tests/skills/test-skill-structure.sh`, replace the `BUDGETS` block (currently lines 17–24, comment included) with:

```bash
# skill-name:max-words
# These are ratchets, not targets. A budget is raised only with a recorded reason.
# artifact-map was 500 and is raised to 600 here: it gains a paragraph describing
# the config format, which was an 87-line script the skill could point at instead.
# The four authoring skills keep the budgets they were merged with even though this
# change moves their slot tables out, so the headroom stays visible rather than spent.
BUDGETS="routing-documentation-updates:600 claude-md-guard:500 sweep:700
         brainstorm-design:700 brainstorm-architecture:600
         writing-roadmaps:850 adopting-a-repo:700"
```

Then replace the `-- artifact-map content` block (currently lines 137–148) with:

```bash
echo "-- routing-documentation-updates content"
map="$REPO_ROOT/skills/routing-documentation-updates/SKILL.md"
if [ -f "$map" ]; then
    body=$(cat "$map")
    for tier in Living Instructions Append-mostly Immutable Consumed; do
        assert_contains "the map names the $tier tier" "$body" "$tier"
    done
    assert_contains "the map says which tiers are verified" "$body" "verified"
    assert_contains "the map routes a number describing a run to the ledger" "$body" "sealed ledger"
    assert_contains "it describes the config format rather than naming a parser" \
        "$body" "tier: path"
    assert_contains "an unadopted repository is routed to adoption" \
        "$body" "dopamine:adopting-a-repo"
    assert_not_contains "no reference to the deleted parser survives" "$body" "artifact-paths"
else
    fail "skills/routing-documentation-updates/SKILL.md exists" "not found"
fi
```

In `tests/skills/test-authoring-skills.sh`, change all five occurrences of the needle `"dopamine:artifact-map"` to `"dopamine:routing-documentation-updates"`:

```bash
sed -i 's/dopamine:artifact-map/dopamine:routing-documentation-updates/g' \
    tests/skills/test-authoring-skills.sh
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `bash tests/skills/test-skill-structure.sh; bash tests/skills/test-authoring-skills.sh`
Expected: FAIL — `skills/routing-documentation-updates/SKILL.md exists / not found`, `artifact-map: has a declared word budget / add it to BUDGETS in this test`, and four `dopamine:routing-documentation-updates` needles missing from the authoring skills.

- [ ] **Step 3: Move the directory**

```bash
git mv skills/artifact-map skills/routing-documentation-updates
```

- [ ] **Step 4: Rewrite the skill's frontmatter, title and config sentence**

In `skills/routing-documentation-updates/SKILL.md`, set the frontmatter and heading:

```markdown
---
name: routing-documentation-updates
description: Use when deciding where a fact belongs — a lesson, a measured number, a decision, a constraint — or when a document is growing and it is not obvious which of them should hold what
---

# Routing documentation updates
```

Change the **Immutable** tier row to drop the deleted brief (`sweep briefs` no longer exist):

```markdown
| **Immutable** — intent and actuality | `specs/`, `plans/`, sealed ledgers | Never touched |
```

Replace the sentence that named the parser (currently line 24):

```markdown
This repository's own paths are declared in `.dopamine/config`, one `tier: path` per line. A declared path that does not exist is **absent**, not an error — that is how remaining work stays visible without machinery to nag about it. No `.dopamine/config` at all means the repository has not adopted dopamine: use dopamine:adopting-a-repo.
```

Then insert a new section immediately before `## Common mistakes`:

```markdown
## Once the destination is decided

- A living document → dopamine:writing-living-documents, which holds the slots each one has and the rules for writing into them.
- `CLAUDE.md` → dopamine:writing-claude-md, which holds the admission test.

Routing says which document. Those two say where inside it, and in what shape.
```

Leave `## The tiers`' remaining rows, `## Where each kind of fact goes` and `## Common mistakes` unchanged.

- [ ] **Step 5: Update every reference in shipped files**

```bash
grep -rl 'dopamine:artifact-map' skills hooks README.md \
  | xargs sed -i 's/dopamine:artifact-map/dopamine:routing-documentation-updates/g'
sed -i 's|skills/artifact-map/|skills/routing-documentation-updates/|g' README.md
```

The second `sed` catches `README.md:75`, a Known-gaps bullet that names the directory rather than the skill. Task 7 deletes that bullet outright; renaming it here keeps the grep below clean in the meantime.

Then fix the two prose mentions `sed` cannot see, because they do not carry the `dopamine:` prefix:

- `skills/sweep/discovery-prompt.md:38` — `**Tier** — the artifact-map tier the destination belongs to` becomes `**Tier** — the tier the destination belongs to, as dopamine:routing-documentation-updates defines it`.
- `README.md:33` — the table row `| `dopamine:artifact-map` | …` is already handled by the `sed` above; verify it now reads `` | `dopamine:routing-documentation-updates` | Where each kind of fact belongs, and why only two tiers are ever re-verified | ``.

Confirm nothing is left behind, outside the immutable `docs/` tree:

```bash
grep -rn 'artifact-map' skills hooks tests README.md .claude-plugin .dopamine
```

Expected: no output.

- [ ] **Step 6: Run the whole suite**

Run: `bash tests/run-tests.sh`
Expected: PASS — `all 12 test file(s) passed`. Note the reported word count for `routing-documentation-updates`; if it exceeds 600 the added section is too long, so tighten it rather than raise the budget.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor: rename artifact-map to routing-documentation-updates

superpowers:writing-skills requires active, verb-first names. The tier
table and the routing table are unchanged; the artifact-paths sentence
becomes a description of the config format.

References inside docs/superpowers/plans/ are deliberately not updated:
a sealed plan records what was true on its date."
```

---

### Task 3: Rename `claude-md-guard` → `writing-claude-md`

**Files:**
- Rename: `skills/claude-md-guard/` → `skills/writing-claude-md/` (SKILL.md, `claude-md-best-practices.md`, `scripts/refresh-rule-card`, `sources/*.md`)
- Modify: `skills/writing-claude-md/SKILL.md` (frontmatter, title, trigger list, verdict paragraph)
- Modify: `skills/writing-claude-md/claude-md-best-practices.md:3`
- Modify: `skills/adopting-a-repo/SKILL.md:61`, `skills/sweep/discovery-prompt.md:42,56`
- Modify: `tests/skills/test-skill-structure.sh` (BUDGETS key, and the `-- claude-md-guard content` block)
- Modify: `tests/skills/test-rule-card.sh:12,46,52,69`, `tests/scripts/test-refresh-rule-card.sh:9`
- Modify: `tests/test-guard-end-to-end.sh` (`GUARD_DIR`)
- Modify: `tests/skills/test-authoring-skills.sh:122`
- Modify: `README.md:31,63`

**Interfaces:**
- Consumes: `dopamine:routing-documentation-updates` from Task 2 (referenced in this skill's REQUIRED BACKGROUND, already rewritten by Task 2's `sed`).
- Produces: the skill name `dopamine:writing-claude-md`, referenced by Task 6's `finishing-work` and Task 7's session-start context. The path `skills/writing-claude-md/scripts/refresh-rule-card` for `README.md`.

- [ ] **Step 1: Write the failing assertions**

In `tests/skills/test-skill-structure.sh`, change the BUDGETS key `claude-md-guard:500` to `writing-claude-md:550`, appending its reason to the block comment:

```bash
# writing-claude-md was 500 and is raised to 550: nothing intercepts an edit to
# CLAUDE.md any more, so the skill has to say where its own trigger comes from
# and where the backstop is. Not licence to pad.
```

Then replace the `-- claude-md-guard content` block with:

```bash
echo "-- writing-claude-md content"
guard="$REPO_ROOT/skills/writing-claude-md/SKILL.md"
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
    assert_contains "it points at the routing skill rather than restating it" \
        "$body" "dopamine:routing-documentation-updates"
    assert_not_contains "it no longer claims a PostToolUse hook fires it" \
        "$body" "PostToolUse"
    assert_not_contains "a routed verdict is not parked in a brief that no longer exists" \
        "$body" "in the brief"
else
    fail "skills/writing-claude-md/SKILL.md exists" "not found"
fi
```

Update the four path prefixes in the two card tests and the one in the end-to-end test:

```bash
sed -i 's|skills/claude-md-guard|skills/writing-claude-md|g' \
    tests/skills/test-rule-card.sh \
    tests/scripts/test-refresh-rule-card.sh \
    tests/test-guard-end-to-end.sh
sed -i 's/dopamine:claude-md-guard/dopamine:writing-claude-md/g' \
    tests/skills/test-authoring-skills.sh \
    tests/test-guard-end-to-end.sh
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `bash tests/skills/test-skill-structure.sh; bash tests/skills/test-rule-card.sh; bash tests/test-guard-end-to-end.sh`
Expected: FAIL — `skills/writing-claude-md/SKILL.md exists / not found`, `claude-md-guard: has a declared word budget`, and the card test failing to find its card.

- [ ] **Step 3: Move the directory**

```bash
git mv skills/claude-md-guard skills/writing-claude-md
```

- [ ] **Step 4: Rewrite the skill's frontmatter, title, triggers and verdict paragraph**

In `skills/writing-claude-md/SKILL.md`:

```markdown
---
name: writing-claude-md
description: Use when a line is about to be added to CLAUDE.md, when work is finishing and something is being drained into it, or when a recurring lesson is proposed for promotion to an always-loaded line
---

# Writing CLAUDE.md
```

Replace the whole `## When the guard fires` section (currently lines 19–23) with:

```markdown
## When this fires

- **Before a line enters `CLAUDE.md`** — written by hand, or drained into it as work finishes.
- **On a promotion** — a lesson that has recurred, offered as an always-loaded line.

Nothing intercepts an edit to `CLAUDE.md` any more, so this skill is loaded because the writer reaches for it. dopamine:finishing-work's exit gate is the backstop: a promotion that reached the instructions tier without a verdict is a finding there.
```

Replace the closing paragraph of `## The verdict` (currently line 51) with:

```markdown
A routed verdict is reported when the work closes and then forgotten — re-litigating one costs a single lookup in the table above, and logging every one would grow the lessons tier, which nothing verifies and nothing prunes. A promotion that was **genuinely contested** is a ruling, and a ruling belongs in the sealed ledger with everything else the work decided.
```

Leave `## Overview`, `## The test` and `## Keeping the card honest` unchanged, except that Task 2's `sed` has already rewritten the REQUIRED BACKGROUND line to `**REQUIRED BACKGROUND:** Use dopamine:routing-documentation-updates — it holds the tier each destination below belongs to.`

- [ ] **Step 5: Update every reference in shipped files**

```bash
grep -rl 'dopamine:claude-md-guard' skills hooks README.md \
  | xargs sed -i 's/dopamine:claude-md-guard/dopamine:writing-claude-md/g'
sed -i 's|skills/claude-md-guard|skills/writing-claude-md|g' README.md
```

That covers `skills/writing-claude-md/claude-md-best-practices.md:3`, `skills/adopting-a-repo/SKILL.md:61`, `skills/sweep/discovery-prompt.md:42,56` and `README.md:31,63`. Confirm:

```bash
grep -rn 'claude-md-guard' skills hooks tests README.md .claude-plugin .dopamine
```

Expected: no output. (`claude-md-best-practices.md`, `claude_md_guard` and `test-claude-md-guard.sh` are all gone or unrelated — the first is a different string, the last two were deleted in Task 1.)

- [ ] **Step 6: Run the whole suite**

Run: `bash tests/run-tests.sh`
Expected: PASS — `all 12 test file(s) passed`.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor: rename claude-md-guard to writing-claude-md

Verb-first per superpowers:writing-skills, and the old name described a
hook that no longer exists. The admission test and the routing table are
unchanged; the trigger list drops PostToolUse and the verdict paragraph
stops pointing at the deleted sweep brief."
```

---

### Task 4: Add `writing-living-documents` and move the schemas into it

**Files:**
- Create: `skills/writing-living-documents/SKILL.md`
- Create: `skills/writing-living-documents/design-schema.md`
- Create: `skills/writing-living-documents/architecture-schema.md`
- Create: `skills/writing-living-documents/roadmap-schema.md`
- Create: `tests/skills/test-living-documents.sh`
- Modify: `skills/brainstorm-design/SKILL.md` (§3, lines 34–48)
- Modify: `skills/brainstorm-architecture/SKILL.md` (§3, lines 32–43)
- Modify: `skills/writing-roadmaps/SKILL.md` (§3, lines 31–41; §4's table row moves, its prose stays)
- Modify: `skills/adopting-a-repo/SKILL.md` (§4, line 50)
- Modify: `tests/skills/test-skill-structure.sh` (BUDGETS)
- Modify: `tests/skills/test-authoring-skills.sh` (slot assertions move to the schemas; new `${CLAUDE_PLUGIN_ROOT}` assertions)

**Interfaces:**
- Consumes: `dopamine:routing-documentation-updates` (Task 2) as its REQUIRED BACKGROUND.
- Produces: the skill name `dopamine:writing-living-documents` and three schema paths, spelled `${CLAUDE_PLUGIN_ROOT}/skills/writing-living-documents/<name>-schema.md`. Task 6's `finishing-work` and Task 7's session-start context both reference the skill by name.

- [ ] **Step 1: Write the failing test for the new skill and its schemas**

Create `tests/skills/test-living-documents.sh`:

```bash
#!/usr/bin/env bash
# Content assertions for the schema skill.
#
# tests/skills/test-skill-structure.sh checks what every skill must have. This
# file checks the thing that made the skill worth extracting: that each living
# document's slots exist in exactly one place, reachable from both consumers —
# the authoring recipe that creates the document, and dopamine:finishing-work,
# which edits it for the rest of the project's life.
#
# The Iron Law of superpowers:writing-skills is waived for this plugin
# (spec section 8), so nothing here is a pressure scenario.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

DIR="$REPO_ROOT/skills/writing-living-documents"

echo "-- the skill exists and links all three schemas"
if [ -f "$DIR/SKILL.md" ]; then
    pass "skills/writing-living-documents/SKILL.md exists"
    body=$(cat "$DIR/SKILL.md")
    assert_contains "it points at the routing skill for which document" \
        "$body" "dopamine:routing-documentation-updates"
    assert_contains "a document is a fixed set of slots" "$body" "slots"
    assert_contains "a change replaces what it makes wrong" "$body" "Change what changed"
    assert_contains "a run's number is cited from the ledger, not copied in" \
        "$body" "sealed ledger"
    for schema in design architecture roadmap; do
        assert_contains "SKILL.md links $schema-schema.md" "$body" "$schema-schema.md"
    done
else
    fail "skills/writing-living-documents/SKILL.md exists" "not found"
fi

echo "-- each schema names its own document's slots"
check_schema() {
    local file="$1"; shift
    if [ ! -f "$DIR/$file" ]; then
        fail "$file exists" "not found"
        return
    fi
    pass "$file exists"
    local sbody
    sbody=$(cat "$DIR/$file")
    local slot
    for slot in "$@"; do
        assert_contains "$file declares the '$slot' slot" "$sbody" "$slot"
    done
}

check_schema design-schema.md \
    "What this is" "The problem" "What it must do" \
    "The shape of the solution" "Principles" "Not this" "Open questions"
check_schema architecture-schema.md \
    "The assembly" "How they talk" "Where state lives" \
    "When it fails" "What runs where" "Not this"
check_schema roadmap-schema.md \
    "What drives the order" "The phases" "External asks" \
    "Lands" "Why here" "Exit" "Observations, not assertions"

echo "-- both consumers reach every schema through CLAUDE_PLUGIN_ROOT"
for pair in "brainstorm-design:design-schema.md" \
            "brainstorm-architecture:architecture-schema.md" \
            "writing-roadmaps:roadmap-schema.md"; do
    skill="${pair%%:*}"; schema="${pair#*:}"
    sbody=$(cat "$REPO_ROOT/skills/$skill/SKILL.md")
    assert_contains "$skill reaches its schema through the plugin root" \
        "$sbody" "\${CLAUDE_PLUGIN_ROOT}/skills/writing-living-documents/$schema"
    assert_contains "$skill names the skill that holds the writing rules" \
        "$sbody" "dopamine:writing-living-documents"
done
abody=$(cat "$REPO_ROOT/skills/adopting-a-repo/SKILL.md")
assert_contains "adoption reaches the schemas directly, not via the recipes" \
    "$abody" "\${CLAUDE_PLUGIN_ROOT}/skills/writing-living-documents/"
assert_contains "adoption names the skill that holds the writing rules" \
    "$abody" "dopamine:writing-living-documents"

echo "-- a slot table lives in exactly one place"
# The extraction only pays off if the tables did not stay behind. A slot header
# is unique enough to catch a copy: if it appears in an authoring skill as well
# as its schema, both are now maintained and one will drift.
for pair in "brainstorm-design:Open questions" \
            "brainstorm-architecture:Where state lives" \
            "writing-roadmaps:Observations, not assertions"; do
    skill="${pair%%:*}"; slot="${pair#*:}"
    assert_not_contains "$skill no longer carries the '$slot' slot itself" \
        "$(cat "$REPO_ROOT/skills/$skill/SKILL.md")" "$slot"
done

finish
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bash tests/skills/test-living-documents.sh`
Expected: FAIL — `skills/writing-living-documents/SKILL.md exists / not found`, all four schema-existence failures, and the three "no longer carries" assertions failing because the tables are still in the authoring skills.

- [ ] **Step 3: Write `skills/writing-living-documents/SKILL.md`**

```markdown
---
name: writing-living-documents
description: Use when about to write or edit DESIGN.md, ARCHITECTURE.md or ROADMAP.md — creating one, draining into one as work finishes, or reconstructing one during adoption
---

# Writing living documents

## Overview

A living document describes the **present**. It is re-read and re-verified every time a unit of work finishes, so everything it holds is paid for again at every close. That recurring cost is what decides its shape.

**REQUIRED BACKGROUND:** Use dopamine:routing-documentation-updates — it decides *which* document a fact belongs in. This skill decides *where inside it*, and in what shape.

## Each document is a fixed set of slots

A living document is a named set of slots, in a fixed order. Content going in claims one of them; content that claims none has a different home, and dopamine:routing-documentation-updates says where. That is what keeps these documents growing with the system rather than with the project.

| Document | Its slots |
|---|---|
| `DESIGN.md` | [design-schema.md](design-schema.md) |
| `ARCHITECTURE.md` | [architecture-schema.md](architecture-schema.md) |
| `ROADMAP.md` | [roadmap-schema.md](roadmap-schema.md) |

Read the schema for the document being written before writing to it. Each names its slots, what each one holds, and the order they appear in.

## Writing into a slot

- **Present tense.** The document states what is true now. What *was* true, and when it stopped being true, is the sealed ledger's job.
- **Change what changed.** Text that a change makes wrong is *replaced*. Appending the new statement beside the old leaves the document asserting both, and a reader cannot tell which is current.
- **A number describing the system now** — a current limit, a current gate — sits here as a bounded set, replaced when it changes. **A number describing one run** lives in the sealed ledger and is cited from here rather than copied in.
- **A rejected or superseded approach** goes in the slot that holds those, with the reason it was rejected, so it is not proposed again.
- **Rationale a spec already records** stays in the spec. A spec is dated intent, frozen at its date; this document is the state of the system, and it diverges from the spec as the project moves.

## Common mistakes

- **Filing design rationale here that a frozen spec already holds.** It reads perfectly well, and is then re-verified at every close while duplicating a document nothing re-reads.
- **Draining a run's measurement into the body.** It has to be defended at every close, and it drifts from the run that produced it.
- **Leaving the old sentence in place beside the new one.** Two plausible statements about the present is worse than one stale statement: a stale statement at least fails a check.
```

- [ ] **Step 4: Write `skills/writing-living-documents/design-schema.md`**

```markdown
# `DESIGN.md` — slots

What the system is for, in the present tense, holding only what stays true as the project moves.

| Slot | Holds |
|---|---|
| **What this is** | One paragraph: what the system does, and for whom |
| **The problem** | What is wrong without it, measured wherever a number exists |
| **What it must do** | The requirements that decide whether it works |
| **The shape of the solution** | The approach taken, and the one or two rejected with the reason each was rejected |
| **Principles** | The constraints that override an agent's defaults on this project |
| **Not this** | What it deliberately does not do, so it is not proposed again |
| **Open questions** | What is unsettled, and who settles it |

The questions asked, the approaches surveyed and the record of who decided what stay in the spec this document was derived from. They are the dated account of one conversation; this is the state of the system.

`ARCHITECTURE.md` takes **What it must do** as given. A requirement that turns out to be wrong is settled here, in this document, rather than worked around downstream.
```

- [ ] **Step 5: Write `skills/writing-living-documents/architecture-schema.md`**

```markdown
# `ARCHITECTURE.md` — slots

The assembly that realises `DESIGN.md`, in the present tense.

| Slot | Holds |
|---|---|
| **The assembly** | Each component in one line: what it owns, and what it must never own |
| **How they talk** | The interface between each pair, and which way the dependency points |
| **Where state lives** | Every store, and which component is authoritative for what in it |
| **When it fails** | What each failure looks like from outside, and what is retried, dropped or surfaced |
| **What runs where** | Processes, jobs, and the boundaries a deployment has to respect |
| **Not this** | Assemblies considered and rejected, with the reason each was rejected |

A number that describes the system now — a size limit, a timeout, a budget — belongs here as a bounded set, replaced when it changes. A number that describes one run belongs in the sealed ledger and is cited from here rather than copied into it.

Component boundaries follow from what the system is for, so a change here that contradicts `DESIGN.md` is a finding for `DESIGN.md` first.
```

- [ ] **Step 6: Write `skills/writing-living-documents/roadmap-schema.md`**

```markdown
# `ROADMAP.md` — slots

The order of the remaining work.

| Slot | Holds |
|---|---|
| **What drives the order** | Which of dependency or risk placed each phase, named per phase |
| **The phases** | One entry per phase, in order, each with the three slots below |
| **External asks** | Anything the work waits on from outside: what is being asked, which phase needs it, why it belongs to them |

Each phase, in this order:

| Slot | Holds |
|---|---|
| **Lands** | What exists at the end that did not exist at the start |
| **Why here** | The dependency it satisfies, or the risk it retires |
| **Exit** | Observations, not assertions — what someone runs, and what they then see |

An exit criterion is something that happens: a command that returns, a number that lands inside a band, a run that completes, a page that loads. "The module is finished" is not one, because nothing observes it and so nothing can close it.

Sequence comes from dependency, not from a date: a phase becomes available when its predecessors' exits are met.

A **closed** phase keeps its position, struck through, its body replaced by a pointer to its sealed ledger. That form, and the reason for it, are in dopamine:writing-roadmaps — the recipe that re-runs at each close.
```

- [ ] **Step 7: Replace `brainstorm-design` §3 with a schema pointer**

In `skills/brainstorm-design/SKILL.md`, replace the whole `### 3. Derive the document` section (currently lines 34–48, table included) with:

```markdown
### 3. Derive the document

`DESIGN.md` is the spec re-cast in the present tense, holding only what stays true as the project moves. Its slots are declared in `${CLAUDE_PLUGIN_ROOT}/skills/writing-living-documents/design-schema.md`.

Use dopamine:writing-living-documents. It holds that schema and the rules for writing into it, and it is the same skill every later edit to this document goes through — so the shape this stage creates is the shape the sweep maintains.
```

- [ ] **Step 8: Replace `brainstorm-architecture` §3 with a schema pointer**

In `skills/brainstorm-architecture/SKILL.md`, replace the whole `### 3. Derive the document` section (currently lines 32–43, table included) with:

```markdown
### 3. Derive the document

`ARCHITECTURE.md`'s slots are declared in `${CLAUDE_PLUGIN_ROOT}/skills/writing-living-documents/architecture-schema.md`.

Use dopamine:writing-living-documents. It holds that schema and the rules for writing into it — including which numbers this document states outright and which it cites from the sealed ledger instead.
```

- [ ] **Step 9: Replace `writing-roadmaps` §3 with a schema pointer**

In `skills/writing-roadmaps/SKILL.md`, replace the whole `### 3. Write the phases` section (currently lines 31–41, table included) with:

```markdown
### 3. Write the phases

The phase slots, and the document's own, are declared in `${CLAUDE_PLUGIN_ROOT}/skills/writing-living-documents/roadmap-schema.md`.

Use dopamine:writing-living-documents. It holds that schema and the rules for writing into it.
```

`### 4. Name what the project cannot do for itself` keeps its prose — the schema declares that **External asks** is a slot; this section argues why it is worth filling early. Trim only the words that restated the slot's contents, so §4 reads:

```markdown
### 4. Name what the project cannot do for itself

Anything the work waits on from outside — an access grant, an approval, a decision by another team — earns a row in **External asks**. Asked early it is off the critical path; asked late it is the critical path.
```

`### 5. Strike a closed phase` and `## Common mistakes` stay exactly as they are.

- [ ] **Step 10: Point `adopting-a-repo` §4 at the schemas directly**

In `skills/adopting-a-repo/SKILL.md`, replace the first paragraph of `### 4. Write, and mark what was inferred` (currently line 50) with:

```markdown
Fill each document's slots from its findings file. The slots are declared in `${CLAUDE_PLUGIN_ROOT}/skills/writing-living-documents/` — `design-schema.md`, `architecture-schema.md`, `roadmap-schema.md` — and dopamine:writing-living-documents holds the rules for writing into them. The schema is the shape; the findings file is the content.

Where a document needs more than filling in — an order that has to be argued, an assembly that has to be decided — that is dopamine:brainstorm-design, dopamine:brainstorm-architecture or dopamine:writing-roadmaps, and adoption hands off to it rather than guessing.
```

The rest of §4 (`**Code carries what, not why.**` onward) stays unchanged.

- [ ] **Step 11: Add the new skill's word budget**

In `tests/skills/test-skill-structure.sh`, add `writing-living-documents:600` to `BUDGETS`:

```bash
BUDGETS="routing-documentation-updates:600 writing-claude-md:550 sweep:700
         writing-living-documents:600
         brainstorm-design:700 brainstorm-architecture:600
         writing-roadmaps:850 adopting-a-repo:700"
```

- [ ] **Step 12: Move the slot assertions out of `test-authoring-skills.sh`**

The slot tables no longer live in the authoring skills, so the assertions that read them there must go — `tests/skills/test-living-documents.sh` now owns them. Delete these eight `assert_contains` calls (each spans two lines):

- `brainstorm-design`: `"the document has a non-goals slot" … "Not this"` and `"the document has an open-questions slot" … "Open questions"`
- `brainstorm-architecture`: `"the document says where state lives" … "Where state lives"`, `"the document says what failure looks like from outside" … "When it fails"`, `"the document records the assemblies rejected" … "Not this"`
- `writing-roadmaps`: `"each phase says what exists at the end" … "Lands"`, `"each phase says why it sits where it does" … "Why here"`, `"an exit criterion is observed, not asserted" … "Observations, not assertions"`

Then add one assertion per authoring skill, replacing what was lost — that it reaches its schema:

```bash
# after the brainstorm-design block
assert_contains "it hands the document's shape to the schema skill" \
    "$body" "design-schema.md"
```

```bash
# after the brainstorm-architecture block
assert_contains "it hands the document's shape to the schema skill" \
    "$body" "architecture-schema.md"
```

```bash
# after the writing-roadmaps block
assert_contains "it hands the phase shape to the schema skill" \
    "$body" "roadmap-schema.md"
```

Leave `brainstorm-architecture`'s `"sealed ledger"` assertion in place — the new §3 still says it. Leave `writing-roadmaps`' `"critical path"`, `"struck through"`, `"and nothing else"` and `"Dates and durations"` assertions in place: §4, §5 and Common Mistakes all survive.

- [ ] **Step 13: Run the whole suite**

Run: `bash tests/run-tests.sh`
Expected: PASS — `all 13 test file(s) passed`. The reported word counts for the three authoring skills should have dropped; note them, but do not lower the budgets in this task.

- [ ] **Step 14: Commit**

```bash
git add -A
git commit -m "feat: extract living-document schemas into their own skill

The slot tables were the anti-bloat mechanism and they loaded only at
document creation. They now have two consumers each: the authoring
recipe that creates the document, and the sweep that edits it for the
rest of the project's life.

One file per document rather than inline, so brainstorm-design does not
load all three schemas to reach the one it owns."
```

---

### Task 5: Replace the `artifact-paths` call sites with the config format in prose

**Files:**
- Modify: `skills/brainstorm-design/SKILL.md` §1 (lines 20–24)
- Modify: `skills/brainstorm-architecture/SKILL.md` §1 (lines 20–24)
- Modify: `skills/writing-roadmaps/SKILL.md` §1 (lines 18–20)
- Modify: `skills/adopting-a-repo/SKILL.md` §1 (line 33)
- Modify: `.dopamine/config` (the comment block)
- Modify: `tests/skills/test-authoring-skills.sh` (four `artifact-paths` needles)
- Modify: `tests/test-authoring-end-to-end.sh` (three blocks that exercise the script)

**Interfaces:**
- Consumes: `dopamine:routing-documentation-updates`'s config-format sentence from Task 2 — this task states the same three facts at each call site, in the same words, so a reader who has only one of them is not missing anything.
- Produces: no shipped file references `artifact-paths` any more, which is what lets Task 6 delete it. The script itself still exists after this task and is unused.

- [ ] **Step 1: Write the failing assertions**

In `tests/skills/test-authoring-skills.sh`, replace the four config-location assertions. For `brainstorm-design`, `brainstorm-architecture` and `writing-roadmaps`:

```bash
assert_contains "it reads its output path from the config" "$body" ".dopamine/config"
assert_contains "it describes the config format rather than naming a parser" \
    "$body" "tier: path"
assert_not_contains "no reference to the deleted parser survives" "$body" "artifact-paths"
```

For `adopting-a-repo`, replace `assert_contains "it verifies the config it wrote" "$body" "artifact-paths"` with:

```bash
assert_contains "it reads back the config it wrote" "$body" "read it back"
assert_not_contains "no reference to the deleted parser survives" "$body" "artifact-paths"
```

In `tests/test-authoring-end-to-end.sh`, replace the block `-- every root-relative reference to artifact-paths points at the real script` (currently lines 55–63) with a check that generalises it — every plugin-root-relative path a skill names must exist:

```bash
echo "-- every \${CLAUDE_PLUGIN_ROOT} path a skill names resolves"
# The gap this closes: a skill runs with the *user's* repository as its working
# directory, so a plugin-relative path only works when it is spelled through the
# plugin root. Checking that those spellings resolve is what stops a rename
# leaving the shipped plugin pointing at nothing.
missing=""
while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    [ -e "$REPO_ROOT/$rel" ] || missing="$missing $rel"
done < <(grep -rhoE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9._/-]+' "$REPO_ROOT/skills" \
    | sed 's|${CLAUDE_PLUGIN_ROOT}/||' | sed 's|/$||' | sort -u)
if [ -z "$missing" ]; then
    pass "every \${CLAUDE_PLUGIN_ROOT} path resolves"
else
    fail "every \${CLAUDE_PLUGIN_ROOT} path resolves" "missing:$missing"
fi
```

The companion check — that no skill names a script this change deletes — belongs in Task 6, not here: `skills/sweep/SKILL.md` still names all three at the end of this task, and it is Task 6 that rewrites it.

Replace the block `-- that config is one artifact-paths can read` (currently lines 74–86) with a parse check that needs no script:

```bash
echo "-- the documented config is well-formed under the format the skills describe"
# Each line is `tier: path`. There is no parser any more -- the consumer is an
# LLM reading the file -- so what is worth checking is that the block every
# document shows a human is actually in that shape.
malformed=$(printf '%s\n' "$from_skill" | grep -vE '^[a-z]+: [A-Za-z0-9._/-]+$' | grep -c . || true)
assert_eq "every documented line is one tier: path pair" "0" "$malformed"
assert_eq "it declares six paths" "6" "$(printf '%s\n' "$from_skill" | grep -c ':')"
assert_eq "three of them are the living tier" "3" \
    "$(printf '%s\n' "$from_skill" | grep -c '^living:')"
```

Replace the block `-- an unadopted repository is routed rather than guessed at` (currently lines 97–103) with:

```bash
echo "-- an unadopted repository is routed rather than guessed at"
assert_contains "the recipe names the absence of the config as the trigger" \
    "$(cat "$design")" ".dopamine/config"
assert_contains "and names the way out" "$(cat "$design")" "dopamine:adopting-a-repo"
```

The `TEST_ROOT`/`repo`/`bare` fixtures become unused; delete them along with the `mktemp -d`, its `trap` and the `git init` lines.

- [ ] **Step 2: Run them to make sure they fail**

Run: `bash tests/skills/test-authoring-skills.sh; bash tests/test-authoring-end-to-end.sh`
Expected: FAIL — three `tier: path` needles missing, four `no reference to the deleted parser survives / unexpectedly present: artifact-paths`, and `it reads back the config it wrote / missing: read it back`.

The `${CLAUDE_PLUGIN_ROOT}` resolve check passes from the moment it is written: the script it will guard against still exists. It is a regression guard replacing the narrower one it supersedes, not a driver for this task's change — which is why every assertion that *does* drive the change is listed above it.

- [ ] **Step 3: Rewrite `brainstorm-design` §1**

Replace `### 1. Locate the output` (currently lines 20–24) with:

```markdown
### 1. Locate the output

Read `.dopamine/config` at the repository root. It declares one `tier: path` per line; the design document is the `living:` path whose basename is `DESIGN.md`, present or absent. A declared path that does not exist is **absent**, not an error. Where no declared path matches, ask which one is meant rather than creating a second.

No `.dopamine/config` means this repository has not adopted dopamine. Use dopamine:adopting-a-repo first — it writes the config, and where there is already code it reconstructs rather than brainstorms.
```

- [ ] **Step 4: Rewrite `brainstorm-architecture` §1**

Replace `### 1. Locate the input and the output` (currently lines 20–24) with:

```markdown
### 1. Locate the input and the output

Read `.dopamine/config`; it declares one `tier: path` per line, and its `living:` paths give both. The architecture document is the declared path whose basename is `ARCHITECTURE.md`; `DESIGN.md` beside it is this brainstorm's input. A declared path that does not exist is **absent**, not an error. Where no declared path matches either name, ask which is meant rather than creating a second. No `.dopamine/config` means the repository has not adopted dopamine — run dopamine:adopting-a-repo first.

An absent `DESIGN.md` stops this recipe: run dopamine:brainstorm-design and come back.
```

- [ ] **Step 5: Rewrite `writing-roadmaps` §1**

Replace `### 1. Locate the output and read the two inputs` (currently lines 18–20) with:

```markdown
### 1. Locate the output and read the two inputs

Read `.dopamine/config`; it declares one `tier: path` per line, and its `living:` paths give all three. The roadmap is the declared path whose basename is `ROADMAP.md`; where no declared path matches, ask which one is meant rather than creating a second. `DESIGN.md` says what must exist; `ARCHITECTURE.md` says what depends on what. With either absent the phases would be guesses — run dopamine:brainstorm-design and dopamine:brainstorm-architecture first. No `.dopamine/config` means the repository has not adopted dopamine — run dopamine:adopting-a-repo first.
```

The needle `The roadmap is the declared path whose basename is` is asserted in `tests/skills/test-authoring-skills.sh`; keep that clause word for word.

- [ ] **Step 6: Rewrite `adopting-a-repo` §1's verification sentence**

Replace the sentence at line 33 (`Verify with ${CLAUDE_PLUGIN_ROOT}/skills/sweep/scripts/artifact-paths. Exit 0, …`) with:

```markdown
Then read it back and confirm every line is one `tier: path` pair, and that each declared path is either present or one this project intends to create. A declared path that does not exist yet is **absent**, not an error, and adoption goes on.
```

- [ ] **Step 7: Update `.dopamine/config`'s comment**

Replace the two comment lines that name the deleted script:

```
# dopamine's own artifact map.
#
# DESIGN.md, ARCHITECTURE.md and ROADMAP.md are declared and do not exist yet.
# Deriving them is `dopamine:brainstorm-design`, `dopamine:brainstorm-architecture`
# and `dopamine:writing-roadmaps`, which need a brainstorm with a human and so
# have not been run here yet. A declared path that does not exist is absent, not
# an error, which is how that stays visible without any nagging machinery.
living: docs/DESIGN.md
living: docs/ARCHITECTURE.md
living: docs/ROADMAP.md
instructions: CLAUDE.md
lessons: docs/LESSONS.md
plans: docs/superpowers/plans
```

The six `tier: path` lines must stay byte-identical: `tests/test-authoring-end-to-end.sh` asserts the block in `adopting-a-repo/SKILL.md` and the block in `README.md` are the same six lines, and this file is the live instance of them.

- [ ] **Step 8: Run the whole suite**

Run: `bash tests/run-tests.sh`
Expected: PASS — `all 13 test file(s) passed`. `tests/scripts/test-artifact-paths.sh` still passes: the script is unused but not yet deleted.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "refactor: state the config format in prose instead of calling a parser

An 87-line parser for a six-line file made sense when a hook read it.
The consumer is now an LLM, which needs three facts: each line is
'tier: path', a declared path that does not exist is absent rather than
an error, and no config at all means the repo has not adopted dopamine.

artifact-paths is now unreferenced; it is deleted with the pipeline."
```

---

### Task 6: Replace `sweep` with `finishing-work`

**Files:**
- Rename: `skills/sweep/` → `skills/finishing-work/`
- Rewrite: `skills/finishing-work/SKILL.md` (58 lines → the recipe below)
- Delete: `skills/finishing-work/discovery-prompt.md`, `implementer-prompt.md`, `verifier-prompt.md`, `scripts/artifact-paths`, `scripts/seal-ledger`, `scripts/sweep-package`
- Delete: `tests/scripts/test-artifact-paths.sh`, `tests/scripts/test-seal-ledger.sh`, `tests/scripts/test-sweep-package.sh`
- Modify: `skills/writing-roadmaps/SKILL.md:53` (`dopamine:sweep`, and the brief that no longer exists)
- Rewrite: `hooks/session-start-context.md` (all 7 lines — it names the renamed skill, so it moves with it)
- Modify: `tests/skills/test-skill-structure.sh` (BUDGETS key, and the `-- sweep content` block including its three prompt sub-blocks)
- Modify: `tests/hooks/test-session-start.sh` (the `-- what the injection actually says` block)
- Modify: `tests/test-authoring-end-to-end.sh` (add the deleted-script guard deferred from Task 5)
- Rewrite: `tests/test-spine-end-to-end.sh` (every unit it integrated is gone; it becomes the chain that survives)
- Modify: `tests/test-guard-end-to-end.sh` (the `-- the sweep now gates promotions on the guard` block)

**Interfaces:**
- Consumes: `dopamine:routing-documentation-updates` (Task 2), `dopamine:writing-claude-md` (Task 3), `dopamine:writing-living-documents` (Task 4). All three are named in the recipe, so this task must run last of the four.
- Produces: the skill name `dopamine:finishing-work`, referenced by `README.md` in Task 7. The commit convention `sweep: <slug> — …` is unchanged.

**Why the injection moves here and not in Task 7:** `hooks/session-start-context.md` is the only shipped file left naming `dopamine:sweep`, and the rewritten `tests/test-spine-end-to-end.sh` below resolves every skill the injection names. Leaving the rename to Task 7 would end this task with a red suite.

- [ ] **Step 1: Write the failing assertions for the recipe**

In `tests/skills/test-skill-structure.sh`, change the BUDGETS key `sweep:700` to `finishing-work:700`, then replace the entire `-- sweep content` block (currently lines 150–211, all three prompt sub-blocks included) with:

```bash
echo "-- finishing-work content"
fw="$REPO_ROOT/skills/finishing-work/SKILL.md"
if [ -f "$fw" ]; then
    body=$(cat "$fw")
    assert_contains "the input is the sealed ledger, not the documents" \
        "$body" "sealed ledger"
    assert_contains "documents are reached along terms derived from it" "$body" "grep terms"
    assert_contains "and never read in bulk" "$body" "in bulk"
    assert_contains "sealing is one copy, not a script" "$body" "cp .superpowers/sdd/"
    assert_contains "an absent ledger is reconstructed rather than skipped" \
        "$body" "reconstruction"
    assert_contains "the commit convention survives the rename" "$body" "sweep: <slug>"
    assert_contains "nothing to drain is a legitimate outcome" "$body" "nothing to drain"
    assert_contains "the close reports the line counts that make failure visible" \
        "$body" "wc -l"
    assert_contains "it says where it sits relative to branch integration" \
        "$body" "finishing-a-development-branch"
    assert_contains "it points at the routing skill rather than restating it" \
        "$body" "dopamine:routing-documentation-updates"
    assert_contains "it hands each edit to the schema skill" \
        "$body" "dopamine:writing-living-documents"
    assert_contains "an instructions-tier candidate goes through the admission test" \
        "$body" "dopamine:writing-claude-md"

    echo "-- finishing-work's exit gate"
    gate=$(awk '/^## Exit gate$/{flag=1; next} /^## /{flag=0} flag' "$fw")
    assert_contains "right tier" "$gate" "Right tier"
    assert_contains "changed what changed" "$gate" "Changed what changed"
    assert_contains "no run number entered a living document" "$gate" "describing a run"
    assert_contains "every promotion carries an admission verdict" "$gate" "verdict"
    assert_contains "historical records untouched" "$gate" "Historical records"
    assert_contains "the gate is a self-review, not a subagent dispatch" \
        "$gate" "fresh eyes"

    echo "-- the pipeline's files are gone"
    for gone in discovery-prompt.md implementer-prompt.md verifier-prompt.md \
                scripts/artifact-paths scripts/seal-ledger scripts/sweep-package; do
        if [ -e "$REPO_ROOT/skills/finishing-work/$gone" ]; then
            fail "$gone is deleted" "still present"
        else
            pass "$gone is deleted"
        fi
    done
    assert_not_contains "the recipe prescribes no agent count" "$body" "one subagent"
else
    fail "skills/finishing-work/SKILL.md exists" "not found"
fi
```

In `tests/test-authoring-end-to-end.sh`, add the guard deferred from Task 5, immediately after the `-- every ${CLAUDE_PLUGIN_ROOT} path a skill names resolves` block:

```bash
echo "-- no skill names a script this change deleted"
leftover=$(grep -rhoE '(artifact-paths|seal-ledger|sweep-package)' "$REPO_ROOT/skills" | sort -u)
assert_eq "artifact-paths, seal-ledger and sweep-package are gone from the skills" \
    "" "$leftover"
```

In `tests/hooks/test-session-start.sh`, replace the `-- what the injection actually says` block (currently lines 71–74) with:

```bash
echo "-- what the injection actually says"
assert_contains "names the skill that closes a unit of work" "$ctx" "dopamine:finishing-work"
assert_contains "names the skill loaded before writing to a living document" \
    "$ctx" "dopamine:writing-living-documents"
assert_contains "names the skill loaded before writing to the instructions file" \
    "$ctx" "dopamine:writing-claude-md"
assert_contains "points at superpowers' existing ledger" "$ctx" "ledger"
assert_contains "names the living documents it governs" "$ctx" "living document"
assert_not_contains "no reference to the renamed skill survives" "$ctx" "dopamine:sweep"
```

The 200-word budget check and the no-prohibition check below it stay exactly as they are — the rewritten injection must satisfy both.

- [ ] **Step 2: Run them to make sure they fail**

Run: `bash tests/skills/test-skill-structure.sh; bash tests/test-authoring-end-to-end.sh; bash tests/hooks/test-session-start.sh`
Expected: FAIL — `skills/finishing-work/SKILL.md exists / not found`, `sweep: has a declared word budget`, the three script names still present under `skills/`, three missing `dopamine:` needles in the injection, and `dopamine:sweep` unexpectedly present in it.

- [ ] **Step 3: Move the directory and delete the pipeline's files**

```bash
git mv skills/sweep skills/finishing-work
git rm skills/finishing-work/discovery-prompt.md \
       skills/finishing-work/implementer-prompt.md \
       skills/finishing-work/verifier-prompt.md \
       skills/finishing-work/scripts/artifact-paths \
       skills/finishing-work/scripts/seal-ledger \
       skills/finishing-work/scripts/sweep-package \
       tests/scripts/test-artifact-paths.sh \
       tests/scripts/test-seal-ledger.sh \
       tests/scripts/test-sweep-package.sh
```

- [ ] **Step 4: Write `skills/finishing-work/SKILL.md`**

Replace the file entirely:

```markdown
---
name: finishing-work
description: Use when a superpowers plan or an ad-hoc unit of work is finished and before its workspace is cleaned up, or when a living document has fallen behind what the code now does
---

# Finishing work

## Overview

Work is finished when what happened during it has been carried back into the documents that describe the present. That carry is the sweep, and this is its recipe.

Its input is the **sealed ledger** — never the documents in bulk. It reaches into a document only along grep terms derived from that ledger. That is the whole cost argument: the work tracks the change, not the size of the project.

**This runs one step before `superpowers:finishing-a-development-branch`**, while the workspace still exists. Branch integration follows it. The two fire at nearly the same moment and neither one covers the other.

**REQUIRED BACKGROUND:** Use dopamine:routing-documentation-updates — which tier a fact belongs to decides where every edit lands.

## Obligations

### 1. Seal

`cp .superpowers/sdd/<slug>/progress.md <plans>/<slug>.ledger.md`, taking `<plans>` from the `plans:` line of `.dopamine/config`. Superpowers deletes that ledger with the workspace, and it is the one genuinely unreconstructable record of the work.

No ledger — ad-hoc work, or `superpowers:executing-plans` — means writing one: `<plans>/<slug>.reconstructed-ledger.md`, from what this conversation records, opening with a line naming it a reconstruction and dating it. A reconstruction is the weaker record, and that line is how later readers know. Ad-hoc work has no plan file: name a dated slug once and use it wherever this recipe says `<slug>`.

### 2. Drain from the ledger

Read the sealed ledger in full. Derive grep terms from it — the names, paths, symbols and decisions it actually mentions — and reach into a living document only along those terms. Reading the documents **in bulk** returns this to O(project), which is the cost this plugin exists to avoid.

Use dopamine:writing-living-documents for each edit to a living document, and dopamine:writing-claude-md for anything proposed for the instructions tier.

### 3. Commit

`sweep: <slug> — 3 edits`, or `sweep: <slug> — nothing to drain`.

The `sweep:` prefix is a commit convention, not a skill name. `git log --grep='^sweep:'` is how a project answers whether sweeps are happening at all, so the prefix outlives any renaming of this skill.

### 4. Report the line counts

In the same commit message, `wc -l` for each `living:` document and for the `instructions:` file. Growth in those numbers without matching growth in the system is the signal that routing is not being applied — and it is the number that was legible the whole time in the project this plugin was built from, while nobody looked.

## Exit gate

Five checks, run with **fresh eyes** over the diff, fixed inline. No re-review and no subagent dispatch: this is the pattern superpowers uses for its own documents, where the human is the gate. A fresh-subagent review is for code, which has tests and objective failure modes.

1. **Right tier.**
2. **Changed what changed** — a paragraph appended where existing text should have been replaced is a failure even when the added text is true.
3. **No number describing a run** entered a living document.
4. **Every promotion to the instructions tier carries an admission verdict.**
5. **Historical records untouched** — specs, plans and sealed ledgers are immutable.

## Method is your judgment

A ledger with thirty entries across four documents may be worth fanning out; a two-line drain is not. Nothing here prescribes an agent count.

## What a finished sweep leaves

The **sealed ledger** beside the plan, and one `sweep:` commit whose message carries the line counts. No separate record: a brief would restate the ledger, which is the failure this plugin exists to prevent.

| The ledger holds | This produces |
|---|---|
| Entries with living-document consequence | The edits, one `sweep:` commit, and the line counts |
| No drainable entries | The sealed ledger, and a `nothing to drain` commit |
| A declared document that does not exist | It is reported absent, and it is not created |

**"Nothing to drain" is a finished sweep**, not a skipped one. It is a conclusion about the ledger, reached by reading it.

Decisions made along the way — a routed promotion, a claim placed against the obvious tier — are reported in the conversation when the work closes and then forgotten. A decision that was genuinely contested is a **ruling**, and a ruling belongs in the ledger, where it seals with everything else.
```

- [ ] **Step 5: Update `writing-roadmaps`' reference to the old skill**

In `skills/writing-roadmaps/SKILL.md`, replace the paragraph at line 53:

```markdown
The ledger is immutable, so the trail cannot rot; its header names the plan, which names the spec. `dopamine:finishing-work` has no concept of a phase, so re-running this recipe at each close is what strikes it.
```

Then confirm no shipped file still names the old skill:

```bash
grep -rn 'dopamine:sweep\|skills/sweep' skills hooks tests README.md .claude-plugin .dopamine
```

Expected: only `hooks/session-start-context.md`, which the next step rewrites.

- [ ] **Step 6: Rewrite `hooks/session-start-context.md`**

Replace the file entirely. Two rules govern the wording: it must stay under 200 words, and it must avoid `never` / `do not` / `don't` — the failure this injection addresses is wrong-shaped output, not a rule an agent knows and skips, and prohibitions test worse than conditionals on that failure. `tests/hooks/test-session-start.sh` asserts both.

```markdown
**Documentation discipline (add-on to superpowers)**

This project has living documents — listed in `.dopamine/config` — that describe the present. Superpowers' ledger already records what happened during execution; that record is the sweep's input, and it is the only journal you keep.

If you find yourself about to change a living document mid-execution, record it in the ledger instead and let the sweep place it.

When you do write to a living document, load `dopamine:writing-living-documents` first; for `CLAUDE.md`, load `dopamine:writing-claude-md`. Each holds the shape that document has to keep, and `dopamine:routing-documentation-updates` decides which document a fact belongs in at all.

At the end of any plan or ad-hoc unit of work, and before the workspace is cleaned up, invoke the `dopamine:finishing-work` skill.
```

Note the resulting `wc -w hooks/session-start-context.md`; Task 7 states that figure in the README's component table.

- [ ] **Step 7: Rewrite `tests/test-spine-end-to-end.sh` as the chain that survives**

Every unit the old file integrated — the gate, `seal-ledger`, `sweep-package` — is deleted. What survives of the spine is the config, the `SessionStart` hook that reads it, and the skill that hook names. Replace the file entirely:

```bash
#!/usr/bin/env bash
# The spine as one mechanism: config, injection, skill.
#
# What is left of the spine after the hooks and scripts came out is a chain of
# names: a repository declares .dopamine/config, the SessionStart hook notices
# and injects, the injection names dopamine:finishing-work, and that skill names
# the three skills it delegates to. Every unit test here reads one file by its
# own path, so all of them keep passing after a rename that leaves the shipped
# plugin pointing at nothing. This file is what catches that.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=helpers.sh
source "$REPO_ROOT/tests/helpers.sh"

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

repo="$TEST_ROOT/project"
mkdir -p "$repo/.dopamine" "$repo/docs/superpowers/plans"
git init -q "$repo"
printf 'living: docs/DESIGN.md\ninstructions: CLAUDE.md\nplans: docs/superpowers/plans\n' \
    > "$repo/.dopamine/config"

echo "-- an adopted repository gets the injection"
out=$( (cd "$repo" && CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$REPO_ROOT/hooks/session-start") )
ctx=$(printf '%s' "$out" | python3 -c '
import json, sys
raw = sys.stdin.read().strip()
print(json.loads(raw)["hookSpecificOutput"]["additionalContext"] if raw else "")')
assert_contains "the injection arrived" "$ctx" "living document"

echo "-- the injection names skills that exist"
unresolved=""
while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    [ -f "$REPO_ROOT/skills/$ref/SKILL.md" ] || unresolved="$unresolved $ref"
done < <(printf '%s' "$ctx" | grep -oE 'dopamine:[a-z][a-z-]*' | sed 's/^dopamine://' | sort -u)
if [ -z "$unresolved" ]; then
    pass "every skill the injection names resolves"
else
    fail "every skill the injection names resolves" "unresolved:$unresolved"
fi
assert_contains "it names the skill that closes a unit of work" \
    "$ctx" "dopamine:finishing-work"

echo "-- and that skill names the three it delegates to"
fw=$(cat "$REPO_ROOT/skills/finishing-work/SKILL.md")
for dep in routing-documentation-updates writing-living-documents writing-claude-md; do
    assert_contains "finishing-work reaches dopamine:$dep" "$fw" "dopamine:$dep"
    assert_eq "and dopamine:$dep exists" "yes" \
        "$([ -f "$REPO_ROOT/skills/$dep/SKILL.md" ] && echo yes || echo no)"
done

echo "-- the sweep's own record is the sealed ledger, and nothing beside it"
assert_contains "sealing is a copy the recipe spells out" "$fw" "cp .superpowers/sdd/"
assert_contains "the commit prefix that makes sweeps greppable is stated" \
    "$fw" "git log --grep='^sweep:'"

echo "-- an unadopted repository is silent"
plain="$TEST_ROOT/plain"
mkdir -p "$plain"
git init -q "$plain"
RC=0
out=$( (cd "$plain" && CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$REPO_ROOT/hooks/session-start") ) || RC=$?
assert_eq "exits 0" 0 "$RC"
assert_eq "and injects nothing" "" "$out"

finish
```

- [ ] **Step 8: Update the promotion-gating block in `tests/test-guard-end-to-end.sh`**

Replace the block `-- the sweep now gates promotions on the guard` (currently lines 113–118) with:

```bash
echo "-- the close still gates promotions on the admission test"
fw=$(cat "$REPO_ROOT/skills/finishing-work/SKILL.md")
assert_contains "finishing-work routes instructions-tier candidates through the test" \
    "$fw" "dopamine:writing-claude-md"
assert_contains "and its exit gate catches a promotion that arrived without a verdict" \
    "$fw" "admission verdict"
```

- [ ] **Step 9: Run the whole suite**

Run: `bash tests/run-tests.sh`
Expected: PASS — `all 10 test file(s) passed`.

- [ ] **Step 10: Verify the deletion arithmetic**

Run: `git diff --stat main -- hooks skills tests`
Expected: the deletions across Tasks 1 and 6 total roughly 1,500 lines, matching spec §1. If the number is materially lower, something the spec listed for deletion is still present.

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "refactor: replace the sweep pipeline with the finishing-work recipe

Superpowers already provides a fresh implementer per task, a task
reviewer and a whole-branch review before the workspace is deleted. Two
of the old verifier's three verdicts policed seams the pipeline itself
created -- brief-to-implementer placement, and a drain-completeness
check whose independence trick only works on an agent that did not write
the brief. With no handoff there is no handoff error. Discipline, the
one verdict that was ever about the documents, becomes the exit gate.

Method -- subagents or not -- is the agent's judgment."
```

---

### Task 7: Update the two documents that describe the machinery

**Files:**
- Modify: `README.md` (component table, Requirements, Known gaps, Status)
- Modify: `.claude-plugin/plugin.json` (description, version, keywords)

**Interfaces:**
- Consumes: every skill name established in Tasks 2–6, and the injection's word count from Task 6 Step 6.
- Produces: nothing later tasks depend on. This is the last task.

**No test drives this task.** `README.md` and `plugin.json` are prose and metadata. The only two assertions that touch either are `tests/test-plugin-manifests.sh`, which checks that a version field exists rather than what it holds, and the config-block equality check in `tests/test-authoring-end-to-end.sh`. Step 6 below is what catches a stale name, and it is a grep the implementer runs rather than a test file — so read its output, do not just check its exit status.

- [ ] **Step 1: Update `README.md`'s component table**

Replace the two hook rows and the three renamed skill rows, and add the new skill. The table becomes:

```markdown
| Piece | What it does |
|---|---|
| `.dopamine/config` | Declares which paths hold which artifact tier. The plugin hard-codes no project's document set |
| `SessionStart` hook | ~145 words positioning dopamine relative to superpowers, and naming the skills that hold each document's rules. Silent in a repo with no config |
| `dopamine:adopting-a-repo` | Writes the config, surveys existing code, and reconstructs the living documents — marking what was inferred |
| `dopamine:brainstorm-design` | Wraps superpowers' brainstorming at system scope and derives `DESIGN.md` |
| `dopamine:brainstorm-architecture` | The same at assembly scope, deriving `ARCHITECTURE.md` |
| `dopamine:writing-roadmaps` | Breaks the two into phases sized for one superpowers loop, producing `ROADMAP.md` |
| `dopamine:routing-documentation-updates` | Where each kind of fact belongs, and why only two tiers are ever re-verified |
| `dopamine:writing-living-documents` | The slots each living document has, one schema file per document, and the rules for writing into them |
| `dopamine:writing-claude-md` | The admission test, the routing table for what fails it, and the vendored standard behind both |
| `dopamine:finishing-work` | Seal the ledger, drain it along terms derived from it, commit, and report the line counts |
```

Substitute the actual `wc -w hooks/session-start-context.md` from Task 6 Step 6 for `~145`, rounded to the nearest five. The `How it works` prose above the table needs no change: superpowers still keeps a per-plan ledger and still deletes it when the plan finishes, and dopamine still seals it before that happens.

- [ ] **Step 2: Rewrite `README.md`'s Requirements section**

```markdown
## Requirements

**bash and git.** That is the whole runtime: one `SessionStart` hook and a set of skills.

Python 3 is used by the **test suite** — `tests/` parses JSON and skill frontmatter with it — and by nothing the plugin ships.

`skills/writing-claude-md/scripts/refresh-rule-card` also needs **curl or wget**, and network access. It is a maintenance script that runs off the edit path; nothing else in the plugin makes a network request.
```

- [ ] **Step 3: Rewrite `README.md`'s Known gaps section**

Six of the eight gaps described deleted machinery. Delete these five outright — the seal gate they describe no longer exists:

- the `rm -rf "$dir"` shell-variable gap
- the `git clean -fdx` gap
- the delete-verb list gap
- the verb-word-match gap
- the `PostToolUse` output-shape gap

Delete the `${CLAUDE_PLUGIN_ROOT}` gap too: the scripts it named are gone, and `tests/test-authoring-end-to-end.sh` now asserts that every `${CLAUDE_PLUGIN_ROOT}` path a skill names resolves.

Rewrite the `CLAUDE.md` bypass gap, since nothing intercepts those edits now, and keep the other two. The section becomes:

```markdown
## Known gaps

- **Nothing enforces that a writing skill is loaded before a governed document changes.** The `SessionStart` injection names `dopamine:writing-living-documents` and `dopamine:writing-claude-md`, and `dopamine:finishing-work`'s exit gate catches a promotion that arrived without an admission verdict — but on the ad-hoc path an edit can land unexamined. This is the first place the rules-over-mechanism bet would visibly fail, and the first candidate for escalation back to a hook.
- **No ledger outside `subagent-driven-development`.** `executing-plans` and ad-hoc work have none, so the sweep falls back to reconstruction there. A reconstruction opens with a line saying so, which is how later readers know it is the weaker record.
- **The `living:` tier does not say which path plays which role.** The authoring recipes take the declared path whose basename matches the document they own — `DESIGN.md` for `dopamine:brainstorm-design`, and so on — and ask the human where no path matches. A project using different filenames therefore answers one question per recipe, once. A `role:` field in the config is the escalation if that proves annoying.
- **Whether sweeps happen at all is answered only after the fact.** `git log --grep='^sweep:'` shows which units of work closed with one; nothing prompts for the ones that did not. Line-count growth in the commit messages is the signal that routing is being skipped, and it has to be read by a human.
```

Leave the `The problem`, `Install`, `Tests` sections and the six-line config block untouched — `tests/test-authoring-end-to-end.sh` asserts the README's config block matches `adopting-a-repo`'s byte for byte.

- [ ] **Step 4: Update `README.md`'s Status section**

```markdown
## Status

All three original slices were built — the spine, the `CLAUDE.md` guard, and the authoring skills — and the first two have since been replaced by rules. The design they now implement is `docs/superpowers/specs/2026-09-01-dopamine-rules-over-mechanism-design.md`, which supersedes the hooks and the sweep pipeline in `docs/superpowers/specs/2026-08-28-dopamine-design.md` while leaving its artifact model intact.

This repository has not yet run its own authoring recipes on itself: `docs/DESIGN.md`, `docs/ARCHITECTURE.md` and `docs/ROADMAP.md` are declared in `.dopamine/config` and are absent, which is the mechanism working rather than a gap in it.
```

- [ ] **Step 5: Update `.claude-plugin/plugin.json`**

```json
{
  "name": "dopamine",
  "description": "Documentation discipline for long-horizon work: authors a project's living documents, then carries each finished unit of work back into them at a cost that tracks the change",
  "version": "0.2.0",
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
    "sweep",
    "roadmap",
    "architecture"
  ]
}
```

The minor bump, not a patch: two hooks and three scripts are gone, and a repository pinning `0.1.x` should not silently receive that.

- [ ] **Step 6: Run the whole suite**

Run: `bash tests/run-tests.sh`
Expected: PASS — `all 10 test file(s) passed`. Nothing in this task is asserted, so a failure here means one of the two surviving checks broke: the manifest's version field, or the README config block's equality with `adopting-a-repo`'s.

- [ ] **Step 7: Final sanity sweep for stale names**

```bash
grep -rn 'artifact-map\|claude-md-guard\|dopamine:sweep\|artifact-paths\|seal-ledger\|sweep-package\|py-hook\|seal-gate' \
    skills hooks tests README.md .claude-plugin .dopamine
```

Expected: no output. Anything reported is a missed rename — `docs/` is deliberately excluded and must not be searched or edited.

```bash
git status --short
```

Expected: clean.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "docs: describe the plugin that now ships

The README's component table, Requirements and Known gaps described two
hooks and three scripts that no longer exist, and six of the eight known
gaps were properties of the deleted seal gate or of hooks that no longer
fire. One gap replaces them, and it is the one this change creates:
nothing enforces that a writing skill is loaded before a governed
document changes.

Minor version bump: hooks and scripts were removed, so 0.1.x pins
should not receive this silently."
```

---

## Verification

After Task 7, the whole change is checkable in four commands:

```bash
bash tests/run-tests.sh                    # all 10 test file(s) passed
find hooks -name '*.py' -o -name 'py-hook' # empty: bash + git at runtime
ls skills/                                 # 8 skills, all verb-first or gerund
git diff --stat main                        # ~1,500 lines deleted
```

**What cannot be checked here, and is deliberately left to manual validation** (spec §8, Ruling 1): whether the skills teach the right thing. The RED phase — running a subagent without each skill and recording how it fails — is waived for time. Two consequences the maintainer should hold: a skill may counter a rationalization no agent ever produces, and a skill that was never needed is invisible to manual checking, because identifying one requires deliberately running without it.

**The number to watch** is the one in every `sweep:` commit message. `git log --grep='^sweep:'` says whether sweeps are happening; the `wc -l` figures in those messages say whether routing is being applied. Growth without matching growth in the system is the signal to escalate a rule back into mechanism.
