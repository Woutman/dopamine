### c001 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
> """The export job: copies records from the source to the store within a request budget."""
  
  from dataclasses import dataclass
  
```

### c002 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
          self.assertEqual((result.requests, result.cursor), (2, "r049"))
  
      def test_budget_used_up_by_the_last_batch_is_not_a_stop(self):
>         """Needing no further request is completion, even with the budget spent."""
          store = Store()
          records = live_records(50) + [record("r050", "draft"), record("r051", "draft")]
          with mock.patch.object(job, "MAX_REQUESTS", 2):
```

### c003 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
              records = json.load(file)
      except OSError as error:
          raise UsageError(f"cannot read {path}: {error.strerror or error}")
>     except ValueError as error:  # JSONDecodeError and UnicodeDecodeError
          raise UsageError(f"{path} is not valid JSON: {error}")
      if not isinstance(records, list):
          raise UsageError(f"{path} must hold a JSON array of records")
```

### c004 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
      def test_the_budget_counts_only_this_runs_requests(self):
          store = RecordingStore()
>         store.requests = job.MAX_REQUESTS  # requests an earlier run made against the same store
          result = job.run(Source(numbered(30)), store)
          self.assertFalse(result.stopped_by_budget)
          self.assertEqual((result.exported, result.requests), (30, 2))
```

### c005 — exporter/job.py

```python
  
  
  def _flush(store, result, batch, drafts, last_id):
>     """Write `batch` and move the cursor to `last_id`; False if the budget stops the write."""
      if batch:
          if store.requests >= MAX_REQUESTS:
              result.stopped_by_budget = True
```

### c006 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
> """Command-line entrypoint: runs one export over a JSON file of records and prints its report."""
  
  import json
  import sys
```

### c007 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
          )
  
      def test_draft_inside_an_unwritten_batch_is_not_counted(self):
>         """A stop leaves every record after the cursor uncounted, drafts included."""
          store = Store()
          records = live_records(26) + [record("r026", "draft"), record("r027")]
          with mock.patch.object(job, "MAX_REQUESTS", 1):
```

### c008 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
          return str(path)
  
      def main(self, *args):
>         """Run report.main on `args`; return (exit code, stdout, stderr)."""
          out, err = io.StringIO(), io.StringIO()
          with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
              code = report.main(list(args))
```

### c009 — tests/test_job.py

```python
          self.assertEqual((result.exported, result.cursor), (50, "r049"))
  
      def test_trailing_drafts_are_dealt_with_at_the_budget(self):
>         """Drafts after the last written batch need no request, so the cursor passes them."""
          store = Store()
          records = [record(f"r{i:03}") for i in range(25)] + [record("s", "draft")]
          with mock.patch.object(job, "MAX_REQUESTS", 1):
```

### c010 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def numbered(count, drafts=()):
>     """Records r000, r001, ... up to count-1, in id order; the numbers in `drafts` are drafts."""
      return [record(f"r{n:03d}", "draft" if n in drafts else "live") for n in range(count)]
  
  
```

### c011 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  class BudgetTest(unittest.TestCase):
      def test_stops_at_the_request_budget(self):
>         """The run stops before the request that would exceed the budget, and says so."""
          store = Store()
          with mock.patch.object(job, "MAX_REQUESTS", 2):
              result = job.run(Source(live_records(60)), store)
```

### c012 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def _records_after(source, after):
>     """Every record after `after`, in id order, read from the source a page at a time."""
      while True:
          page = source.page(after, SOURCE_PAGE_SIZE)
          if not page:
```

### c013 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
                  self.assertEqual((result.exported, result.requests), (count, requests))
  
      def test_batch_spans_source_pages(self):
>         """Page ends do not force a write, and the next page is read after the last record read."""
          store = Store()
          with mock.patch.object(job, "SOURCE_PAGE_SIZE", 10):
              result = job.run(Source(live_records(30)), store)
```

### c014 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
          )
  
      def test_budget_is_counted_per_run(self):
>         """A run resumed against the same store gets its own budget."""
          store = Store()
          source = Source(live_records(30))
          with mock.patch.object(job, "MAX_REQUESTS", 1):
```

### c015 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def _write(store, pending, result):
>     """Write the live records in `pending` in one request and count all of `pending` as dealt with.
> 
>     Returns False, having written and counted nothing, when the budget allows no further request.
>     """
      if result.requests >= MAX_REQUESTS:
          result.stopped_by_budget = True
          return False
```

### c016 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
          self.assertEqual((len(store.records), result.cursor), (50, "r050"))
  
      def test_spending_the_budget_exactly_is_not_a_stop(self):
>         """Trailing drafts need no request, so they are skipped rather than stopping the run."""
          store = Store()
          records = live_records(50) + [record("r051", "draft"), record("r052", "draft")]
          with mock.patch.object(job, "MAX_REQUESTS", 2):
```

