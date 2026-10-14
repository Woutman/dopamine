# Dopamine — program design

> **Status.** Design settled 2026-10-12.
>
> **Builds on** `2026-09-01-dopamine-rules-over-mechanism-design.md`: rules first, mechanism only
> where rules demonstrably fail. The artifact model gains one living document; nothing else in it
> changes.

## 1. What this is

Nothing installed decides the shape of code — its types, signatures, layout and call stacks.
Superpowers states principles (one purpose per unit, small focused files, split by responsibility)
and checks that names and signatures stay consistent across a plan's tasks; reviews then judge the
result by taste. So each plan's author settles these questions afresh, inside the first narrow plan
that meets them, and the next plan copies the precedent.

This adds a fourth living document, `PROGRAM-DESIGN.md`, derived in its own brainstorm after the
architecture one, that records the project's program-design rules — and the plumbing that carries
those rules into plans and checks them at the close.

**What was asked.** The program-design decisions made explicit at project scope, with the human
choosing them, not decided by the model in the first plan that needs one. Both goals count equally:
consistency across plans, and overriding the model's defaults where they are weak. Language-agnostic,
with Python taking precedence where the two conflict. The superpowers loop is not to be overloaded.
The skill is written with `superpowers:writing-skills`.

**What was assumed and confirmed through the brainstorm.** The document holds rules, never an
inventory of the code's types or modules; superpowers' existing positions are presented as defaults
rather than re-decided; deep versus shallow modules is decided here, not in `ARCHITECTURE.md`.

## 2. What superpowers already settles

| Slot | Superpowers' position | Settled? |
|---|---|---|
| Types | Names and types consistent across tasks | No |
| Errors | Bans "add appropriate error handling" as a plan placeholder | No — requires handling, not its shape |
| Effects | TDD: "must mock everything → use dependency injection"; test-only code stays out of production classes | Partly |
| Signatures | Consistent across tasks | No |
| Layout | Split by responsibility, not technical layer; files that change together live together; smaller focused files; follow existing patterns | Mostly — import direction is open |
| Modules | One clear purpose; understandable without reading internals; YAGNI; DRY without premature abstraction | Partly, and pulling both ways: the encapsulation test leans deep, "smaller units" leans shallow |

Where a position exists, the brainstorm offers it as the default. Depth is never inherited
silently: left unasked, superpowers' pull toward small units decides it.

## 3. Scope

- **Only in adopted repositories**, and only where `PROGRAM-DESIGN.md` is declared in
  `.dopamine/config`.
- **Rules, not inventory.** A list of the project's actual types or modules describes the code, grows
  with it, and is O(project) to verify. Rules are checked against the diff, which keeps the gate
  O(change).
- **Out of scope:** naming and formatting (linters and defaults own them) and component boundaries
  (`ARCHITECTURE.md` owns them).

## 4. The pieces

| Piece | Change |
|---|---|
| `tests/baselines/program-design/` | New. Fixture, prompts, blinding script. Kept for re-runs; not in `run-tests.sh` |
| `skills/brainstorm-program-design/SKILL.md` | New. The recipe |
| `skills/writing-living-documents/program-design-schema.md` | New. The slots |
| `skills/writing-living-documents/SKILL.md` | Fourth table row; description names `PROGRAM-DESIGN.md` |
| `skills/writing-living-documents/architecture-schema.md` | One sentence: component interfaces follow the Modules slot |
| `skills/brainstorm-architecture/SKILL.md` | Step 4 names `PROGRAM-DESIGN.md` as pending beside `ROADMAP.md` |
| `skills/writing-roadmaps/SKILL.md` | Step 2 reads `PROGRAM-DESIGN.md`, when present, for risk only |
| `skills/routing-documentation-updates/SKILL.md` | A program-design rule is a prescription for this document, never `CLAUDE.md` or `LESSONS.md` |
| `skills/adopting-a-repo/` | Fourth survey and the handoff (§4.5) |
| `hooks/session-start-context.md` | One sentence (§4.3) |
| `skills/finishing-work/SKILL.md` | Exit gate gains a seventh check |
| `tests/` | Structure and injection tests extended |
| `README.md` | Skill table row; fourth `living:` line in the config example |
| `.dopamine/config` | Declares `docs/PROGRAM-DESIGN.md`, absent like its siblings |
| `.claude-plugin/plugin.json` | Version bump |

The baseline comes first and gates everything after it (§5).

### 4.1 The schema

`program-design-schema.md` declares the slots, in this order.

**Core slots** — answered for every project:

