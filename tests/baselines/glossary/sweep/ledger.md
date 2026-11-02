# SDD ledger — plan: docs/superpowers/plans/2026-11-03-dormant.md
Pre-flight: no shared interfaces
Task 1: Ruling: a lead never contacted is not dormant — dormant means sales tried and stopped, and a never-contacted nurture lead is still untried — cost if wrong: untried leads stay in the nurture queue.
Task 1: complete (commits {BASE1}..{TASK1}, tests: python3 -m unittest → OK)
Task 2: Ruling: the backfill rows' key is renamed with the function (`legacy_band` → `backfill_band`), since the job's consumers read both — cost if wrong: one downstream key to alias.
Task 2: complete (commits {TASK1}..{TASK2}, tests: python3 -m unittest → OK)
Task 3: Ruling: COOLDOWN_DAYS deleted rather than kept at 0, so nothing reads a setting that no longer does anything — cost if wrong: one constant to restore.
Task 3: complete (commits {TASK2}..{TASK3}, tests: python3 -m unittest → OK)
Final review: clean, no findings.