### c017 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def run(source, store, cursor=""):
>     """Export every record after `cursor` with put_many, making at most MAX_REQUESTS store requests.
> 
>     The result's cursor is the id of the last record dealt with, written or skipped, so the next
>     run resumes after it and neither loses nor repeats a record.
>     """
      result = RunResult(cursor=cursor)
      # Records read but not yet dealt with. It always starts with a live record, so a draft that
      # follows an unwritten record waits with it and the cursor never passes an unwritten record.
```

### c018 — exporter/job.py

```python
      The result's cursor is the id of the last record dealt with, so the next run resumes after it.
      """
      result = RunResult(cursor=cursor)
>     # Records read but not yet dealt with: the live ones waiting to be written, and the drafts read
>     # after the first of them. A draft is dealt with only once every live record before it is written,
>     # so a run that stops at the budget never moves the cursor past an unwritten record.
      batch = []
      batch_drafts = 0
      batch_last_id = cursor
```

### c019 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
      run resumes after it and neither loses nor repeats a record.
      """
      result = RunResult(cursor=cursor)
>     # Records read but not yet dealt with. It always starts with a live record, so a draft that
>     # follows an unwritten record waits with it and the cursor never passes an unwritten record.
      batch = []
      for record in _records_after(source, cursor):
          if not batch and _is_draft(record):
```

### c020 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def format_report(result):
>     """The one-line report of spec §4."""
      return (
          f"exported={result.exported} skipped={result.skipped} requests={result.requests} "
          f"stopped_by_budget={'yes' if result.stopped_by_budget else 'no'} cursor={result.cursor}"
```

### c021 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
      nor repeats a record.
      """
      result = RunResult(cursor=cursor)
>     # Pages are read after the last record read, which runs ahead of the cursor while
>     # records wait in `pending` for their batch.
      read_after = cursor
      # Records read but not yet dealt with, in id order. The first is always live: a draft
      # with nothing ahead of it is dealt with at once.
```

### c022 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
          self.assertEqual((result.skipped, result.requests, result.cursor), (3, 0, "r002"))
  
      def test_a_batch_spans_source_pages(self):
>         """A batch filled from several source pages is written once, and no record is read twice."""
          store = Store()
          with mock.patch.object(job, "SOURCE_PAGE_SIZE", 7):
              result = job.run(Source(numbered(["live"] * 60)), store)
```

### c023 — tests/test_job.py

```python
          self.assertEqual((len(store.records), result.exported, store.requests), (60, 60, 3))
  
      def test_budget_is_checked_before_every_request_within_a_page(self):
>         """A run stopped mid-page keeps the cursor at the last batch written; resuming loses and repeats nothing."""
          records = [record(f"{i:03}") for i in range(60)]
          store = Store()
          with mock.patch.object(job, "MAX_REQUESTS", 2):
```

### c024 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
> """The export job: copies records from the source to the store within a request budget."""
  
  from dataclasses import dataclass
  
```

### c025 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
          self.assertEqual(result.requests, store.requests - before)
  
      def test_a_run_stopped_by_the_budget_is_resumed_by_the_next(self):
>         """Runs against one store, each starting at the last cursor, deal with every record exactly once."""
          records = numbered(["live"] * 118 + ["draft"] * 2)
          store = Store()
          cursor, exported, skipped, stops = "", 0, 0, 0
```

### c026 — tests/test_job.py

```python
          self.assertEqual((result.exported, store.requests), (60, 3))
  
      def test_never_exceeds_the_budget_within_a_page(self):
>         """A run stopped mid-page keeps the cursor at the last batch written, and a second run finishes."""
          records = [record(f"r{i:03d}") for i in range(60)]
          store = Store()
          with mock.patch.object(job, "MAX_REQUESTS", 2):
```

### c027 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
> """The export job: copies records from the source to the store within a request budget."""
  
  from dataclasses import dataclass
  
```

### c028 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def run(source, store, cursor=""):
>     """Export every record after `cursor` with put_many, making at most MAX_REQUESTS store requests.
> 
>     The result's cursor is the id of the last record written or skipped, so the next run resumes
>     after it: records read into a batch the budget stopped from being written are not passed.
>     """
      result = RunResult(cursor=cursor)
      # Records read but not yet dealt with; the first, if any, is live.
      pending = []
```

### c029 — exporter/report.py

```python
> """Command-line entrypoint: runs one export and prints its report.
> 
> Usage: python3 -m exporter.report RECORDS_JSON [CURSOR]
> """
  
  import json
  import sys
```

### c030 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  class RecordsError(Exception):
>     """The records file cannot be read, or does not hold a list of records."""
  
  
  def main(argv=None):
```

### c031 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  class RecordingStore(Store):
>     """A Store that keeps the keys of each batch it writes, and refuses single-record puts."""
  
      def __init__(self):
          super().__init__()
```

### c032 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def run(source, store, cursor=""):
>     """Export every record after `cursor`, making at most MAX_REQUESTS store requests.
> 
>     The result's cursor is the id of the last record dealt with, so the next run resumes after it.
>     """
      result = RunResult(cursor=cursor)
      while True:
          page = source.page(result.cursor, SOURCE_PAGE_SIZE)
```

### c033 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
      def test_a_stop_leaves_the_cursor_before_the_first_unwritten_record(self):
          """A draft read while nothing waits is dealt with; a draft behind an unwritten record is not."""
          store = RecordingStore()
>         # r000-r024 fill the one allowed batch; r025 is a draft with nothing waiting;
>         # r026 is live and waits for a batch that the budget refuses; r027 is a draft behind it.
          with mock.patch.object(job, "MAX_REQUESTS", 1):
              result = job.run(Source(numbered(28, drafts={25, 27})), store)
          self.assertTrue(result.stopped_by_budget)
```

### c034 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def run(source, store, cursor=""):
>     """Export every record after `cursor` with put_many, in batches of at most MAX_BATCH.
> 
>     Drafts are skipped. The run makes at most MAX_REQUESTS store requests of its own and stops,
>     setting stopped_by_budget, rather than exceed them. The result's cursor is the id of the last
>     record dealt with, written or skipped, and only records up to it are counted, so the next run
>     resumes after it and loses and repeats nothing.
>     """
      result = RunResult(cursor=cursor)
      # Records read but not yet dealt with. It always starts with a live record: a draft read while
      # it is empty is dealt with at once, and one read after it waits for the batch to be written.
```

### c035 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
          self.dir = tmp.name
  
      def records_file(self, records=None, text=None):
>         """Write `records` as JSON, or `text` verbatim, and return the file's path."""
          path = os.path.join(self.dir, "records.json")
          with open(path, "w", encoding="utf-8") as f:
              f.write(json.dumps(records) if text is None else text)
