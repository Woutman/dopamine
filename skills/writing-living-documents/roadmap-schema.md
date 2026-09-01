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
