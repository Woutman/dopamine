# Dopamine — design

> **Status.** Design settled 2026-08-28. **The name is provisional.**
>
> **Reading order.** This document, then the implementation plan it produces. There is no
> `DESIGN.md` yet: deriving one from this spec is a job for the plugin itself, once it exists.

## 1. What this is

A Claude Code plugin that sits beside [superpowers](https://github.com/obra/superpowers) and
operates **one level above it**. Superpowers plans and executes a change; dopamine designs and
sequences a project, and carries what actually happened back into the documents that describe it.

Its subject is agent alignment and efficiency on **long-horizon work**. Documentation discipline is
the first strand, not the whole scope; in-code comment discipline follows, and further
documentation-related capabilities after that.

## 2. The problem, measured

The predecessor project `heijmans-demo` accumulated **5,186 lines** across six documents
(`ARCHITECTURE.md` 1,534, `DESIGN.md` 1,340, `ROADMAP.md` 830, `OBSERVABILITY.md` 587, `CLAUDE.md`
516, `CLIENT_HANDOFF.md` 379) for roughly thirty Python modules and a small React page.

Line count alone is not the finding. The reported cost is:

- context burned on every session that read them;
- **each implementation phase slower than the last**;
- an end-of-development **document sweep that routinely took several times longer than any other
  activity**.

That last item is the target. The sweep is expensive because it is a **reconstruction** task whose
input grows with the project:

| Step | What the agent does | Scales with |
|---|---|---|
| 1 | Re-read the documents | the project |
| 2 | Reconstruct what happened this phase | the phase, lossily |
| 3 | Decide where each change belongs | the change |
| 4 | Determine what is now **false** | the project |
| 5 | Rewrite in place without eroding what was load-bearing | the change |

Steps 1 and 4 scale with the project rather than the phase. That is the superlinearity, and keeping
documents *tidy* does not touch it: a perfectly written 400-line `DESIGN.md` still has to be fully
re-read and fully re-verified at every phase close.

**Superpowers already sweeps at the end of each plan** — emergently, unenforced — and the demo
degraded anyway. So the failure was never the trigger. It was the sweep's inputs and the growth of
its swept surface.

## 3. The target and the acid test

**A sweep whose cost tracks the change, not the project.**

Every mechanism must answer one question: **is its cost O(change) or O(project)?** Anything
O(project) per phase is rejected regardless of how well it performs on a small repository.

Rejected by that test, and named here so they are not reintroduced:

- **Uniform size budgets** (`any doc <= 400 lines`). They treat a `CLAUDE.md` and an ADR as the same
  kind of object when the two differ by read frequency, and a document at its cap plus an agent with
  a new paragraph produces silent erosion of the oldest, least-defended prose.
- **Whole-repo LLM review passes.** O(project) by construction.
- **Declared per-section anchors** with an import-closure staleness graph. Rejected as premature: a
  distributed tax on every phase, largely redundant with the ledger, paid against a win condition
  most projects never reach. Purely additive if ever needed.
- **Any "re-read everything and reconcile" ritual**, including the one being done by hand today.

## 4. The inversion

Appending is not the enemy. Appending **into living documents** is — because a living document is
the only artifact that must later be re-read and re-verified in full.

Superpowers already maintains a per-plan **ledger** at
`<repo-root>/.superpowers/sdd/<plan-basename>/progress.md` (git-ignored), created by
`subagent-driven-development` to survive compaction. It records rulings
(`Ruling: <what> — <why> — <what it costs if wrong>`), task completions, deferred and parked
findings, and the preflight conflict table.

**That is the journal, and it already exists.** It captures the one thing that is genuinely
unreconstructable: deviations from the plan, recorded as they happen. Lessons, gotchas and measured
numbers are *recoverable* at sweep time from the ledger plus the diff plus the plan and spec — which
is why the emergent sweeps caught them.

At `Finish`, superpowers harvests `Ruling:` lines into a chat message and then runs
`rm -rf <workspace>`. Its own skill text says *"a ruling that dies with the workspace was a decision
made in secret"* — but a chat message scrolls away. **The actuality record is created, used, and
destroyed by design.** Preserving it is the single highest-leverage change available.

## 5. Ownership boundary

**Dopamine reads superpowers' artifacts and writes only its own.**

No fork, no patch, no co-owned file. Sealing the ledger is a read of their file and a write of ours,
so the boundary holds. If a superpowers release changes its layout we break loudly at a hook rather
than diverging silently from a fork.

Consequence, accepted deliberately: **we do not widen the ledger's entry kinds.** If drained content
proves thin in practice, the escalation is a supplementary journal in our own directory — never a
second set of instructions about their file, which would risk agents logging the same event twice.

## 6. Artifact model

| Kind | Files | At sweep |
|---|---|---|
| **Living** — describes the present | `DESIGN.md`, `ARCHITECTURE.md`, `ROADMAP.md` | Drained **and verified** |
| **Instructions** — highest read frequency | `CLAUDE.md` | Drained, verified, **plus an admission test** |
| **Append-mostly** — dated observations, reached by grep | `LESSONS.md` | Drained, **never verified**; growth unbounded by design |
| **Immutable** — intent and actuality | `specs/`, `plans/`, sealed ledgers | Never touched |
| **Consumed** — deleted when discharged | handoffs (a supported kind, not a mandate) | n/a |

The tiers are not tidiness. They are a **sweep-cost optimisation**: only the first two tiers are ever
re-read and re-verified, so the discipline pushes content out of them wherever it legitimately can.

Notes that follow from the model:

- **A dated observation never goes stale; a prescription does.** "We tried X on this date, it failed
  because Y" is a claim about a past event and stays true. "Do not use X" stops being true when the
  library is fixed or the constraint lifts. The never-verified tier is therefore sound only for
  entries written as dated observations — see §9.6. Cost stays O(new lessons).
- **A number that describes the system now** — the current retrieval gate, the current backfill cost
  — lives in a living document as a bounded set, **replaced** rather than appended. **A number that
  describes a run** stays in the sealed ledger and is cited. This gives the "same figure restated in
  three places and defended when it drifts" failure a structural fix, and removes any need for a
  `docs/evidence/` directory.
- **No `docs/decisions/` either.** A spec records what was *planned*; agents deviate from specs
  routinely; the sealed ledger records what was actually decided. Spec plus ledger is the decision
  archive, and inventing ADRs alongside them would be convention rather than need.
- **One unit of work leaves three dated siblings**: spec (what we meant to build), plan (how we meant
  to build it), sealed ledger (what actually happened). The deviation is the delta between the second
  and the third.

## 7. Layer model

| superpowers | dopamine |
|---|---|
| `brainstorming` → spec (one change) | `brainstorm-design` → `DESIGN.md`; `brainstorm-architecture` → `ARCHITECTURE.md` |
| `writing-plans` → plan: a spec broken into **tasks** sized for execution loops | `writing-roadmaps` → `ROADMAP.md`: a design broken into **phases** sized for superpowers loops |
| `subagent-driven-development` → executes one plan | (each roadmap phase **is** one superpowers cycle) |
| — | `sweep` → drains the sealed ledger back into the living documents |

The loop closes: dopamine sequences the project, superpowers executes each phase, the sweep carries
actuality back up.

**Order.** `brainstorm-design` → `brainstorm-architecture` → `writing-roadmaps`. The roadmap comes
last because phase order is driven by technical dependency — what proves what, which prerequisite
gates which slice — and that is knowable only once the assembly is designed.

**Phase sizing, by analogy.** `writing-plans` defines a task as *"the smallest unit that carries its
own test cycle and is worth a fresh reviewer's gate"* and requires each plan to *"produce working,
testable software on its own."* So a **phase is the smallest unit that makes one good plan** —
independently valuable, independently verifiable, with exit criteria that are observations rather
than assertions.

**Brainstorm wrappers, not interception.** `brainstorm-design` and `brainstorm-architecture` invoke
`superpowers:brainstorming` with a scope and framing supplied, then derive their living document from
the spec it produces. Superpowers keeps its promise — a brainstorm always delivers a spec — and we
touch none of its files. Detecting "project scope" from repository state was considered and rejected:
making a documented contract behave differently based on invisible context is hostile to debug.

A spec and a living document only duplicate if **both** are consulted as current truth. They are not:
the spec is immutable intent, frozen at its date, never swept, never authoritative about the present.
A living document diverging from the spec that produced it is correct behaviour, exactly as shipped
code diverges from the plan that made it.

## 8. Components

### Skills

| Skill | Form | Job |
|---|---|---|
| `brainstorm-design` | Recipe | Wraps `superpowers:brainstorming` at system scope; derives `DESIGN.md` |
| `brainstorm-architecture` | Recipe | Wraps `superpowers:brainstorming` at assembly scope; derives `ARCHITECTURE.md` |
| `writing-roadmaps` | Recipe | Runs after `brainstorm-architecture`; breaks design and architecture into phases sized for superpowers loops; produces `ROADMAP.md` |
| `sweep` | Recipe | Seals the ledger and drains it into the living documents |
| `claude-md-guard` | Reference | Admission test for anything entering `CLAUDE.md` |
| `adopting-a-repo` | Recipe | Brownfield: reconstruct living documents from existing code |

A shared reference file holds the **artifact map** — where each kind of fact lives — pointed at by
every recipe, so the map itself has one home.

`claude-md-guard` splits on **provenance, not size**: a file a script rewrites must not be the file a
human curates.

```
skills/claude-md-guard/
  SKILL.md                     # when it fires, the test, input/output shape, pointer to reference
  claude-md-best-practices.md  # vendored rule card + source URLs + date distilled
  scripts/refresh-rule-card    # re-fetches those sections, diffs, reports drift
```

Scripts colocate with the skill they serve, as superpowers does.

### Hooks

| Event | Scope | Behaviour |
|---|---|---|
| `SessionStart` | always | Injects ~110 words positioning dopamine relative to superpowers |
| `PreToolUse` | `Bash` touching `.superpowers/sdd/` | Denies workspace deletion unless a sealed ledger exists |
| `PostToolUse` | `Edit`/`Write` on `CLAUDE.md` | Returns the admission-test verdict as `additionalContext` |

### Scripts

- `seal-ledger` — copies the ledger beside its plan and marks it sealed.
- `sweep-package` — writes the sweep's diff, scoped to the living documents, to a file for the
  verifier, so the diff never enters the controller's context.
- `refresh-rule-card` — re-fetches the two source sections, diffs, reports drift.

### Configuration

A per-repo file declares which paths are the living documents, since the plugin cannot hard-code any
one project's answer. The sweep reports any declared document that is **absent** — `ARCHITECTURE.md`
before there is code to describe is a state, not an error, and naming it once is how the pending
technical brainstorm surfaces without nagging machinery.

## 9. Key mechanisms

### 9.1 The SessionStart injection

Superpowers injects its entire `using-superpowers` skill at every session start: 63 lines, 485 words.
`writing-skills` sets a tighter target for frequently-loaded content — **under 200 words**. Draft, at
108 words:

> **Documentation discipline (add-on to superpowers)**
>
> This project has living documents — listed in the config — that describe the present. **They are
> not updated while you work.** Superpowers' ledger already records what happened during execution;
> that record is the sweep's input, and you do not keep a second one.
>
> If you find yourself about to change a living document mid-execution, record it in the ledger
> instead and let the sweep place it.
>
> At the end of any plan or ad-hoc unit of work, and before the workspace is cleaned up, invoke the
> sweep skill. That is the only moment living documents change.

Every line is phrased as *what dopamine adds on top of what superpowers already does*, so an agent
cannot read it as an instruction to keep a parallel log. The mid-execution line is a conditional on
an observable predicate, not a prohibition.

### 9.2 The seal gate

The hook does not ask *"is this superpowers?"* — provenance is not observable and not the point. It
asks **"does a sealed copy of this ledger exist?"**

- Sealed → allow, silently. A human's `rm -rf` of a drained workspace passes untouched.
- Not sealed → deny, with one line naming the seal command.

No false positives on drained workspaces, no need to detect execution context, and it correctly stops
a human deletion too, since that destroys the same record. Hooks fire inside subagents, so the
controller's own cleanup is covered.

### 9.3 The `CLAUDE.md` admission test

`CLAUDE.md` is drained like a living document but verifies against **two** questions:

1. *Is this still true?* — as everywhere else.
2. *Does this belong here at all?* — the admission test.

The second is what matters. The demo's 516 lines were not false, they were **misfiled**: design
rationale reads perfectly well in `CLAUDE.md` and is simply being paid for on every session while
duplicating `DESIGN.md`. Staleness checking would never have caught it.

Content that fails the test is **routed, not discarded** — it lands in `LESSONS.md` (§9.6). The
guard's weak point is that an agent holding a true fact with nowhere to put it will argue to keep it
in `CLAUDE.md`; a destination turns the test from a rejection into a routing decision and removes the
incentive to fight it.

The standard is Anthropic's own, distilled into the vendored rule card: the per-line test *"Would
removing this cause Claude to make mistakes? If not, cut it"*, the include/exclude table, the
200-line target, "sometimes-relevant belongs in a skill", and the `/doctor` trim pass.

**Why vendored rather than fetched.** Measured: the two source pages are 39,879 and 36,982 bytes, of
which the `CLAUDE.md` guidance is 8% and 7% respectively — roughly 900 usable words inside ~19,000
tokens. `WebFetch` returns whole pages. Fetching on every `CLAUDE.md` edit is therefore the wrong
mechanism; the card carries its source URLs and distillation date, and `refresh-rule-card` checks for
drift off the edit path. The canonical URL has already moved once
(`anthropic.com/engineering/claude-code-best-practices` → 308 →
`code.claude.com/docs/en/best-practices`), which is exactly what the refresh check exists to catch.

**Why `additionalContext` rather than a warning or a block.** From the hooks reference: a hook that
exits 0 sends stderr to the debug log only and **Claude never sees it**, so a plain warning changes
nothing; exit 2 shows stderr to Claude framed as a blocking error; `additionalContext` reaches Claude
as a system reminder beside the tool result with no error framing. The verdict travels as
`additionalContext`. Escalation to exit 2 is available if it proves ignorable.

### 9.4 The sweep's form

`writing-skills` classifies guidance by the failure it addresses, and the finding is measured rather
than stylistic:

| Baseline failure | Right form | Wrong form |
|---|---|---|
| Skips a rule under pressure | Prohibition + rationalization table + red flags | Soft guidance |
| **Complies, but the output has the wrong shape** | **Positive recipe: what the output IS, its parts, in order** | **Prohibition list** |
| Omits a required element | A required slot in the template | Prose reminders |
| Behaviour depends on a condition | Conditional on an observable predicate | Unconditional rule + exemptions |

Our documents *do* get written; they come out accreted, narrative and restating numbers. That is the
second row. The handoff that raised this topic proposed almost entirely prohibitions — no test
counts, never accrete, delete on close — and `writing-skills` reports that in head-to-head tests the
prohibition arm produced **more** unwanted content than even the no-guidance control.

So the sweep skill is a **recipe**, and "nothing to drain" is an explicit, legitimate outcome of that
recipe, conditioned on the ledger holding no drainable entries — not a judgement about whether to
bother. Skipping the sweep entirely is not addressed by prose at all: a skill an agent never invokes
is never read. It is addressed by the injection, the skill's description, and the seal gate.

Two rules that survive from the handoff, restated in the forms above rather than as prohibitions:

- **Change what changed; append only what is genuinely new.** Documents may legitimately grow. The
  demo's growth was pathological because almost none of those lines were new *things*.
- **No metric that changes without the system changing** — the general form of "no test counts",
  sourced from Anthropic's own exclusion of *information that changes frequently*.

### 9.5 How the sweep runs

The sweep is dopamine's own execution→verification cycle, dispatched by the session that ran the
plan. It borrows superpowers' shape — brief, fresh implementer, fresh reviewer that does not trust
the report — and owns every part of it.

**Ordering.** Seal, then drain. The gate (§9.2) makes workspace deletion impossible before a sealed
copy exists, so the drain reads a file that outlives the workspace. The trigger point is the close of
the superpowers loop; nothing breaks if it slips later.

**1. Discovery — one agent, all documents at once.** Its inputs are the sealed ledger and the unit's
diff, never the documents in bulk; it reaches into the documents only along grep terms derived from
those inputs. That is what keeps the sweep O(change). One pass covers every living document, because
the ledger is read once — per-document discovery would re-read it once per document for no gain.

Output is the **sweep brief**, whose entries come in three kinds, plus the grep terms discovery
derived:

- **Edits** — file, line, the current text quoted, the change required.
- **Negatives** — a location checked and deliberately left alone, with the reason.
- **Promotions** — a claim that has recurred, with the `CLAUDE.md` line proposed for it (§9.6).

A located, quoted entry is what makes a sweep reviewable at all; an unlocated instruction cannot be
verified by anyone.

**2. Execution — one implementer, from the brief alone.** Sweep edits are many small same-shape
changes across files, exactly the case superpowers' batching rule covers: one brief listing every
file and its change, reviewed as a single diff.

**3. Verification — a fresh subagent that does not trust the report.** Three verdicts:

- **Placement** — every brief entry has a matching hunk, nothing extra. A listed location the diff
  never touches is a Missing finding.
- **Discipline** — changed what changed rather than appended; landed in the right tier; no number
  describing a run entered a living document; historical records left alone.
- **Drain completeness** — the verdict superpowers has no need for. Its reviewer is deliberately
  diff-scoped because a human-approved plan is the completeness authority; our brief was written
  minutes earlier by an agent with no gate. So the verifier re-derives grep terms from the sealed
  ledger **independently** and checks that every ledger entry is either drained or explicitly ruled
  to have no living-document consequence.

**Fix loop: two rounds.** A sweep edit that fails review twice is usually a defect in the brief — a
mis-located claim, or a document state discovery misread — not an implementer needing a stronger
model, so escalation by model tier buys little. The failure is **propagated, not parked**: the sweep
returns a distinct status to the orchestrator naming which entries failed and what the pattern
suggests, and the orchestrator rules. Parking it silently would leave the living documents wrong with
nothing to signal it.

**The record is the brief.** Discovery writes it, execution annotates outcomes onto it, verification
appends its verdicts, and it is kept beside the sealed ledger as one artifact of one unit of work. No
separate drain record is written: it would restate the ledger, which is the failure this plugin
exists to prevent.

### 9.6 `LESSONS.md`

**What it is.** The destination for content that fails the `CLAUDE.md` admission test but is still
true and worth keeping. That definition is derived from a mechanism that already exists rather than
asserted, and it earns the tier: nothing consults the file as current truth, so staleness costs
nothing and never-verified is honest. Its growth is the price of `CLAUDE.md` staying small, which is
the trade this plugin wants.

**It is reached by grep, not by loading.** So an entry must carry what a future agent would actually
search for: the error text, the symbol, the version number.

**Entry shape.** A dated observation *and* a transferable claim — one to three sentences carrying the
claim, the condition it holds under, the mechanism, and why the obvious move is wrong. That last
clause is what makes it a lesson rather than a note. The demo's own gotchas are the model: a
`footnoteBackLabel` must be a string on the installed `mdast-util-to-hast` 12.3.0, because a function
silently emits no `aria-label` while later majors take one — so current upstream documentation tempts
you exactly wrong.

**Headings are the index, not decoration.** They make discovery's read O(section) rather than O(file),
and are created lazily by whatever files the first entry beneath them.

**No consolidation pass.** Duplicates cost one extra grep hit and staleness costs nothing, so a pass
priced at O(file) has almost nothing to buy — and it could not be expressed as a located brief entry
in any case, leaving the verifier no claim to check.

**Recurrence is the exception, and it is free.** A lesson learned twice is evidence that a line in
`CLAUDE.md` would have prevented the second occurrence, converting repeated future mistakes into one
always-loaded line. Discovery is already reading the destination section to decide append-or-merge, so
a near-identical entry sitting there *is* the recurrence signal, in hand, with no extra read. It
becomes a promotion entry in the brief.

**A promotion is subject to the guard like anything else.** One the admission test rejects stays in
`LESSONS.md`, and the brief records that it was proposed and refused, so the next recurrence does not
re-litigate it.

## 10. Accepted risks

- **The Iron Law is skipped.** `writing-skills` requires baseline pressure scenarios before writing
  any skill. We are not doing that. The consequence is that we are guessing which rationalizations to
  counter, and guidance that feels right can measurably underperform no guidance. Mitigation: lean
  harder on the *form* guidance, which is the measured part. The skill's cheaper micro-test — five
  fresh-context samples against a no-guidance control — remains available for any wording that turns
  out to be load-bearing.
- **The vendored rule card can go stale.** Bounded by `refresh-rule-card` being run occasionally.
  Editorial guidance moves on a scale of months.
- **No ledger outside `subagent-driven-development`.** `executing-plans` and ad-hoc work have none, so
  the sweep falls back to reconstruction there. Acceptable, since those units are smaller; a one-line
  journal instruction for `executing-plans` is the escalation if drains prove thin.
- **Superpowers' terminal-state rule.** `brainstorming`'s architectural path hard-terminates in
  "invoke `writing-plans`, and no other skill." A project-scope brainstorm must not jump straight to
  an implementation plan. The wrapper is the outer skill so its own checklist legitimately continues,
  but this must be worded so the two do not fight — a drafting hazard, named here rather than
  discovered at runtime.

## 11. Deferred

- **In-code comment discipline.** Same disease, different economics: comments are never swept, so the
  journal-and-sweep apparatus has no purchase on them. Their cost is context burn on every read plus
  active misdirection at the moment of editing. The fix is a writing standard applied at generation
  time. It is sequenced after this work because the boundary — **living documents do not restate
  code-level truth, and code does not restate design-level truth** — can only be drawn once the
  living-document contract exists. That boundary belongs in the contract regardless.
- **Further documentation-related capabilities**, unspecified.

## 12. Suggested decomposition

Six skills, three hooks and three scripts are more than one plan should carry. Three slices, each
independently valuable and independently verifiable — the shape `writing-roadmaps` would produce, done
by hand because the plugin does not exist yet:

- **Slice 1 — the spine.** Per-repo config, the `SessionStart` injection, the `sweep` skill with all
  three of its stages, the verifier's prompt, the `seal-ledger` and `sweep-package` scripts, and the
  `PreToolUse` seal gate. This is the entire cost argument realised, and it is usable on an existing
  project the day it lands.
- **Slice 2 — the `CLAUDE.md` guard.** Skill, vendored rule card, `refresh-rule-card`, and the
  `PostToolUse` verdict. It touches nothing slice 1 built, but slice 1's promotion entries (§9.6) are
  proposals with no test to pass until this lands — so until then a promotion is recorded and left
  unapplied rather than written into `CLAUDE.md` ungated.
- **Slice 3 — the authoring skills.** `brainstorm-design`, `brainstorm-architecture`,
  `writing-roadmaps`, `adopting-a-repo`. Needed when a project starts or is adopted, so it is last
  despite being first in the layer model.

## 13. Open questions

1. **The name.** `dopamine` is settled for now and not blocking; it is still open to a better one.

## 14. What this document deliberately does not contain

- **The implementation plan.** That is `writing-plans`' output, next.
- **Skill text.** Drafting the recipes is implementation, not design; only the injection is drafted
  here, because its word budget is a design constraint.
- **Any project-specific configuration.** Paths, budgets and document sets belong in a per-repo config
  file, never in the plugin.
- **History of this design.** The brainstorm that produced it is the record.