```

### c036 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
          return path
  
      def main(self, *argv):
>         """Run report.main and return (exit code, stdout, stderr)."""
          stdout, stderr = io.StringIO(), io.StringIO()
          with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
              try:
```

### c037 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  class RunTest(unittest.TestCase):
      def test_exports_live_records_and_skips_drafts(self):
>         """Drafts are counted as skipped and never written."""
          store = Store()
          result = job.run(Source([record("a"), record("b", "draft"), record("c")]), store)
          self.assertEqual(sorted(store.records), ["a", "c"])
```

### c038 — exporter/job.py

```python
  
  
  def run(source, store, cursor=""):
>     """Export every record after `cursor`, stopping before the store would exceed MAX_REQUESTS.
> 
>     Each source page is written in batches of at most MAX_BATCH records, one request per batch. The
>     result's cursor is the id of the last record dealt with, so the next run resumes after it.
>     """
      result = RunResult(cursor=cursor)
      while True:
          page = source.page(result.cursor, SOURCE_PAGE_SIZE)
```

### c039 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def live_records(count):
>     """`count` live records whose ids sort in the order they were made: r0000, r0001, ..."""
      return [record(f"r{index:04d}") for index in range(count)]
  
  
```

### c040 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
      resumes after it and loses and repeats nothing.
      """
      result = RunResult(cursor=cursor)
>     # Records read but not yet dealt with. It always starts with a live record: a draft read while
>     # it is empty is dealt with at once, and one read after it waits for the batch to be written.
      pending = []
      live = 0
      last_read = cursor
```

### c041 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
> """The export job: copies records from the source to the store within a request budget."""
  
  from dataclasses import dataclass
  
```

### c042 — tests/test_job.py

```python
          self.assertEqual(result.cursor, f"r{2 * MAX_BATCH - 1:04d}")
  
      def test_run_stopped_at_budget_loses_and_repeats_nothing(self):
>         """Drafts among unwritten records are left for the next run, so none is counted twice."""
          all_records = records(MAX_BATCH + 5)
          all_records[MAX_BATCH + 1]["status"] = "draft"  # read, but after the budget ran out
          all_records[3]["status"] = "draft"
```

### c043 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
              records = json.load(f)
      except OSError as error:
          raise UsageError(f"cannot read {path}: {error.strerror}") from error
>     except ValueError as error:  # JSONDecodeError, or bytes that are not UTF-8
          raise UsageError(f"{path} is not valid JSON: {error}") from error
      if not isinstance(records, list):
          raise UsageError(f"{path} must hold a JSON array of records")
```

### c044 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  class BudgetTest(unittest.TestCase):
      def test_stops_at_the_request_budget(self):
>         """The run stops before the request that would exceed the budget, and says so."""
          store = Store()
          with mock.patch.object(job, "MAX_REQUESTS", 2):
              result = job.run(Source(live_records(60)), store)
```

### c045 — exporter/job.py

```python
      """
      result = RunResult(cursor=cursor)
      batch = []
