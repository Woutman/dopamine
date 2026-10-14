# Dopamine — module depth

> **Status.** Design settled 2026-10-14.
>
> **Builds on** `2026-10-12-program-design-design.md`. No new document and no new skill: this
> changes what existing slots ask for, and when the roadmap may be written.

## 1. What this is

A deep module hides a lot of work behind a small interface; a shallow one makes its callers know
nearly as much as it does. Deep modules suit agentic work: an agent reads less to use a component,
has fewer contracts to get wrong, and a change stays behind one interface.

Dopamine currently leaves module depth undecided until it is too late to shape the interfaces.
Component interfaces are drawn in `brainstorm-architecture`, but how deep they should be is
deferred to `PROGRAM-DESIGN.md`'s **Modules** slot, which runs afterwards and whose schema says only
that the question "pulls both ways". And the roadmap may be written without program design at all.

The worked example is `heijmans-evaluatie-assistent`. Its functions are deep (`answer_question`,
`retrieve`), but its packages are shallow: every internal file is imported from outside, internal
constants leak into callers, and the API and the chat REPL repeat one eight-step startup. The
shallowness entered **between** phases — each time a later phase became a new consumer of an
earlier package, it reached into that package rather than the package offering what it needed. Its
*How they talk* documents five seams well and never states what `retrieval/` or `answer/` offer
their callers.

## 2. Scope

| In | Out |
|---|---|
| Depth at a component's boundary decided in architecture, with what each component offers and what must hold at its interface | Support for products that keep growing after production — `docs/BACKLOG.md` |
| A recommended, checkable Modules rule, which also catches erosion per diff through `finishing-work` check 7 | Asking the human about interface signatures in the superpowers loop — dropped; the model chooses them from what architecture now records |
| Modules required before a new roadmap; roadmap phases name the interface they publish | Any change to `finishing-work` itself |
| The adoption survey recording interfaces and reach-ins | Restructuring any real project |

## 3. The pieces

### 3.1 Architecture — depth at the boundary

**`architecture-schema.md`.** *How they talk* holds three things:

1. **The depth principle**, one line, for the whole project, with any **named exceptions** and the
   reason for each — a shared-types package imported everywhere by design is the usual one.
2. **One row per component**:

   | Component | Offers its callers | Must hold |
   |---|---|---|
   | retrieval | retrieve: a question and an optional filter → ranked evaluations; facets: the allowed filter values | — |
   | answer | answer: a question in a mode → one turn's result, with citations | a mode and its config never disagree: callers pass the mode only |

   *Offers its callers* is operations and data in domain words, with **no types**, so it changes
   only when what the component offers changes. *Must hold* records values that must never disagree
   and what callers must not be able to do, or `—`. This is what a signature cannot be inferred
   without: in Heijmans, `answer_question` takes a mode and its config as two arguments, so a caller
   can pass a mismatched pair — the model chose a plausible signature because nothing recorded that
   the two must agree.
3. **Cross-cutting seams and dependency direction**, as today.

The deferral sentence becomes:

> Depth **at** a component's boundary, and what the component offers, is decided here. How that
> boundary is enforced in code, and when a new module, layer or abstraction is admitted, is
> `PROGRAM-DESIGN.md`'s **Modules** slot; how code is arranged inside a component is its **Layout**
> slot.

The table grows with components, which *The assembly* already lists, so it adds no new kind of
inventory.

**`brainstorm-architecture`.** Stage 2's scope adds: *what each component offers its callers, what
must hold at each interface, and how deep the boundaries are — recommending deep, with exceptions
named.* Stage 4 names `PROGRAM-DESIGN.md` before `ROADMAP.md`, and why: the roadmap requires its
Modules slot.

### 3.2 Program design — enforcing the boundary, admitting abstractions

**`program-design-schema.md`.** The Modules question becomes:

> Where does each component's public surface live and how is a reach-in caught, and when is a new
> module, layer or abstraction admitted?

Its default column states what superpowers does: it pulls towards smaller units. The schema gains a
worked Modules example beside the Errors one, carrying the recommended rules:

- **Rule (boundary):** A component's public surface is its `__init__.py`; code outside a component
  imports only what that exports, except from a component `ARCHITECTURE.md` names as an exception.
  *Check:* no added import from outside a component reaches past its `__init__.py`; every name
  added to or removed from a public surface is named in the plan.
- **Rule (admission):** A new module, layer or abstraction is added only when it hides something
  its callers would otherwise handle.
  *Check:* no added function or class whose body only forwards to one other call; no added
  `Protocol` or base class with a single implementation — a test fake counts as a second one.

The surface's location is the rule's variable part: a project may name an `api.py` instead, as
Heijmans would, whose `__init__.py` files avoid re-exports for import cost.

**`brainstorm-program-design`.** Reads *How they talk* before asking Modules, so the rule enforces
the boundaries architecture drew rather than re-deciding them. Modules stays always asked: the
admission half still pulls against superpowers.

**Erosion per diff.** `finishing-work` is unchanged. Check 7 already judges a diff's added lines
against each rule's check, so the boundary rule catches every new reach-in and every silent
widening at the close that introduced it.

### 3.3 Roadmap

**`writing-roadmaps`, stage 1.** Where `PROGRAM-DESIGN.md` is absent or its Modules slot is
deferred:

- **writing a roadmap, or adding phases** — stop, and run `dopamine:brainstorm-program-design`
  first, as an absent `ARCHITECTURE.md` already stops it;
- **striking a closed phase, or re-ordering what remains** — proceed, and name Modules as pending
  in one line, so a project part-way through its roadmap keeps closing phases.

