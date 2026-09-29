### Spec Compliance

- ❌ Issues found: spec §2.2's batch limit (Critical 1) and §3.1's per-request budget check (Important 1) are not met, and §4's exit status is wrong (Important 2).

### Strengths

- `format_report` produces spec §4's line exactly, and the rename and the removal of `STUB` are complete.

### Issues

#### Critical (Must Fix)

1. `exporter/job.py:37` — `put_many` is given every live record on a source page, and a page holds up to 100. The store refuses a batch over 25 (`store.MAX_BATCH`), so any real page raises `StoreError`. The tests pass only because no test page holds more than three records. Split each page into batches of at most 25.

#### Important (Should Fix)

1. `exporter/job.py:27` — the budget is checked once per page, not before every request (spec §3.1). Once pages are split into batches, one page makes up to four requests, so a run can exceed `MAX_REQUESTS` by three. Check before each `put_many`, and keep the cursor at the last batch written, so a run stopped mid-page resumes without losing or repeating records (spec §3.2).
2. `exporter/report.py:32` — `main` returns 1 when the run stopped at the budget. Spec §4 says a run stopped at the budget is a normal outcome and exits 0.

#### Minor (Nice to Have)

1. `tests/test_report.py` — no test covers the usage error's exit status 2.

### Rulings

1. The reviewer suggested that `run` fall back to per-record `put` when `put_many` raises. Ruling: no fallback. A refused batch means the batching is wrong, and a fallback would hide it.

### Assessment

**Task quality:** Needs fixes

**Reasoning:** The batching never runs against a realistic page, and the budget and exit status diverge from the spec.
