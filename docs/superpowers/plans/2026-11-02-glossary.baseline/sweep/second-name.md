# Glossary sweep micro-test: a second name

Does finishing-work's text make a sweep record a second name for a listed concept on that concept's line? Same arms as `../sweep/score.md`: C loads dopamine from `main` (4871420), G this branch. Scenario `masked` in `tests/baselines/glossary/sweep/`: one task adds `is_masked` to the partner CSV export, re-implementing the glossary's **withheld** rule. The plan and ledger name `masked` and never `withheld`. Sonnet, two batches of 5 runs per arm (the second confirming a cost flag on the first), run 2026-11-02 on the subscription login.

Reproduce: `SCENARIO=masked bash tests/baselines/glossary/sweep/run-sweep RUNS C <main checkout> N`, the same with `G <this branch>`, then `SCENARIO=masked bash tests/baselines/glossary/sweep/score-sweep RUNS`.

| Run | Cost | Turns | masked on withheld's line | no separate masked entry | a masked entry names withheld | check clean | ran check | sweep commit |
|---|---|---|---|---|---|---|---|---|
| C-1 | $0.0974 | 8 | n | n | y | y | n | y |
| C-10 | $0.1001 | 7 | n | n | y | y | n | y |
| C-2 | $0.0924 | 7 | n | n | y | y | n | y |
| C-3 | $0.1134 | 12 | n | n | y | y | n | y |
| C-4 | $0.1057 | 8 | n | n | y | y | n | y |
| C-5 | $0.1072 | 9 | n | n | y | y | n | y |
| C-6 | $0.1074 | 8 | n | n | y | y | n | y |
| C-7 | $0.0990 | 7 | n | n | y | y | n | y |
| C-8 | $0.1010 | 7 | n | n | y | y | n | y |
| C-9 | $0.1054 | 8 | n | n | y | y | n | y |
| G-1 | $0.1049 | 8 | y | y | n | y | y | y |
| G-10 | $0.1101 | 8 | y | y | n | y | y | y |
| G-2 | $0.1073 | 9 | y | y | n | y | y | y |
| G-3 | $0.1095 | 8 | y | y | n | y | y | y |
| G-4 | $0.1092 | 8 | y | y | n | y | y | y |
| G-5 | $0.1124 | 8 | y | y | n | y | y | y |
| G-6 | $0.1115 | 9 | y | y | n | y | y | y |
| G-7 | $0.1108 | 8 | y | y | n | y | y | y |
| G-8 | $0.1141 | 8 | y | y | n | y | y | y |
| G-9 | $0.1096 | 7 | y | y | n | y | y | y |

| Arm | Mean cost, batch 1 | Batch 2 | All 10 | Turns |
|---|---|---|---|---|
| C | $0.1032 ± 0.0083 | $0.1026 ± 0.0036 | $0.1029 ± 0.0061 | 8.1 |
| G | $0.1087 ± 0.0028 | $0.1112 ± 0.0017 | $0.1099 ± 0.0026 | 8.1 |

Every glossary diff was read by hand.

## Verdict

- **Both arms see that masked is withheld (10/10 each); only G records it on withheld's line (10/10 against 0/10).** Every C sweep added a separate `masked` entry, most of them calling it "the export's counterpart of withheld", so a grep for withheld never reaches the export's name. Nine G sweeps wrote `(UI: "Neutraal"; partner export: "masked")`; one put it in the meaning, which a grep still finds.
- **G costs $0.0071 more per sweep (standard error $0.0021), over the $0.005 per-question line, with equal turns.** It goes to reading `glossary-schema.md` (9/10 G runs), running `check-glossary` (10/10), and rewriting an existing line rather than appending one. In the dormant scenario G was $0.0037 cheaper.