Stage 2's line keeps program design's risk use — an unproven rule may justify an early vertical
slice — and drops "its absence blocks nothing".

**`roadmap-schema.md`, Lands.** Where a phase builds or widens a component, one line names the
interface it publishes and points to *How they talk*, without restating its operations.

### 3.4 Adoption

**`survey-prompt.md`.** The architecture row also reads *what each component's callers actually
import from it* and *every import that reaches past a component's public surface*, recorded as
**Read** findings with `path:line`.

**`adopting-a-repo`, stage 4.**

- *Offers its callers* is filled from what callers actually use.
- *Must hold* is rarely readable from code, so it goes to *Reconstructed, unconfirmed*.
- **The depth principle is never written by adoption.** It is a choice, as program-design rules are.
- Each reach-in becomes a **Question**: *widen X's interface, or move this caller onto what X
  already offers?*

### 3.5 Housekeeping

- README rows for `brainstorm-architecture`, `brainstorm-program-design` and `writing-roadmaps`.
- `.claude-plugin/plugin.json` to 0.1.5.
- `docs/BACKLOG.md`: the erosion bullet is dropped, with one line saying its per-diff half now lives
  in the Modules rule.
- `tests/skills/test-authoring-skills.sh:112` asserts "read for risk only" — it changes in the task
  that changes the wording.

## 4. Baseline

Behavioural arms only where a model's judgement decides the outcome; the other changes are wording
whose effect is predictable, asserted by static tests. Lean on purpose: about a quarter of program
design's runs.

### Fixture

`tests/baselines/module-depth/fixture/`, about 120 lines of Python in three packages — `fetch/`,
`store/`, `notify/` — and a shared `types.py`, the exception candidate. Planted:

- **two reach-ins**: `cli` imports a `store` internal helper, `notify` imports `fetch`'s parsing
  internals;
- **one invariant** in `DESIGN.md`: a notification channel and its message format never disagree;
- **a feature spec** — digests need each feed's last error, which today lives only inside `store`.

`blind` and `score` are **copied** from `tests/baselines/program-design/`, not generalised. The
GREEN prompt renderer is committed. Lessons carried from the last baseline: unique temp paths per
run and no writes outside the run's repository; no `.pyc` and no unannotated tests in the fixture;
blinding scrubs stage and run labels; the judge gets its rubric readings spelled out up front.

### Control and treatment

RED runs the current skills with documents in the shape the current schemas produce — no component
table, Modules the inherited default. GREEN runs the changed skills with documents in the new
shape. P and X therefore compare what dopamine produces, not only a skill's wording.

### Arms

| Arm | RED / GREEN | Run | Columns |
|---|---|---|---|
| **P** plan, second consumer | 3 / 3 | `writing-plans` on the digest feature | reaches in · widens deliberately, named in the plan · stops to ask |
| **X** gate | 3 / 3 | `finishing-work` check 7 over a diff with one reach-in, one pass-through wrapper and one legitimate import through a public surface | reach-in flagged · wrapper flagged · misflagged |
| **A** architecture, pre-answered | 3 / 3 | One turn: the brainstorm's answers supplied, the run derives `ARCHITECTURE.md` | interface table · exception named · invariant in *Must hold* |

### Static tests

In `run-tests.sh`, asserting the rule is written where it must be: the roadmap's block-new and
warn-at-close cases; the Lands interface line; the Modules question and both recommended rules with
their checks; the survey's interface and reach-in reading; adoption never writing the depth
principle.

### Judging

One fresh judge per arm reads RED and GREEN together, blinded, with only the items and the rubric;
the key stays closed until every verdict is filled. Three judges in all.

### Pass criteria

- **RED, at the human's checkpoint:** an arm whose control already scores 3/3 on its main column
  drops its item from scope.
- **GREEN:** each main column 3/3, or 2/3 with no run below its control. At most one refactor round,
  re-running only the failing arm and re-judging its whole pool.
- An arm worse than its control is a regression: micro-test a fix, never record it as a known gap.

About 18 runs and 3 judges, roughly 45 minutes of runs. Results are measurements of a run and go in
the plan's ledger.

## 5. Rulings

**Ruling: depth at the boundary moves to architecture** — keeping all depth in program design would
leave one place for it. Against: interfaces would still be drawn before their depth was decided, the
conflict this resolves. **Cost if wrong:** two documents to read to know a component's depth; *How
they talk* points at Modules to keep them joined.

**Ruling: a project default with named exceptions, not per component** — per-component answers
would be most precise. Against: a question per component whose answer is almost always the same;
and a default with no exceptions flags every diff that touches a shared-types package. **Cost if
wrong:** a component that should differ is noticed at the first check-7 flag and named then.

**Ruling: operations and data, no types** — signature-like entries would be closer to the code.
Against: they drift on every rename and make the sweep re-verify them; the code is the source of
truth for signatures. **Cost if wrong:** a plan has to read the code to learn exact parameters,
which it does anyway.

**Ruling: block a new roadmap, warn at a close** — always blocking is simpler to state. Against: a
project part-way through its roadmap without program design could not close its next phase.
**Cost if wrong:** a project keeps closing phases without the rule; the pending line names it at
every close.

**Ruling: no signature question in the superpowers loop** — asking would catch a poor signature
before it lands. Against: given *Offers* and *Must hold*, choosing signatures is within the model's
reach, and asking every time costs the human more than it returns. **Cost if wrong:** a poor
signature reaches review; arm P's GREEN runs are where one would show.

**Ruling: a lean baseline** — every change behaviourally tested at n=5 would measure more. Against:
roughly four times the runs, for changes whose effect is a written rule. **Cost if wrong:** a rule
that is written but not followed goes unmeasured until real use shows it.