>     # Drafts read since the last write. They are counted, and the cursor moves past them, only once
>     # the live records before them are written: if the budget stops the run first, the next run
>     # reads them again, and counting them now would count them twice.
      batch_skipped = 0
      last_read = cursor
  
```

### c046 — exporter/job.py

```python
  
  
  def _flush(store, result, batch, drafts, last_id):
>     """Write `batch` and advance the result to `last_id`; False, changing nothing, if the budget is spent."""
      if batch:
          if store.requests >= MAX_REQUESTS:
              return False
```

### c047 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
> """The export job: copies records from the source to the store within a request budget."""
  
  from dataclasses import dataclass
  
```

### c048 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def _write(batch, store, result):
>     """Write `batch`'s live records in one request and count the whole batch as dealt with.
> 
>     Returns False, writing nothing, when the request would take the run past MAX_REQUESTS.
>     """
      if result.requests >= MAX_REQUESTS:
          result.stopped_by_budget = True
          return False
```

### c049 — tests/test_job.py

```python
          self.assertEqual((result.exported, store.requests, len(store.records)), (100, 4, 100))
  
      def test_checks_the_budget_before_every_batch_within_a_page(self):
>         """A page of 60 needs three requests; with a budget of 2 the run stops after 50 and resumes at the 51st."""
          records = [record(f"{n:03d}") for n in range(60)]
          store = Store()
          with mock.patch.object(job, "MAX_REQUESTS", 2):
```

### c050 — exporter/report.py

```python
  
  
  def main(argv=None):
>     """Run one export over the records in RECORDS_JSON and print the report line.
> 
>     Returns 0 whether the run completed or stopped at the budget, and 2 on a usage error, which
>     includes a records file that cannot be read as a JSON list.
>     """
      args = sys.argv[1:] if argv is None else argv
      if len(args) not in (1, 2):
          print(USAGE, file=sys.stderr)
```

### c051 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def load_records(path):
>     """The records in the JSON file at `path`: objects with a non-empty string id and a string status."""
      try:
          with open(path, encoding="utf-8") as f:
              records = json.load(f)
```

### c052 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def live_records(count, first=1):
>     """`count` live records with ids r001, r002, ... that sort in numeric order."""
      return [record(f"r{n:03d}") for n in range(first, first + count)]
  
  
```

### c053 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
          self.assertEqual(len(store.records), 60)
  
      def test_stops_at_the_request_budget(self):
>         """The run stops before the request that would exceed the budget, and says so."""
          store = Store()
          with mock.patch.object(job, "MAX_REQUESTS", 2):
              result = job.run(Source(numbered(["live"] * 60)), store)
```

### c054 — tests/test_job.py

```python
          self.assertEqual((result.exported, store.requests), (60, 3))
  
      def test_never_exceeds_the_budget_and_resumes_mid_page(self):
>         """A run stopped between batches of one page keeps its cursor at the last batch written."""
          records = [record(f"{n:03d}") for n in range(60)]
          store = Store()
          with mock.patch.object(job, "MAX_REQUESTS", 2):
```

### c055 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def run(source, store, cursor=""):
>     """Export every record after `cursor` with put_many, in batches of at most MAX_BATCH.
> 
>     The run makes at most MAX_REQUESTS store requests of its own and stops, with
>     stopped_by_budget set, rather than exceed them. The result's cursor is the id of the last
>     record dealt with, written or skipped, so the next run resumes after it and neither loses
>     nor repeats a record.
>     """
      result = RunResult(cursor=cursor)
      # Pages are read after the last record read, which runs ahead of the cursor while
      # records wait in `pending` for their batch.
```

### c056 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def main(argv=None):
>     """Run one export and print its report; return 0 for a completed or budget-stopped run, 2 on a usage error."""
      args = sys.argv[1:] if argv is None else argv
      if len(args) not in (1, 2):
          print(USAGE, file=sys.stderr)
```

### c057 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
      # Pages are read after the last record read, which runs ahead of the cursor while
      # records wait in `pending` for their batch.
      read_after = cursor
>     # Records read but not yet dealt with, in id order. The first is always live: a draft
>     # with nothing ahead of it is dealt with at once.
      pending = []
      live_pending = 0
      while True:
```

### c058 — exporter/job.py

```python
  
  
  def run(source, store, cursor=""):
