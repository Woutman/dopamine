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
