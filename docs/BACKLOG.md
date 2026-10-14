# Backlog

Ideas for dopamine that are agreed to be worth doing and are **not scheduled**. Each entry says
what it is, why, and what is still open.

**This file is consumed, not maintained.** It is deliberately absent from `.dopamine/config`, so
no sweep reads or verifies it. An entry is deleted when a spec picks it up — the spec carries it
from there — or when it is dropped, with one line saying why in the commit that drops it.

Every entry that changes a skill goes through a RED/GREEN baseline before it ships, as program
design did (`docs/superpowers/plans/2026-10-12-program-design.md`).

Origin of the current entries: a discussion on 2026-10-14 about deep versus shallow modules,
using `heijmans-evaluatie-assistent` as the worked example. Its findings, briefly: the functions
there are deep (`answer_question`, `retrieve`) but the packages are shallow — every internal file
is imported from outside, internal constants leak into callers, and the API and the chat REPL
repeat the same eight-step startup. The shallowness entered **between** phases, each time a later
phase became a new consumer of an earlier package, not inside any one phase.

## Interface decisions

### 1. Resolve the order conflict between architecture and program design

**Problem.** Component interfaces are decided in `brainstorm-architecture` (*How they talk*), but
the choice for deep modules is made afterwards, in `brainstorm-program-design` (*Modules*). The
architecture schema says so explicitly: "the depth of its interfaces included, is
`PROGRAM-DESIGN.md`'s Modules slot". So interfaces are drawn before anyone has decided how deep
they should be.

**Recommendation: split depth by the boundary it applies to.**

- **Depth at a component boundary is an assembly decision** and moves to architecture. *How they
  talk* states, per component, its front door — what it offers its callers and what crosses — and
  `brainstorm-architecture` asks the depth question there, with deep as its recommendation. This
  is also the gap the Heijmans example shows: its *How they talk* documents five seams well
  (Protocols, `StageSink`, `RecordSink`, `domain/events`, the state table) and never states what
  `retrieval/` or `answer/` offer their callers.
