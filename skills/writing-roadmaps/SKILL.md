---
name: writing-roadmaps
description: Use when a design and an architecture are settled and the order of the work is not yet decided, when a project has no ROADMAP.md, or when a phase has closed and what remains needs re-ordering
---

# Writing roadmaps

## Overview

`superpowers:writing-plans` breaks a spec into **tasks** sized for one execution loop. This breaks a design and an architecture into **phases** sized for one superpowers loop — and the loop is the unit: each phase is one spec, one plan, one execution, one sweep.

**A phase is the smallest unit that makes one good plan.** `writing-plans` requires a plan to produce working, testable software on its own; a phase inherits that requirement whole — independently valuable, independently verifiable.

**REQUIRED BACKGROUND:** Use dopamine:routing-documentation-updates — `ROADMAP.md` is a living document, re-read and re-verified at every phase close, and what that costs decides what is allowed into it.

## The recipe

### 1. Locate the output and read the two inputs

`${CLAUDE_PLUGIN_ROOT}/skills/sweep/scripts/artifact-paths --tier living` gives all three. The roadmap is the declared path whose basename is `ROADMAP.md`; where no declared path matches, ask which one is meant rather than creating a second. `DESIGN.md` says what must exist; `ARCHITECTURE.md` says what depends on what. With either absent the phases would be guesses — run dopamine:brainstorm-design and dopamine:brainstorm-architecture first. Exit 3 means the repository has not adopted dopamine — run dopamine:adopting-a-repo first.

### 2. Order by dependency and risk, and say which one placed each phase

Two forces set the order, and every phase's position is one or the other:

- **Dependency** — B cannot be built until A exists.
- **Risk** — A carries an unknown that invalidates later work if it turns out badly, so it is proven early and cheaply. A vertical slice that proves a pattern with a hello-world is the standard shape: finding the pattern broken there costs a day, and finding it later, inside a half-built component, costs a week and does not say which half is at fault.

An order set by neither is a preference, and a preference does not survive contact with a schedule.

### 3. Write the phases

The phase slots, and the document's own, are declared in `${CLAUDE_PLUGIN_ROOT}/skills/writing-living-documents/roadmap-schema.md`.

Use dopamine:writing-living-documents. It holds that schema and the rules for writing into it.

### 4. Name what the project cannot do for itself

Anything the work waits on from outside — an access grant, an approval, a decision by another team — earns a row in **External asks**. Asked early it is off the critical path; asked late it is the critical path.

### 5. Strike a closed phase, and leave a pointer

A closed phase stays, **struck through**, its body replaced by one link to its sealed ledger under the `plans:` tier, written relative to the roadmap's own directory so it survives the docs moving as a unit:

`~~**Phase 2 — The spine**~~ — [ledger](<plans>/2026-08-28-dopamine-spine.ledger.md)`

The ledger is immutable, so the trail cannot rot; its header names the plan, which names the spec, and the sweep brief sits beside it. `dopamine:sweep` has no concept of a phase, so re-running this recipe at each close is what strikes it.

**The struck line holds the name and the link, and nothing else** — no `Lands`, no `Exit`, no measured number: what asserts something about the present is defended at every sweep, and a bare pointer asserts nothing. What changed the system goes to `DESIGN.md` or `ARCHITECTURE.md`; what a run measured stays in the ledger, cited.

## Outcomes

| The inputs hold | This recipe produces |
|---|---|
| A settled design and architecture | `ROADMAP.md` at the declared path: what drives the order, the phases, and the external asks |
| An architecture still open on one component | The phases up to that question, and the question named as what unblocks the rest |
| A phase that has just closed | It is struck through above its ledger pointer, its outcome placed, and the remaining order re-decided if what closed changed it |

## Common mistakes

- **Dates and durations.** They change without the system changing, which is exactly the metric the artifact model excludes. Sequence is by dependency; a phase becomes available when its predecessors' exits are met.
- **Implementation detail inside a phase.** A phase names what lands, not how. The how is the spec and the plan that phase produces when it starts.
- **A phase whose exit nobody can observe.** It never closes, so it stays in the document, and the document stops describing the present.
