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
