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

### 1. Locate the output and read the two inputs

`skills/sweep/scripts/artifact-paths --tier living` gives all three. The roadmap is the declared path whose basename is `ROADMAP.md`; where no declared path matches, ask which one is meant rather than creating a second. `DESIGN.md` says what must exist; `ARCHITECTURE.md` says what depends on what. With either absent the phases would be guesses — run dopamine:brainstorm-design and dopamine:brainstorm-architecture first.

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
| A settled design and architecture | `ROADMAP.md` at the declared path: what drives the order, the phases, and the external asks |
| An architecture still open on one component | The phases up to that question, and the question named as what unblocks the rest |
| A phase that has just closed | It is deleted and its outcome placed, and the remaining order re-decided if what closed changed it |

## Common mistakes

- **Dates and durations.** They change without the system changing, which is exactly the metric the artifact model excludes. Sequence is by dependency; a phase becomes available when its predecessors' exits are met.
- **Implementation detail inside a phase.** A phase names what lands, not how. The how is the spec and the plan that phase produces when it starts.
- **A phase whose exit nobody can observe.** It never closes, so it stays in the document, and the document stops describing the present.
