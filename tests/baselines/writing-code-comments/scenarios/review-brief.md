### Task 1: Batch writes and the run report

**Spec:** `docs/superpowers/specs/2026-01-08-exporter-design.md`

**Files:**
- Modify: `exporter/job.py`, `exporter/report.py`
- Test: `tests/test_job.py`, `tests/test_report.py`

**Requirements:**
- `run` writes with `store.put_many`, in batches of at most 25 (spec §2.2), under the request budget and cursor rules of spec §3.1 and §3.2.
- `PAGE_SIZE` becomes `SOURCE_PAGE_SIZE` (spec §2.2).
- `exporter/report.py` implements the run report of spec §4, and its `STUB` marker and placeholder test go.
- Test each behaviour; `python3 -m unittest` passes.
