# Export job Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A nightly job that copies records from the source to the store within a request budget.

**Architecture:** In-memory stand-ins for the source and the store, and one `run` function that pages
through the source and writes to the store.

**Tech Stack:** Python 3, unittest.

**Spec:** `docs/superpowers/specs/2026-01-08-exporter-design.md`

**Not in this plan:** batch writes (spec §2.2) and the run report (spec §4). They follow in the next plan.

---

### Task 1: Source and store stand-ins

**Files:**
- Create: `exporter/source.py`, `exporter/store.py`

- [x] **Step 1:** Write `Source.page(after, size)` and `Store.put(key, record)`, each counting requests.
- [x] **Step 2:** Commit.

### Task 2: The export loop

**Files:**
- Create: `exporter/job.py`
- Test: `tests/test_job.py`

- [x] **Step 1: Write the failing tests** for drafts and the request budget.
- [x] **Step 2: Implement `run`**

```python
def run(source, store, cursor=""):
    result = RunResult(cursor=cursor)
    while True:
        page = source.page(result.cursor, PAGE_SIZE)
        if not page:
            return result
        for record in page:
            if record["status"] == "draft":
                result.skipped += 1
            else:
                if store.requests >= MAX_REQUESTS:
                    result.stopped_by_budget = True
                    return result
                store.put(record["id"], record)
                result.exported += 1
            result.cursor = record["id"]
```

- [x] **Step 3:** Run `python3 -m unittest`; expect OK. Commit.

### Task 3: Resume from a cursor

**Files:**
- Modify: `exporter/job.py`
- Test: `tests/test_job.py`

- [x] **Step 1:** Test that a run given a cursor starts after it.
- [x] **Step 2:** Run `python3 -m unittest`; expect OK. Commit.