>     """Export every record after `cursor` in batches, stopping before the store would exceed MAX_REQUESTS.
> 
>     The result's cursor is the id of the last record dealt with, so the next run resumes after it.
>     Records read but not yet written, and drafts read among them, are not dealt with until their
>     batch is written: if the budget stops the run first, the next run reads them again.
>     """
      result = RunResult(cursor=cursor)
      batch = []
      batch_skipped = 0
```

### c059 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
          self.dir = Path(tmp.name)
  
      def write(self, content, name="records.json"):
>         """Write `content` (a str as it is, anything else as JSON) and return the file's path."""
          path = self.dir / name
          text = content if isinstance(content, str) else json.dumps(content)
          path.write_text(text, encoding="utf-8")
```

### c060 — tests/test_job.py

```python
          self.assertEqual(result.cursor, source[2 * MAX_BATCH - 1]["id"])
  
      def test_a_run_stopped_by_the_budget_loses_and_repeats_nothing(self):
>         """Resuming from the cursor covers every record exactly once, drafts included."""
          source = records(MAX_BATCH + 2)
          source[MAX_BATCH + 1] = record(source[MAX_BATCH + 1]["id"], "draft")
          source.insert(MAX_BATCH, record(source[MAX_BATCH - 1]["id"] + "x", "draft"))
```

### c061 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
      after it: records read into a batch the budget stopped from being written are not passed.
      """
      result = RunResult(cursor=cursor)
>     # Records read but not yet dealt with; the first, if any, is live.
      pending = []
      # The source is paged from the last record read: the cursor lags behind `pending`.
      after = cursor
```

### c062 — exporter/job.py

```python
  
  
  def run(source, store, cursor=""):
>     """Export every record after `cursor`, stopping before the store would exceed MAX_REQUESTS.
> 
>     Writes in batches of at most MAX_BATCH. The result's cursor is the id of the last record dealt
>     with, so the next run resumes after it, even when the run stopped part-way through a page.
>     """
      result = RunResult(cursor=cursor)
      while True:
          page = source.page(result.cursor, SOURCE_PAGE_SIZE)
```

### c063 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
> """Command-line entrypoint: runs one export over a JSON file of records and prints its report.
> 
>     python3 -m exporter.report RECORDS_JSON [CURSOR]
> """
  
  import argparse
  import json
```

### c064 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
          self.assertEqual((exported, skipped, cursor), (60, 10, "r070"))
  
      def test_the_budget_is_per_run(self):
>         """Requests an earlier run made on the same store do not count against this run."""
          store = Store()
          store.requests = 10
          with mock.patch.object(job, "MAX_REQUESTS", 2):
```

### c065 — exporter/job.py

```python
  
  
  def run(source, store, cursor=""):
>     """Export every record after `cursor` in batches of MAX_BATCH, within MAX_REQUESTS store requests.
> 
>     The result's cursor is the id of the last record dealt with, so the next run resumes after it.
>     """
      result = RunResult(cursor=cursor)
      # Records read but not yet dealt with: the live ones waiting to be written, and the drafts read
      # after the first of them. A draft is dealt with only once every live record before it is written,
```

### c066 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
          self.assertEqual((result.exported, result.skipped, result.cursor), (26, 1, "r027"))
  
      def test_makes_no_request_when_nothing_is_left_to_write(self):
>         """Re-running from the final cursor, or over only drafts, sends no empty batch."""
          store = Store()
          result = job.run(Source(live_records(3)), store, cursor="r003")
          self.assertEqual((result.requests, store.requests, result.cursor), (0, 0, "r003"))
```

### c067 — tests/test_job.py

```python
          self.assertEqual((store.requests, len(store.records), result.cursor), (2, 50, "049"))
  
      def test_a_run_resumed_from_a_budget_stop_loses_and_repeats_nothing(self):
>         """Drafts around the stopping point are counted once, and every live record is written once."""
          records = [record(f"{i:03}", "draft" if i % 7 == 0 else "live") for i in range(100)]
          source, first_store, second_store = Source(records), Store(), Store()
          with mock.patch.object(job, "MAX_REQUESTS", 2):
```

### c068 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
          self.assertEqual((len(store.records), result.cursor), (50, "r049"))
  
      def test_the_cursor_does_not_pass_a_batch_the_budget_left_unwritten(self):
>         """Records read into the unwritten batch, drafts among them, are left for the next run."""
          records = numbered(["live"] * 25 + ["draft", "live", "draft"] + ["live"] * 30)
          store = Store()
          with mock.patch.object(job, "MAX_REQUESTS", 1):
```

### c069 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
                  self.fail("the runs never completed")
          for call in spy.call_args_list:
              written.extend(key for key, _ in call.args[0])
>         self.assertEqual(sorted(written), live_ids)  # every live record exactly once
          self.assertEqual((exported, skipped, cursor), (60, 10, "r070"))
  
      def test_the_budget_is_per_run(self):
```

### c070 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
> """Command-line entrypoint: runs one export over a JSON file of records and prints its report.
> 
>     python3 -m exporter.report RECORDS_JSON [CURSOR]
> 
> Prints `exported=N skipped=N requests=N stopped_by_budget=yes|no cursor=ID` and exits 0, whether
> the run completed or stopped at the budget. Exits 2 on a usage error. The cursor is empty when the
> run dealt with no record and no CURSOR was given.
> """
  
  import json
  import sys
```

### c071 — exporter/job.py

```python
  
  
  def run(source, store, cursor=""):
>     """Export every record after `cursor` with `put_many`, stopping before the store would exceed
>     MAX_REQUESTS.
> 
>     The result's cursor is the id of the last record dealt with, so the next run resumes after it.
>     """
      result = RunResult(cursor=cursor)
      batch = []
      # Drafts read since the last write. They are counted, and the cursor moves past them, only once
```

### c072 — tests/test_job.py

```python
          self.assertEqual(result.cursor, "r049")
  
      def test_cursor_does_not_pass_drafts_behind_unwritten_records(self):
>         """A draft between unwritten records is dealt with only once they are, so resuming loses nothing."""
          records = ids(30) + [record("r025a", "draft")]
          with mock.patch.object(job, "MAX_REQUESTS", 1):
              first = job.run(Source(records), Store())
```

### c073 — exporter/job.py

```python
      The result's cursor is the id of the last record dealt with, so the next run resumes after it.
      """
      result = RunResult(cursor=cursor)
