# Glossary RED — 2026-11-02

70 runs: 7 term questions × arms A (definitions found in the code) and O (definitions in the prompt) × 5, Sonnet, on `tests/baselines/glossary/fixture/`. q2 was reworded and its 10 runs rerun after the first wording drew prose answers; the scorer accepts an answer followed by its reasoning.

| Arm | Runs | Correct | Mean $ ± sd | Cache write | Cache read | Out | Turns |
|---|---|---|---|---|---|---|---|
| A | 35 | 35/35 | 0.0696 ± 0.0129 | 13363 | 97446 | 635 | 6.5 |
| O | 35 | 35/35 | 0.0548 ± 0.0096 | 11669 | 50996 | 304 | 3.9 |

| Task / arm | Runs | Correct | Mean $ ± sd | Cache write | Cache read | Out | Turns |
|---|---|---|---|---|---|---|---|
| q1-koud A | 5 | 5/5 | 0.0656 ± 0.0056 | 13042 | 80338 | 533 | 4.8 |
| q1-koud O | 5 | 5/5 | 0.0569 ± 0.0049 | 11438 | 70270 | 406 | 4.8 |
| q2-geen-fit A | 5 | 5/5 | 0.0669 ± 0.0033 | 12252 | 108536 | 702 | 6.4 |
| q2-geen-fit O | 5 | 5/5 | 0.0523 ± 0.0032 | 10894 | 58015 | 295 | 3.8 |
| q3-withheld A | 5 | 5/5 | 0.0728 ± 0.0189 | 14324 | 101583 | 534 | 6.0 |
| q3-withheld O | 5 | 5/5 | 0.0480 ± 0.0034 | 10740 | 36512 | 142 | 3.0 |
| q4-unresolved A | 5 | 5/5 | 0.0768 ± 0.0013 | 13225 | 131800 | 1065 | 10.2 |
| q4-unresolved O | 5 | 5/5 | 0.0654 ± 0.0030 | 12437 | 85243 | 715 | 6.4 |
| q5-opted-out A | 5 | 5/5 | 0.0823 ± 0.0112 | 15590 | 98398 | 1013 | 8.0 |
| q5-opted-out O | 5 | 5/5 | 0.0592 ± 0.0210 | 13983 | 19214 | 136 | 2.4 |
| q6-stale A | 5 | 5/5 | 0.0581 ± 0.0045 | 11300 | 93927 | 354 | 5.4 |
| q6-stale O | 5 | 5/5 | 0.0515 ± 0.0023 | 11072 | 46144 | 262 | 3.4 |
| q7-cooldown A | 5 | 5/5 | 0.0645 ± 0.0189 | 13808 | 67542 | 248 | 4.4 |
| q7-cooldown O | 5 | 5/5 | 0.0503 ± 0.0012 | 11115 | 41574 | 172 | 3.2 |
