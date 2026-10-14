# `ARCHITECTURE.md` — slots

The assembly that realises `DESIGN.md`, in the present tense.

| Slot | Holds |
|---|---|
| **The assembly** | Each component in one line: what it owns, and what it must never own |
| **How they talk** | How deep the components are, what each offers its callers and what must hold at its interface, and the seams between them — below |
| **Where state lives** | Every store, and which component is authoritative for what in it |
| **When it fails** | What each failure looks like from outside, and what is retried, dropped or surfaced |
| **What runs where** | Processes, jobs, and the boundaries a deployment has to respect |
| **Not this** | Assemblies considered and rejected, with the reason each was rejected |

## How they talk

Three things, in this order:

1. **The depth principle** — one line for the whole project: how much a component hides behind what it offers. Recommend deep: callers use what a component offers, never how it does its work. Each **named exception** carries its reason; a package of shared types that every component imports by design is the usual one.
2. **One row per component:**

   | Component | Offers its callers | Must hold |
   |---|---|---|
   | retrieval | retrieve: a question and an optional filter → ranked evaluations; facets: the allowed filter values | — |
   | answer | answer: a question in a mode → one turn's result, with citations | a mode and its config never disagree: callers pass the mode only |

   *Offers its callers* is operations and data in domain words, never types or signatures, so it changes only when what the component offers changes. *Must hold* is the values that must never disagree and what a caller must not be able to do, or `—`: what a signature cannot be chosen well without. The table grows with the components **The assembly** lists, and with nothing else.
3. **The seams** between components, and which way each dependency points.

A number that describes the system now — a size limit, a timeout, a budget — belongs here as a bounded set, replaced when it changes. A number that describes one run belongs in the sealed ledger and is cited from here rather than copied into it.

Component boundaries follow from what the system is for, so a change here that contradicts `DESIGN.md` is a finding for `DESIGN.md` first.

Depth **at** a component's boundary, and what the component offers, is decided here. How that boundary is enforced in code, and when a new module, layer or abstraction is admitted, is `PROGRAM-DESIGN.md`'s **Modules** slot; how code is arranged inside a component is its **Layout** slot.
