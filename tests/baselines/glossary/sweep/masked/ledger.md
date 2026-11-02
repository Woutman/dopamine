# SDD ledger — plan: docs/superpowers/plans/2026-11-04-masked-export.md
Pre-flight: no shared interfaces
Task 1: Ruling: a masked lead exports with an empty score rather than a zero, so a partner cannot read it as a low score — cost if wrong: one column's format.
Task 1: complete (commits {C0}..{C1}, tests: python3 -m unittest → OK)
Final review: clean, no findings.
