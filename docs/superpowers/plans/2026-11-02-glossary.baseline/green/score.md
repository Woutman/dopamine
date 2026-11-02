# Glossary GREEN — 2026-11-02

70 runs: 7 term questions × arms C (dopamine's SessionStart hook, no glossary) and G (the same hook, a declared `docs/GLOSSARY.md` and its pointer) × 5, Sonnet, on `tests/baselines/glossary/fixture/` with `green-overlay/` for G. The working tree was switched to `main` mid-batch; the 20 G runs for q4–q7 that had not started were rerun from a worktree of the same commit, so every run used the same hook.

| Arm | Runs | Correct | Mean $ ± sd | Cache write | Cache read | Out | Turns | Searched |
|---|---|---|---|---|---|---|---|---|
| C | 35 | 34/35 | 0.0707 ± 0.0091 | 13191 | 106242 | 726 | 6.9 | 0/35 |
| G | 35 | 33/35 | 0.0641 ± 0.0089 | 12600 | 80001 | 572 | 5.1 | 35/35 |

| Task / arm | Runs | Correct | Mean $ ± sd | Cache write | Cache read | Out | Turns | Searched |
|---|---|---|---|---|---|---|---|---|
| q1-koud C | 5 | 5/5 | 0.0697 ± 0.0104 | 12915 | 97533 | 831 | 6.4 | 0/5 |
| q1-koud G | 5 | 5/5 | 0.0654 ± 0.0033 | 12385 | 91992 | 662 | 5.6 | 5/5 |
| q2-geen-fit C | 5 | 4/5 | 0.0736 ± 0.0063 | 13743 | 102000 | 837 | 6.4 | 0/5 |
| q2-geen-fit G | 5 | 3/5 | 0.0718 ± 0.0015 | 13323 | 103372 | 816 | 5.8 | 5/5 |
| q3-withheld C | 5 | 5/5 | 0.0702 ± 0.0044 | 13259 | 109452 | 623 | 6.4 | 0/5 |
| q3-withheld G | 5 | 5/5 | 0.0572 ± 0.0002 | 11945 | 62097 | 323 | 4.0 | 5/5 |
| q4-unresolved C | 5 | 5/5 | 0.0810 ± 0.0018 | 13852 | 140346 | 1150 | 11.4 | 0/5 |
| q4-unresolved G | 5 | 5/5 | 0.0808 ± 0.0051 | 14729 | 111867 | 1064 | 7.8 | 5/5 |
| q5-opted-out C | 5 | 5/5 | 0.0785 ± 0.0060 | 14300 | 110380 | 1023 | 7.4 | 0/5 |
| q5-opted-out G | 5 | 5/5 | 0.0574 ± 0.0017 | 11898 | 57076 | 409 | 3.8 | 5/5 |
| q6-stale C | 5 | 5/5 | 0.0639 ± 0.0004 | 12241 | 111915 | 376 | 6.0 | 0/5 |
| q6-stale G | 5 | 5/5 | 0.0587 ± 0.0015 | 11954 | 71761 | 367 | 4.4 | 5/5 |
| q7-cooldown C | 5 | 5/5 | 0.0577 ± 0.0024 | 12025 | 72066 | 238 | 4.4 | 0/5 |
| q7-cooldown G | 5 | 5/5 | 0.0577 ± 0.0003 | 11969 | 61839 | 360 | 4.0 | 5/5 |

## Verdict

| Criterion | Bar | Measured | Result |
|---|---|---|---|
| Correctness | 35/35, or no task below C | Scorer: C 34/35, G 33/35. By hand: 35/35 each | **Pass** |
| Cost | C − G > 1.65 × √(sd_C²/35 + sd_G²/35) | 0.0707 − 0.0641 = **$0.0066** against 1.65 × 0.00215 = $0.0035 | **Pass** |
| Regression | no task with G − C > $0.005 | largest G − C is $0.0000 (q7); every other task is cheaper under G | **Pass** |

**Correctness by hand.** The three runs the scorer marks wrong are all q2 (C-3, G-3, G-4), and each names the `excluded` band and quotes `LeadBand.EXCLUDED`. They open with a lead-in ("The leads labelled…", "\"Geen fit\" is the excluded band…"), which the scorer's starts-with match does not accept. Every run in both arms answered correctly.

**Use.** All 35 G runs touched the glossary (`Searched` 35/35), C none. The saving is largest where RED's gap was largest: withheld (q3) and opted-out (q5) save about $0.02 each, and cooldown (q7) and unresolved (q4) save nothing.

**Against RED.** G saves $0.0066 per question, about 9% of C. RED put the most a glossary could save at $0.015 (21%), with the definitions handed over in the prompt.
