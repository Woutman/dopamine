# Task 1 report

**Status:** DONE

- `run` now collects each page's live records and writes them with one `put_many`; drafts are counted as skipped. `PAGE_SIZE` is renamed `SOURCE_PAGE_SIZE`.
- `report.main` reads the records file, runs one export and prints the report line; `STUB` and its test are removed.
- Tests: 6/6 passing with `python3 -m unittest`.

Files changed: `exporter/job.py`, `exporter/report.py`, `tests/test_job.py`, `tests/test_report.py`.
