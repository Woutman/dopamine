# Reconstructed ledger — 2026-11-02-glossary-second-name

Reconstruction, 2026-11-02, from the conversation: ad-hoc follow-up on PR #12, with no plan and no superpowers ledger.

- Ask (user): micro-test the sweep's second-name judgement; leave finishing-work's "introduces, renames or retires" sentence as it is.
- tests/baselines/glossary/sweep/ split into scenario directories (dormant, masked), chosen with SCENARIO, default dormant so the dormant record's reproduce lines still run.
- Result: docs/superpowers/plans/2026-11-02-glossary.baseline/sweep/second-name.md. Both arms recognise masked as withheld (10/10); only G records it on withheld's line (10/10 against 0/10).
- Cost flag: G − C = +$0.0071 per sweep (se $0.0021) after a confirming second batch, over the $0.005 line, with equal turns; it goes to reading glossary-schema.md, running check-glossary and rewriting an existing line.
- Ruling (user): not a regression — the $0.005 line compares arms of equal correctness, and here the control gets the outcome wrong 10/10; the extra cost is the price of the right outcome — cost if wrong: about $0.007 more per sweep that reaches the glossary.
- Raw runs: ~/glossary-sweep-masked.