| Slot | The question |
|---|---|
| **Types** | How are domain concepts represented, and where is input turned into them? |
| **Errors** | How do failures travel, and who handles them? |
| **Effects** | Where do I/O and mutation live, and how do dependencies get in? |
| **Signatures** | What shape do functions and methods take? |
| **Layout** | How is code arranged inside a component, and which way do imports point? |
| **Modules** | How much must a module hide behind its interface, and when is a new module, layer or abstraction allowed? |

**Conditional slots** — each asked up front when its trigger fires:

| Slot | Trigger |
|---|---|
| **Concurrency** | `ARCHITECTURE.md`'s "What runs where" holds more than one process, worker or job, or the design needs async or parallel I/O |
| **Persistence** | A store in "Where state lives" whose schema will change over time |
| **Public surface** | `DESIGN.md` says the system is consumed as a library or API by others |

**Project slots** — zero or more, each opening with why it exists.

**Not this** — conventions considered and rejected, each with its reason.

**An entry** in a slot is one of two forms:

- **Inherited default** — one line naming superpowers' position, where the human kept it.
- **Rule** — the rule; why, in one line; and **how to check a diff against it**. A rule with no
  check is not admitted, because the gate and the plan's reviewers have nothing to apply.

About one page. Present tense; a changed rule is replaced, not appended.

**Python first.** The slot questions are language-neutral. Recommendations and examples are written
for Python, and where general advice and Python idiom disagree, the idiom wins — for example a
project exception hierarchy over Result types, keyword-only parameters over parameter objects,
`Protocol` over ABCs, `NewType`/dataclasses with Pydantic at boundaries.

### 4.2 The recipe — `dopamine:brainstorm-program-design`

The `brainstorm-architecture` wrapper, one level down.

1. **Locate input and output.** The declared `living:` path whose basename is `PROGRAM-DESIGN.md`
   is the output; `DESIGN.md` and `ARCHITECTURE.md` are the input. An absent `ARCHITECTURE.md`
   stops the recipe: run `dopamine:brainstorm-architecture` first. No matching declared path: ask
   which is meant.
2. **Settle the slots.** Core slots always. Evaluate each conditional trigger against the inputs and
   state which fired and why, one line each; the human adds or drops any. Determine the language
   from `ARCHITECTURE.md` or the code; ambiguous or mixed means Python precedence.
3. **Read observed practice**, only where code exists: a sample per slot, not the repository. Each
   becomes a candidate answer with where it was seen; contradictions are shown as both.
4. **Brainstorm per slot**, through `superpowers:brainstorming`, one slot at a time. Each question
   shows superpowers' default where one exists, observed practice where there is code, a
   recommendation, and one or two alternatives with their trade-offs. **The human picks.** No slot
   is filled unanswered; "take the recommendations for the rest" is an answer and is recorded as
   one. Modules is always asked.
5. **Derive the document** with `dopamine:writing-living-documents` against the schema; the spec
   stays frozen.
6. **Name what is pending** — `ROADMAP.md` if absent.

**Revision.** On an existing document the recipe revises slots in place: current rule, observed
practice, what changed; the human decides. A gap raised by a plan (§4.3) runs this path for that one
slot.

### 4.3 Reaching plans and implementers

**Injection** — one sentence beside the comment sentence:

> When writing a plan's File Structure, Interfaces or Global Constraints, read the `PROGRAM-DESIGN.md`
> declared in `.dopamine/config`. A structural choice it does not settle stops the plan: put it to the
> human and record the answer through `dopamine:brainstorm-program-design` before continuing.

**Absent document.** Declared but absent: the plan's author asks the human once whether to run the
recipe now. If the human declines, the plan proceeds as it would today — no rules, no gap stops —
and its Global Constraints say so in one line. Without this, declaring the document would block
every plan until the brainstorm ran.

**Global Constraints.** The plan's author copies the rules applicable to this plan into the plan's
Global Constraints, verbatim, one line each: rule and check, without the why. Superpowers' per-task
reviewer receives that section as its attention lens, so violations surface per task. Implementers
and reviewers never load the document.

**What counts as a gap.** A structural choice in a slot the document leaves open, or in an area no
slot covers. A choice the document answers, even indirectly, is not a gap.

### 4.4 The exit gate

`finishing-work` gains:

7. **Added lines of `git diff <base>...HEAD` follow `PROGRAM-DESIGN.md`'s rules**, each judged by
   its own check.

The backstop for work outside a plan. A deviation the human approved during the work is a rule
change, and drains into the document in place.