- **Depth inside a component stays in program design.** *Modules* keeps how code inside a
  component is split, when a new module, layer or abstraction is allowed — and the checkable rule
  that **enforces** the boundaries architecture drew ("nothing outside a component imports its
  internal modules").

Rejected: running program design before architecture. Program design reads the components as its
input, and its conditional slots trigger off `ARCHITECTURE.md`.

**Touches.** `architecture-schema.md` (the deferral sentence, and what *How they talk* holds),
`brainstorm-architecture`'s scope line, `program-design-schema.md`'s *Modules* question.

### 2. Make *Modules* a required input to the roadmap, with deep as the recommended default

- `writing-roadmaps` reads `PROGRAM-DESIGN.md` "for risk only; its absence blocks nothing", and
  `finishing-work`'s check 7 runs only where the document is present. A project without it gets no
  enforcement at all — Heijmans has none. Require **Modules** answered before a roadmap is
  written; other slots may still be deferred, which the recipe already supports.
- The schema's default for *Modules* currently "pulls both ways". Keep the human's choice — that is
  the recipe's principle — but give it a concrete recommended rule with a diff check, for example:
  *each component exposes its public surface in `__init__.py`; nothing outside imports its other
  modules; widening the surface is a decision made in the plan, not an import.* Check: no added
  line imports another component's submodule, and an import-boundary test stays green.
- **Do not** put an inventory of interfaces into program design. The schema's "rules, never an
  inventory" is right: a list of interfaces would be re-verified at every sweep.

### 3. Roadmap phases name the interface they publish

A phase's **Lands** names the front door it publishes and points to *How they talk* for it — one
line, never the signatures. Heijmans' Phase 4 "chunk, enrich, embed, push" lists internals; the
consumer phases that came later had nothing to hold them to.

### 4. Raise interface specifics with the human inside the superpowers loop

**Where specifics belong.** *What* a component offers is decided at architecture time; the
signatures, names and error types are decided in the spec of the phase that **builds the
providing component**; after that the code — a public `__init__.py` with docstrings, guarded by the
boundary test — is the source of truth. A consuming phase never redesigns an interface quietly.

**Does superpowers raise them on its own?** Partly, and not reliably (superpowers 6.4.1):

- `brainstorming` classifies "changes that … alter interfaces others depend on" as architectural,
  so a second consumer widening an interface does get the full spec path.
- Its *Design for isolation* section asks whether a unit can be understood without reading its
  internals — but it also says "break the system into smaller units", the pull towards shallow
  that the *Modules* schema already notes.
- `writing-plans` has a per-task **Interfaces** block with exact signatures — but those are
  task-to-task contracts written by the plan's author, seen by the human only inside the plan
  review, not put to them as a question.

**Proposal.** A small injection, not a new skill: when a phase **creates or widens** a front door
named in *How they talk*, its brainstorm puts the signatures to the human as their own question
before the spec is written — design it twice, recommend one. Carrying it via the *Modules* rule
into each plan's Global Constraints reuses the mechanism program design already added. Baseline
first: measure how often the unmodified loop raises the question unprompted.

## Living projects

Dopamine was built for one scoped deliverable worked towards an end. A product that keeps
growing after production needs an entry point after delivery and protection against slow
erosion. Much already works: `brainstorm-design`, `brainstorm-architecture` and
`brainstorm-program-design` revise in place, and the roadmap re-orders at each close.

### 5. A feature-intake recipe — needs its own design discussion first

**Idea.** Something like `dopamine:adding-a-feature`: a short triage of a new request against the
existing documents, whose central question is the deep-modules payoff made into process.

| The feature… | Goes |
|---|---|
| fits inside one component, front door unchanged | straight into a superpowers loop, no roadmap entry |
| changes or adds a front door | `brainstorm-architecture` revises *How they talk* first, then the loop |
| is large or cuts across components | new phases appended to the roadmap |

**Revisit before building — this split is agreed, the recipe is not.** Still to decide together:

- **Which steps** the recipe takes, in what order, and what it reads to triage (only *How they
  talk* and *The assembly*, or `DESIGN.md` too?).
- **What its brainstorm looks like.** Is it a dopamine wrapper around `superpowers:brainstorming`
  like the other recipes, at what scope, and which classification — and how it relates to
  superpowers' own bounded/architectural split, which already overlaps the table above.
- **Which documents a feature passes through**: when it revises `DESIGN.md` (what the system is),
  when `ARCHITECTURE.md`, when `PROGRAM-DESIGN.md`, and when none.
- **How the roadmap handles it** — see entry 6: does a feature always become a phase, and what is
  a phase's exit when the product is already live?
- Whether intake is a recipe at all, or a section of the `SessionStart` injection pointing an
  ordinary brainstorm at the right documents.

### 6. The roadmap for a product that keeps growing

- **Value as a third ordering force**, named per phase like dependency and risk: a backlog of
  features is a choice, and dependency and risk do not make it.
- **A rolling horizon.** The roadmap holds the next few increments, not the product's whole future.
- **Archive closed phases per release.** Struck-through phases with ledger pointers accumulate
  for as long as the product lives; for a long-lived product that is O(project) in a living
  document. Move them to a per-release archive and keep the roadmap short.

### 7. A rule for changing a front door that has more than one consumer

The conditional **Public surface** slot fires only when outsiders consume the system. A growing
product needs the same discipline internally: changing a front door with more than one consumer
means migrating every consumer in the same plan, or deprecating the old shape explicitly. A
ledger entry that changes a front door is routed by the sweep to *How they talk*.

### 8. Catch erosion per change, at `finishing-work`

Shallowness arrives one reach-in at a time, during feature work. A `finishing-work` check over the
diff — **new** imports of another component's internals — catches each at the moment it happens,
at O(change). Deliberate deepening work then comes from parked ledger findings, not occasional
audits of the whole codebase.