>     # Records read but not yet dealt with: the live records of the next batch, and any drafts
>     # between them. The cursor cannot pass a draft until the live records before it are written.
      pending = []
  
      def flush():
```

### c074 — exporter/report.py

```python
> """Command-line entrypoint: runs one export and prints its report.
> 
> Usage: python3 -m exporter.report RECORDS_JSON [CURSOR]
> """
  
  import json
  import sys
```

### c075 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def format_report(result):
>     """The report line for a RunResult, without a trailing newline."""
      return (
          f"exported={result.exported} skipped={result.skipped} requests={result.requests} "
          f"stopped_by_budget={'yes' if result.stopped_by_budget else 'no'} cursor={result.cursor}"
```

### c076 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
          self.addCleanup(self.tmp.cleanup)
  
      def write(self, content, name="records.json"):
>         """Write `content` to a file in the temporary directory (a str as-is, anything else as JSON)."""
          path = os.path.join(self.tmp.name, name)
          with open(path, "w", encoding="utf-8") as file:
              file.write(content if isinstance(content, str) else json.dumps(content))
```

### c077 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  class RunTest(unittest.TestCase):
      def test_exports_live_records_and_skips_drafts(self):
>         """Drafts are counted as skipped and never written."""
          store = RecordingStore()
          result = job.run(Source([record("a"), record("b", "draft"), record("c")]), store)
          self.assertEqual(sorted(store.records), ["a", "c"])
```

### c078 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def _write(store, pending, result):
>     """Write the live records in `pending` in one request, and deal with all of `pending`.
> 
>     Returns False, having written nothing and left the cursor alone, when the request would
>     exceed MAX_REQUESTS.
>     """
      if result.requests >= MAX_REQUESTS:
          result.stopped_by_budget = True
          return False
```

### c079 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
          self.directory = Path(directory.name)
  
      def write(self, content, name="records.json"):
>         """Write `content` (a string as is, anything else as JSON) to a file and return its path."""
          path = self.directory / name
          path.write_text(content if isinstance(content, str) else json.dumps(content), encoding="utf-8")
          return str(path)
```

### c080 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  class RunTest(unittest.TestCase):
      def test_exports_live_records_and_skips_drafts(self):
>         """Drafts are counted as skipped and never written."""
          store = Store()
          result = job.run(Source([record("a"), record("b", "draft"), record("c")]), store)
          self.assertEqual(sorted(store.records), ["a", "c"])
```

### c081 — exporter/report.py

```python
      store = Store()
      result = job.run(Source(records), store, cursor)
      print(format_report(result, store.requests))
>     # A run that stops at the budget is a normal outcome: the next run resumes from its cursor.
      return 0
  
  
```

### c082 — exporter/report.py

```python
  
  
  def main(argv=None):
>     """Run one export over the records in RECORDS_JSON and print its one-line report.
> 
>     Returns 0 when the run completed or stopped at the budget, and 2 on a usage error.
>     """
      args = sys.argv[1:] if argv is None else argv
      if len(args) not in (1, 2):
          print(USAGE, file=sys.stderr)
