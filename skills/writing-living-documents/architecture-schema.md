# `ARCHITECTURE.md` — slots

The assembly that realises `DESIGN.md`, in the present tense.

| Slot | Holds |
|---|---|
| **The assembly** | Each component in one line: what it owns, and what it must never own |
| **How they talk** | The interface between each pair, and which way the dependency points |
| **Where state lives** | Every store, and which component is authoritative for what in it |
| **When it fails** | What each failure looks like from outside, and what is retried, dropped or surfaced |
| **What runs where** | Processes, jobs, and the boundaries a deployment has to respect |
| **Not this** | Assemblies considered and rejected, with the reason each was rejected |

A number that describes the system now — a size limit, a timeout, a budget — belongs here as a bounded set, replaced when it changes. A number that describes one run belongs in the sealed ledger and is cited from here rather than copied into it.

Component boundaries follow from what the system is for, so a change here that contradicts `DESIGN.md` is a finding for `DESIGN.md` first.