### 4.5 Adoption

`adopting-a-repo` declares `living: docs/PROGRAM-DESIGN.md`, runs a fourth `survey-prompt.md`
subagent that samples observed practice per slot, and **writes nothing into the document**: it hands
off to `brainstorm-program-design` with the findings as step 3's input. Even a consistently followed
convention is only a candidate — the code shows what was done, not what was chosen — so this
document has no derived body and no `Reconstructed, unconfirmed` section.

### 4.6 The roadmap

`writing-roadmaps` still requires only `DESIGN.md` and `ARCHITECTURE.md`; program design creates no
dependencies between phases. When `PROGRAM-DESIGN.md` is present, step 2 reads it for **risk**: a
rule not yet proven in this project may justify an early vertical slice, named as that phase's
"Why here".

## 5. Baseline

The RED phase `writing-skills` requires, run **before the skill is written**. If its controls come
back clean, no skill is written.

### Fixture

A small Python project in a scratch repository: `DESIGN.md`; `ARCHITECTURE.md` with one worker
process, so the Concurrency trigger should fire; ~150 lines of code mixing two error conventions,
giving observed practice with a contradiction; and a feature request that needs a plan. A gap
variant carries a `PROGRAM-DESIGN.md` without a Concurrency slot and a feature that needs a
background job.

### Arms

| Stage | Arm | Setup | Measured | Runs |
|---|---|---|---|---|
| RED | **R0** recipe, no skill | "Derive PROGRAM-DESIGN.md from these documents" | Writes rules without asking? | 5 |
| RED | **P0** plan author, no document | `writing-plans` on the feature | Per-slot structural choices, and their spread across runs | 5 |
| GREEN | **R1** recipe with skill | R0 plus the recipe, first turn only | Stops at the first slot question with all four elements; writes nothing | 5 |
| GREEN | **P1** plan author with document and injection | P0 plus `PROGRAM-DESIGN.md` and the injection | Applicable rules in Global Constraints; Interfaces comply with each rule's check | 5 |
| GREEN | **G** gap | P1 on the gap variant | Stops and puts the concurrency question to the human | 5 |
| GREEN | **X** gate | `finishing-work` over a diff with one planted violation | Check 7 flags it | 5 |

### Judging

The main session judges, **blinded**: arm labels stripped, outputs shuffled, classifications written
to a file before the key is opened. P1 compliance is judged with each rule's own check — the first
test of whether "how to check a diff against it" is workable.

### Pass criteria

- **RED shows a problem** when R0 writes rules without asking in at least 4 of 5 runs, or P0's runs
  disagree on at least 2 slots. Otherwise stop.
- **GREEN passes** when R1 asks before writing in 5 of 5; P1 carries the applicable rules and its
  Interfaces comply in at least 4 of 5 each; G stops and asks in at least 4 of 5; X flags the
  violation in at least 4 of 5.
- An arm worse than its control is a regression: micro-test a fix, never record it as a known gap.

Results are measurements of a run and go in the plan's ledger.

## 6. Rulings

**Ruling: a separate document, not slots in `ARCHITECTURE.md`** — slots there would avoid a fourth
document. Against: it would double a document re-verified at every sweep, and mix what the pieces
are with how code inside them is shaped, which change at different rates. **Cost if wrong:** one more
recipe to run and one more document to declare per project.

**Ruling: a gap stops the plan** — a provisional choice flagged for the sweep would never block
planning. Against: a narrow plan would set the precedent the human wanted to set, and the next plan
would copy it. **Cost if wrong:** planning is interrupted often; arm G measures how reliably it stops,
and frequent stops in real use mean the schema is missing a slot.

**Ruling: rules reach implementers through Global Constraints** — the finishing-work gate alone would
keep the superpowers loop untouched. Against: violations would surface only at the close, and the
comment work found implementers follow only what the plan hands them. **Cost if wrong:** the plan's
author omits a rule and per-task review misses it until the gate; arm P1 measures how often.

**Ruling: adoption writes nothing into the document** — writing consistent observed practice as
derived would give adopted repositories a document at once. Against: it would record what the code
did as what the human chose. **Cost if wrong:** an adopted repository plans without rules until the
brainstorm runs — bounded by the absent-document path in §4.3.

**Ruling: Python takes precedence** — a strictly neutral skill would serve every language equally.
Against: the user's projects are mostly Python, and neutral advice conflicts with Python idiom on
errors, signatures and interfaces. **Cost if wrong:** recommendations in other languages lean
Pythonic; the human corrects them at the slot question.