```

### c083 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
          self.assertEqual((result.exported, result.skipped, result.cursor), (25, 25, "r0049"))
  
      def test_stops_at_the_request_budget(self):
>         """The run stops before the request that would exceed the budget, and says so."""
          store = RecordingStore()
          with mock.patch.object(job, "MAX_REQUESTS", 2):
              result = job.run(Source(live_records(51)), store)
```

### c084 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  class RecordingStore(Store):
>     """A Store that keeps the keys of every batch it writes and refuses single puts."""
  
      def __init__(self):
          super().__init__()
```

### c085 — exporter/report.py

```python
> """Command-line entrypoint: runs one export and prints its report.
> 
>     python3 -m exporter.report RECORDS_JSON [CURSOR]
> """
  
  import json
  import sys
```

### c086 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def load_records(path):
>     """The records in the JSON file at `path`: a list of objects, each with a string id and status.
> 
>     Raises UsageError when the file cannot be read or does not hold such a list.
>     """
      try:
          with open(path, encoding="utf-8") as file:
              records = json.load(file)
```

### c087 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
> """Command-line entrypoint: runs one export over a JSON file of records and prints its report."""
  
  import json
  import sys
```

### c088 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
> """The export job: copies records from the source to the store within a request budget."""
  
  from dataclasses import dataclass
  
```

### c089 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def load_records(path):
>     """The records in the JSON file at `path`. Raises ValueError saying what is wrong with the file."""
      try:
          with open(path, encoding="utf-8") as f:
              records = json.load(f)
```

### c090 — exporter/job.py

```python
      batch_last_id = cursor
  
      def flush():
>         """Write the batch in one request, or return False if the budget does not allow another."""
          nonlocal batch_drafts
          if store.requests >= MAX_REQUESTS:
              result.stopped_by_budget = True
```

### c091 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
          self.assertEqual([len(batch) for batch in store.batches], [25, 5])
  
      def test_stops_at_the_request_budget(self):
>         """The run stops before the request that would exceed the budget, and says so."""
          store = RecordingStore()
          with mock.patch.object(job, "MAX_REQUESTS", 2):
              result = job.run(Source(numbered(60)), store)
```

### c092 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
          )
  
      def test_a_stop_leaves_the_cursor_before_the_first_unwritten_record(self):
>         """A draft read while nothing waits is dealt with; a draft behind an unwritten record is not."""
          store = RecordingStore()
          # r000-r024 fill the one allowed batch; r025 is a draft with nothing waiting;
          # r026 is live and waits for a batch that the budget refuses; r027 is a draft behind it.
```

### c093 — tests/test_job.py

```python
      def test_run_stopped_at_budget_loses_and_repeats_nothing(self):
          """Drafts among unwritten records are left for the next run, so none is counted twice."""
          all_records = records(MAX_BATCH + 5)
>         all_records[MAX_BATCH + 1]["status"] = "draft"  # read, but after the budget ran out
          all_records[3]["status"] = "draft"
          source = Source(all_records)
          store = Store()
```

### c094 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
          self.assertFalse(hasattr(job, "PAGE_SIZE"))
  
      def test_exports_live_records_and_skips_drafts(self):
>         """Drafts are counted as skipped and never written."""
          store = RecordingStore()
          result = job.run(Source([record("a"), record("b", "draft"), record("c")]), store)
          self.assertEqual(sorted(store.records), ["a", "c"])
```

### c095 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def main(argv=None):
>     """Run one export and print its report line; return the exit code (0, or 2 on a usage error)."""
      args = sys.argv[1:] if argv is None else argv
      if len(args) not in (1, 2):
          print(USAGE, file=sys.stderr)
```

### c096 — exporter/report.py

```python
> """Command-line entrypoint: runs one export and prints its report.
> 
> Usage: python3 -m exporter.report RECORDS_JSON [CURSOR]
> """
  
  import json
  import sys
```

### c097 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def _write(store, pending, result):
>     """Write the live records in `pending` in one request, then count `pending` as dealt with.
> 
>     Returns False, having written and counted nothing, when the request would exceed MAX_REQUESTS.
>     """
      if result.requests >= MAX_REQUESTS:
          result.stopped_by_budget = True
          return False
```

### c098 — exporter/job.py

```python
  
  
  def run(source, store, cursor=""):
>     """Export every record after `cursor` in batches of MAX_BATCH, within MAX_REQUESTS store requests.
> 
>     The result's cursor is the id of the last record dealt with, so the next run resumes after it.
>     """
      result = RunResult(cursor=cursor)
      # Records read but not yet dealt with: the live records of the next batch, and any drafts
      # between them. The cursor cannot pass a draft until the live records before it are written.
```

### c099 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def _flush(store, pending, result):
>     """Write the live records in `pending` in one request, and count all of `pending` as dealt with.
> 
>     Returns False, having written nothing, when the request would exceed the budget.
>     """
      if result.requests >= MAX_REQUESTS:
          result.stopped_by_budget = True
          return False
