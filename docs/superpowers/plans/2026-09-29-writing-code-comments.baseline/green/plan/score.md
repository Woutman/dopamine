| arm | runs | why | contract | warning | narration | bloat | restatement | bad per run | comment share | labelled | stale kept |
|---|---|---|---|---|---|---|---|---|---|---|---|
| L0p | 5 | 13.6 | 13.6 | 0.0 | 0.0 | 1.6 | 0.6 | 1, 3, 3, 0, 4 | 10% | 6 | 0/5 |
| L1p | 5 | 6.6 | 12.6 | 0.0 | 0.0 | 0.0 | 0.0 | 0, 0, 0, 0, 0 | 9% | 0 | 3/5 |

## Pass criteria (Task 6, Step 9)

| Criterion | L1p | L1x |
|---|---|---|
| 1. The failure is gone: at most 1 ruling comment across 5 runs | 0 (L0p: 4) — pass | 0 (L0x: 3) — pass |
| 2. Bad comments stay rare: bad-per-run sum at most 2 | 0 (L0p: 11) — pass | 0 (L0x: 10) — pass |
| 3. Useful comments survive: why + contract per run at least half of L0's | 19.2 against 27.2, floor 13.6 — pass | 16.8 against 25.2, floor 12.6 — pass |

**GREEN passes.** No REFACTOR round.

## Findings outside the criteria

- **The stale comment came back.** `# row numbers are stable because a station never rewrites a file it has exported` (fixture `readings/parse.py`), which the legacy-phase spec counts among the comments its decisions make false, is kept in 3 of 5 L1p plans (L1p-2, 4, 5) and 2 of 5 L1x executions (L1x-4 ← L1p-2, L1x-1 ← L1p-5), against 0 of 5 in each L0 arm. L1p-1 also carries it in the plan, outside the lines the stale check reads. The executions keep it because their plans do.
- **Why comments halved.** 13.6 → 6.6 per plan run, 12.8 → 5.6 per execution. Contract comments held (13.6 → 12.6, 12.4 → 11.2). Criterion 3 passes on the sum.
- **Plans got shorter.** 6 of 8 L1p plans had 3–4 tasks, against 5 in every L0p; they fold the calibration deletion into a neighbouring task. The sample is the first five plan runs, accepted on every check but the five-task minimum (ledger ruling); the replacement runs are kept outside the pool.
- **No process labels.** 0 labelled comments in either L1 arm, against 6 in each L0 arm.
