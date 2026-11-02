# Glossary sweep micro-test

Does finishing-work's glossary text change what a sweep does to the glossary? Arm C loads dopamine from `main` (4871420), whose finishing-work says nothing about a glossary. Arm G loads this branch. Both close the same unit of work: `tests/baselines/glossary/sweep/`, where the leadflow fixture with the GREEN glossary overlay gets three task commits. The ledger introduces **dormant**, renames `legacy_band` (cold's pointer) and retires **cooldown**. Sonnet, 5 runs per arm, run 2026-11-02 on the subscription login.

Reproduce: `bash tests/baselines/glossary/sweep/run-sweep RUNS C <main checkout> N`, the same with `G <this branch>`, then `bash tests/baselines/glossary/sweep/score-sweep RUNS`.

| Run | Cost | Turns | dormant added | cold re-pointed | cooldown retired | check clean | ran check | sweep commit |
|---|---|---|---|---|---|---|---|---|
| C-1 | $0.1139 | 10 | y | y | y | y | n | y |
| C-2 | $0.1231 | 12 | y | y | y | y | n | y |
| C-3 | $0.1123 | 9 | y | y | y | y | n | y |
| C-4 | $0.1172 | 9 | y | y | y | y | n | y |
| C-5 | $0.1211 | 9 | y | y | y | y | n | y |
| G-1 | $0.1140 | 9 | y | y | y | y | y | y |
| G-2 | $0.1075 | 8 | y | y | y | y | y | y |
| G-3 | $0.1127 | 8 | y | y | y | y | y | y |
| G-4 | $0.1118 | 8 | y | y | y | y | y | y |
| G-5 | $0.1229 | 9 | y | y | y | y | y | y |

| Arm | Mean cost | Turns | Extra entry `dismissed` |
|---|---|---|---|
| C | $0.1175 ± 0.0046 | 9.8 | 4/5 |
| G | $0.1138 ± 0.0056 | 8.4 | 0/5 |

Every glossary diff was read by hand.

## Verdict

- **The drain itself needs no guidance.** All five control sweeps added dormant, re-pointed cold and deleted cooldown, and left the glossary clean. A declared glossary that holds the ledger's terms is reached by the generic drain along those terms.
- **What the text changes is admission and the check.** Four of the five control sweeps also added a **dismissed** entry ("a lead sales dismissed; it never returns to the portal feed"), whose meaning reads off its name in one read of `portal_feed`. That fails the admission test, and no G sweep added it. Only G ran `check-glossary` (5/5 against 0/5).
- **No cost regression:** G − C is −$0.0037 per sweep, inside the noise at n = 5.
- **Not tested:** a second name for a listed concept, the judgement the text asks for along the ledger's terms.