```

### c100 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  def numbered(statuses):
>     """One record per status, with ids r000, r001, ... so that id order is list order."""
      return [record(f"r{index:03d}", status) for index, status in enumerate(statuses)]
```

### c101 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
      record.
      """
      result = RunResult(cursor=cursor)
>     # The first unwritten live record, the live records after it and any drafts between them.
      pending = []
      read_after = cursor
      while True:
```

### c102 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def main(argv=None):
>     """Run one export and print its report line. Returns 0; exits 2 on a usage error."""
      parser = argparse.ArgumentParser(
          prog="python3 -m exporter.report", description="Run one export and print its report."
      )
```

### c103 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def live_records(n, start=0):
>     """n live records with ids r000, r001, ... that sort in the order they are numbered."""
      return [record(f"r{i:03d}") for i in range(start, start + n)]
  
  
```

### c104 — exporter/job.py

```python
      pending = []
  
      def flush():
>         """Write the pending batch; False if the budget leaves no request for it."""
          batch = [(record["id"], record) for record in pending if record["status"] != "draft"]
          if batch:
              if result.requests >= MAX_REQUESTS:
```

### c105 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def run(source, store, cursor=""):
>     """Export every record after `cursor` with `put_many`, making at most MAX_REQUESTS requests.
> 
>     The result's cursor is the id of the last record dealt with, written or skipped, and its counts
>     cover exactly the records up to it. Records read but not yet written are not dealt with. A run
>     that stops at the budget can therefore resume from the cursor without losing or repeating a
>     record.
>     """
      result = RunResult(cursor=cursor)
      # The first unwritten live record, the live records after it and any drafts between them.
      pending = []
```

### c106 — exporter/job.py

```python
  
  
  def run(source, store, cursor=""):
>     """Export every record after `cursor` in batches of MAX_BATCH, within MAX_REQUESTS store requests.
> 
>     The result's cursor is the id of the last record dealt with, so the next run resumes after it.
>     A draft that falls between records of an unwritten batch is not dealt with until that batch is
>     written, so a run stopped by the budget neither loses nor recounts it.
>     """
      result = RunResult(cursor=cursor)
      requests_before = store.requests
      batch = []
```

### c107 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
      result = RunResult(cursor=cursor)
      # Records read but not yet dealt with; the first, if any, is live.
      pending = []
>     # The source is paged from the last record read: the cursor lags behind `pending`.
      after = cursor
      while True:
          page = source.page(after, SOURCE_PAGE_SIZE)
```

### c108 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def load_records(path):
>     """The records in the JSON file at `path`: a list of objects, each with a string id and a status."""
      try:
          with open(path, encoding="utf-8") as file:
              records = json.load(file)
```

### c109 — exporter/report.py

```python
> """Command-line entrypoint: runs one export and prints its report.
> 
>     python3 -m exporter.report RECORDS_JSON [CURSOR]
> """
  
  import json
  import sys
```

### c110 — exporter/report.py

```python
  
  
  def main(argv=None):
>     """Exit 0 when the run completed or stopped at the budget, 2 on a usage error."""
      args = sys.argv[1:] if argv is None else argv
      if len(args) not in (1, 2):
          print(USAGE, file=sys.stderr)
```

### c111 — exporter/report.py

```python
  
  
  def main(argv=None):
>     """Exit 0 when the run completed or stopped at the budget, 2 on a usage error."""
      args = sys.argv[1:] if argv is None else argv
      if not 1 <= len(args) <= 2:
          print(USAGE, file=sys.stderr)
```

### c112 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
> """Command-line entrypoint: runs one export over a JSON file of records and prints its report.
> 
>     python3 -m exporter.report RECORDS_JSON [CURSOR]
> 
> prints `exported=N skipped=N requests=N stopped_by_budget=yes|no cursor=ID` and exits 0 whether
> the run completed or stopped at the budget. It exits 2, with a message on stderr, on a usage error:
> wrong arguments or a records file that cannot be read as a JSON array of records.
> """
  
  import json
  import sys
```

### c113 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
          )
  
      def test_drafts_before_an_unwritten_batch_are_dealt_with(self):
>         """A draft needs no request, so one read before the next batch starts is skipped at once."""
          store = Store()
          records = live_records(25) + [record("r025", "draft"), record("r026")]
          with mock.patch.object(job, "MAX_REQUESTS", 1):
```

### c114 — docs/superpowers/plans/2026-02-02-batch-writes-and-report.md

```python
  
  
  def load_records(path):
>     """The records in the JSON file at `path`: an array of objects with a string id and status."""
      try:
          with open(path, encoding="utf-8") as file:
              records = json.load(file)
```

