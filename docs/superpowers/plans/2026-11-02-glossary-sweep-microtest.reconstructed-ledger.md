# Reconstructed ledger — 2026-11-02-glossary-sweep-microtest

Reconstruction, 2026-11-02, from the conversation: ad-hoc follow-up on PR #12, with no plan and no superpowers ledger.

- Ask (user): micro-test finishing-work's glossary text, which superpowers:writing-skills requires and the rules-over-mechanism spec's ruling had skipped.
- Built tests/baselines/glossary/sweep/ (setup-sweep, run-sweep, score-sweep, change/, ledger.md); tooling tests in tests/scripts/test-glossary-baseline.sh.
- Ruling: arm C loads main (4871420) through --plugin-dir rather than this branch with the paragraph cut, so the control is what ships today — cost if wrong: the other glossary text on this branch (routing row, schema) is credited to finishing-work.
- Result: docs/superpowers/plans/2026-11-02-glossary.baseline/sweep/score.md. Control drains all three ledger terms unprompted; the text's effect is admission (an extra `dismissed` entry 4/5 C, 0/5 G) and running check-glossary (0/5 C, 5/5 G). No cost regression.
- Raw runs: ~/glossary-sweep (and ~/glossary-sweep-smoke, one per arm).
