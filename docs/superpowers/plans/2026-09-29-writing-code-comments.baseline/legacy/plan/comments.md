### c001 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  from . import runner
  from .store import Store
  
> # The summary line's fields, in the order Summary declares them.
  COUNTS = ("files", "imported", "skipped", "failed", "poisoned", "stored", "duplicates", "rejected")
  
  OK = 0              # nothing failed, and no poisoned file is in the inbox
```

### c002 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          with mock.patch.object(self.store, "add", side_effect=add):
              with self.assertRaises(sqlite3.OperationalError):
                  self.run_once()
>         self.assertEqual(self.store.count(), 6)  # rolled back on the run's own connection
          store = self.committed()
          self.assertEqual(store.count(), 6)  # A's, committed before B began
          self.assertIsNone(store.get("ST014|2026-01-15T02:00|temperature"))
```

### c003 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
      self.assertEqual(problems, [(C, "failed", 1), (C, "failed", 2), (C, "poisoned", 3)])
      readings, _ = dump(self.db)
>     self.assertEqual(len(readings), 3)  # only A's; nothing of C, ever
  
  def test_unknown_column_fails_the_file_and_stores_nothing_of_it(self):
      write(self.inbox, A, "time,temp_c,humidity\n2026-01-15T00:00,3.1,80\n")
```

### c004 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  def utf16_export(self, name):
>     # the firmware-updated station: every run will fail it
      with open(os.path.join(self.inbox, name), "wb") as f:
          f.write((HEADER + ROW_00).encode("utf-16"))
  
```

### c005 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def run(inbox, store):
>     """Import every *.csv file in inbox into store, one file per transaction.
> 
>     An exception that is not the file's fault rolls the file back and propagates.
>     """
      summary = Summary()
      for name in inbox_files(inbox):
          summary.files += 1
```

### c006 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(store.marker(A), Marker("done", 0, "3 stored, 0 duplicates, 0 rejected"))
  
      def test_overlapping_exports_store_each_reading_once(self):
>         # A station that drops empty rows: 01:00 is row 2 in A and row 1 in B.
          self.export(A, HEADER + ROW[0] + ROW[1] + ROW[2])
          self.export(B, HEADER + ROW[1] + ROW[2] + ROW[3])
          summary = self.run_once()
```

### c007 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      def test_a_store_error_keeps_nothing_of_that_file_and_propagates(self):
          self.export(EARLY, HEADER + ROW_00)
          self.export(LATE, HEADER + ROW_01)
>         store = FailingStore(self.db, fail_after=4)  # EARLY's 3 adds, then one of LATE's
          self.addCleanup(store.close)
          with self.assertRaises(sqlite3.OperationalError):
              runner.run(self.inbox, store)
```

### c008 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.db = os.path.join(base, "readings.db")
  
      def invoke(self, argv):
>         """(exit status, stdout, stderr) of cli.main(argv)."""
          out, err = io.StringIO(), io.StringIO()
          with redirect_stdout(out), redirect_stderr(err):
              try:
```

### c009 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def inbox_files(inbox):
>     """The names of the *.csv files in the inbox, in name order."""
      return sorted(name for name in os.listdir(inbox)
                    if name.endswith(".csv") and os.path.isfile(os.path.join(inbox, name)))
  
```

### c010 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertTrue(runs[0][2].startswith(f"{D}: failed (1): not text: "))
          self.assertTrue(runs[1][2].startswith(f"{D}: failed (2): not text: "))
          self.assertTrue(runs[2][2].startswith(f"{D}: poisoned (3): not text: "))
>         self.assertEqual(runs[3][2], "")  # poisoned before this run: counted, not reported
>         # a poisoned file does not stop the rest of the inbox from importing
          self.assertEqual(runs[3][1], "files=3 imported=1 skipped=1 failed=0 poisoned=1 "
                                       "stored=3 duplicates=0 rejected=0\n")
          self.assertEqual(self.stored(), 6)
```

### c011 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  @dataclass
  class Summary:
>     files: int = 0       # *.csv files in the inbox
>     imported: int = 0    # read this run and marked done
>     skipped: int = 0     # already done, not opened
>     failed: int = 0      # failed this run, will be retried
>     poisoned: int = 0    # poisoned, this run or before
      stored: int = 0
      duplicates: int = 0
      rejected: int = 0
```

### c012 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  class FailingStore(Store):
>     """A real Store whose writes start failing partway, as a full disk would."""
  
      def __init__(self, path, fail_after):
          super().__init__(path)
```

### c013 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  DEFAULT_DB = "readings.db"
  
> # the summary line's fields, in the order it prints them
  COUNTS = ("files", "imported", "skipped", "failed", "poisoned", "stored", "duplicates", "rejected")
  
  
```

### c014 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
                       Marker("done", 0, "3 stored, 0 duplicates, 0 rejected"))
  
  def test_store_error_keeps_nothing_of_the_file_and_propagates(self):
>     self.export(A, rows("2026-01-15T00:00"))                     # adds 1-3
>     self.export(B, rows("2026-01-15T06:00", "2026-01-15T07:00"))  # fails on its second add
      store = FailingStore(self.db, fail_on=5)
      self.addCleanup(store.close)
      with self.assertRaises(sqlite3.OperationalError):
```

### c015 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
                          help="the store's SQLite file (default: readings.db)")
      args = parser.parse_args(argv)
      if not os.path.isdir(args.inbox):
>         parser.error(f"inbox is not a directory: {args.inbox}")  # exits 2
  
      store = Store(args.db)
      try:
```

### c016 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  def run(inbox, store):
>     """Import every export in inbox that is neither done nor poisoned into store.
> 
>     A file that cannot be read fails, and is retried on later runs until it has
>     failed POISON_AFTER times. Anything that is not the file's fault (the store
>     cannot be written) rolls back that file and propagates.
>     """
      summary = Summary()
      for name in exports(inbox):
          summary.files += 1
```

### c017 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      def test_store_error_propagates(self):
          write(self.inbox, A, HEADER + row(0))
          with self.assertRaises(sqlite3.OperationalError):
>             self.main("--inbox", self.inbox, "--db", self.inbox)  # a directory is no database
  
  
  class ModuleTest(unittest.TestCase):
```

### c018 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(store.marker(other).state, "done")
  
      def test_partial_copy_imports_once_complete(self):
>         self.export(A, A_TEXT[:20])  # cut mid-header: "time,temp_c,pressure"
          self.assertEqual(self.run_once(), Summary(files=1, failed=1))
          self.assertEqual(self.committed().marker(A).failures, 1)
          self.export(A, A_TEXT)  # the copy has finished
```

### c019 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """The command line: import the inbox once, and say by exit status whether a person is needed.
> 
>     python3 -m readings [--inbox DIR] [--db PATH]
> """
  import argparse
  import os
  import sys
```

### c020 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      first = self.run_once()
      self.assertEqual((first.failed, self.store.count()), (1, 0))
      self.assertEqual(self.store.marker(EARLY), Marker("failed", 1, "header has no delimiter"))
>     self.export(EARLY, HEADER + ROW_00)  # the complete copy arrives under the same name
      second = self.run_once()
      self.assertEqual((second.imported, second.failed, second.stored, second.problems), (1, 0, 3, []))
      store = self.reopened()
```

### c021 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      self.assertEqual(self.marker(A), Marker("failed", 1, "unknown columns: humidity"))
  
  def test_partial_copy_that_fails_imports_on_the_next_run(self):
>     # copied up to the middle of the header, then completed before the next run
      write(self.inbox, A, "time,temp_c,pres")
      self.assertEqual(self.run_once(), Summary(files=1, failed=1))
      self.assertEqual(self.marker(A), Marker("failed", 1, "unknown columns: pres"))
```

### c022 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
                                ("poisoned", 3, 0, 1, [])])
      store = self.reopened()
      self.assertTrue(store.marker(EARLY).detail.startswith("not text: "))
>     self.assertEqual(store.count(), 3)  # LATE's readings, stored once on the first run
  
  def test_a_failed_file_is_retried_and_imports_once_complete(self):
      self.export(EARLY, "time")  # a copy cut short inside the header
```

### c023 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.db = os.path.join(directory, "readings.db")
  
      def main(self, *argv):
>         """(exit status, stdout, stderr) of one cli.main over the test inbox and store."""
          out, err = io.StringIO(), io.StringIO()
          with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
              status = cli.main(["--inbox", self.inbox, "--db", self.db, *argv])
```

### c024 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  @dataclass
  class Reading:
      station: str
>     row: int  # the row's number in its file, for a person opening it; not part of any key
      time: str
      quantity: str
      value: float
```

### c025 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def status(summary):
>     # A poisoned file needs a person whatever else happened, so it outranks a failure.
      if summary.poisoned:
          return 3
      if summary.failed:
```

### c026 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(store.marker(A), Marker("failed", 1, "unknown column: humidity"))
  
      def test_a_file_that_failed_once_imports_on_the_next_run(self):
>         self.export(A, "")  # the first instant of a copy
          self.assertEqual(self.run_once().failed, 1)
          self.export(A, HEADER + ROW[0])  # the copy has finished
          summary = self.run_once()
```

### c027 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
      def test_overlapping_exports_store_each_reading_once(self):
          write(self.inbox, A, HEADER + row(0) + row(1) + row(2))
>         # the next export: 01:00 is row 1 here and row 2 in A
          write(self.inbox, B, HEADER + row(1) + row(2) + row(3))
  
          self.assertEqual(self.run_once(), Summary(files=2, imported=2, stored=12, duplicates=6))
```

### c028 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """Import every export in the inbox into the store, with nobody watching.
> 
> Each *.csv file in the inbox gets one marker in the store, committed in the same
> transaction as the file's readings, so a run that stops anywhere leaves the store
> consistent and the next run carries on from the markers.
> """
  import os
  import sys
  from dataclasses import asdict, dataclass
```

### c029 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  INBOX_DIR = "inbox"
  
> # A file that has failed this many runs is poisoned and skipped from then on.
> # Eighteen hours at Phase 3's six-hour interval; no partial copy in the measured
> # fortnight took more than one retry.
  POISON_AFTER = 3
  
  DONE = "done"
```

### c030 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  def parse_file(path):
>     """(readings, rejected row numbers) for one export.
> 
>     Raises FileError when the file has no station name, is not UTF-8, has no
>     delimiter in its header, has no time column, or has a column units.COLUMNS
>     does not know.
>     """
      station = station_of(path)
      try:
          with open(path, encoding="utf-8") as f:
```

### c031 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          raise FileError("first column is not time")
      unknown = [column for column in header[1:] if column not in units.COLUMNS]
      if unknown:
>         # A station sending a column nobody has mapped, not a file full of bad rows.
          raise FileError(f"unknown columns: {', '.join(unknown)}")
  
      readings, rejected = [], []
```

### c032 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertTrue(markers[0].detail.startswith("not text: "))
          self.assertEqual(summaries[0].problems, [(A, markers[0])])
          self.assertEqual(summaries[2].problems, [(A, markers[2])])
>         self.assertEqual(summaries[3].problems, [])  # poisoned before, not opened this run
          self.assertEqual(self.committed().count(), 0)
  
      def test_unknown_column_fails_the_file_and_the_run_goes_on(self):
```

### c033 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def exports(inbox):
>     """The names of the inbox's *.csv files, in name order."""
      return sorted(name for name in os.listdir(inbox)
                    if name.endswith(".csv") and os.path.isfile(os.path.join(inbox, name)))
  
```

### c034 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> # Not the file's fault (import_file handles FileError): keep nothing
> # of this file and let the caller see why.
```

### c035 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
              rejected.append(row)
              continue
          values = [v for v in values if v is not None]
>         # float() accepts "nan" and "inf", but neither is a reading
          if not all(math.isfinite(value) for _, value in values):
              rejected.append(row)
              continue
```

### c036 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(store.marker(A), Marker("done", 0, "3 stored, 0 duplicates, 0 rejected"))
  
      def test_a_poisoned_file_is_not_opened(self):
>         self.export(A, HEADER + ROW[0])  # would import, if it were opened
          self.store.set_marker(A, "poisoned", 3, "not text")
          self.store.commit()
          summary = self.run_once()
```

### c037 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  @dataclass
  class Summary:
>     files: int = 0       # *.csv files in the inbox
>     imported: int = 0    # read this run and marked done
>     skipped: int = 0     # already done, not opened
>     failed: int = 0      # failed this run, will be retried
>     poisoned: int = 0    # poisoned, this run or before
      stored: int = 0
      duplicates: int = 0
      rejected: int = 0
```

### c038 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  def row(hour):
>     """One good row of HEADER at <hour>:00 on 2026-01-15, holding three readings."""
      return f"2026-01-15T{hour:02d}:00,3.{hour},1012.{hour},4.{hour}\n"
  
  
```

### c039 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def exit_status(summary):
>     """0 nothing needs a person; 1 a failure the next run retries; 3 a person is needed."""
      if summary.poisoned:
          return 3
      if summary.failed:
```

### c040 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def _fail(name, previous, error, store, summary):
>     store.rollback()  # nothing of this file is kept
      failures = (previous.failures if previous is not None else 0) + 1
      marker = Marker(POISONED if failures >= POISON_AFTER else FAILED, failures, str(error))
      store.set_marker(name, marker.state, marker.failures, marker.detail)
```

### c041 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  def parse_file(path):
>     """(readings, rejected row numbers) for one export.
> 
>     Raises FileError when the file cannot be read, has no station name, is not
>     UTF-8, has no time column, or has a column units.COLUMNS does not know.
>     """
      station = station_of(path)
      try:
          # utf-8-sig: a byte-order mark is not part of the first column's name
```

### c042 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  @dataclass
  class Summary:
>     files: int = 0       # *.csv files in the inbox
>     imported: int = 0    # read this run and marked done
>     skipped: int = 0     # already done, not opened
>     failed: int = 0      # failed this run, will be retried
>     poisoned: int = 0    # poisoned, this run or before
      stored: int = 0
      duplicates: int = 0
      rejected: int = 0
```

### c043 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """python3 -m readings: one run over the inbox, exiting with its status."""
  import sys
  
  from .cli import main
```

### c044 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.addCleanup(store.close)
          with self.assertRaises(sqlite3.OperationalError):
              runner.run(self.inbox, store)
>         # rolled back on this connection, not merely left uncommitted
          self.assertEqual(store.count(), 3)
          self.assertIsNone(store.marker(LATE))
          reopened = self.reopened()
```

### c045 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
              duplicates += 1
      store.set_marker(name, "done", 0, f"{stored} stored, {duplicates} duplicates, {len(rejected)} rejected")
      store.commit()
>     # counted only once committed, so the summary never claims what the store lacks
      summary.imported += 1
      summary.stored += stored
      summary.duplicates += duplicates
```

### c046 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  def exit_status(summary):
      """0 nothing to do; 1 a file failed and will be retried; 3 a person is needed."""
      if summary.poisoned:
>         return 3  # a poisoned file in the inbox outranks everything else
      if summary.failed:
          return 1
      return 0
```

### c047 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def rows(*times):
>     """An export: one row per time, the same three values in each."""
      return HEADER + "".join(f"{time},3.1,1012.4,4.2\n" for time in times)
  
  
```

### c048 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      header, *body = dialect.rows(text, found)
      if not header or header[0] != "time":
          raise FileError("first column is not time")
>     # Checked before any row: an unmapped column is the station's setup, not bad
>     # data, and would otherwise reject every row of the file one by one.
      unknown = [column for column in header[1:] if column not in units.COLUMNS]
      if unknown:
          raise FileError(f"unknown columns: {', '.join(unknown)}")
```

### c049 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.export(A, A_TEXT[:20])  # cut mid-header: "time,temp_c,pressure"
          self.assertEqual(self.run_once(), Summary(files=1, failed=1))
          self.assertEqual(self.committed().marker(A).failures, 1)
>         self.export(A, A_TEXT)  # the copy has finished
          summary = self.run_once()
          self.assertEqual(summary, Summary(files=1, imported=1, stored=6))
          self.assertEqual(summary.problems, [])
```

### c050 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  class RunnerCase(unittest.TestCase):
>     """A real Store on a temporary file, and an empty inbox beside it."""
  
      def setUp(self):
          base = temp_dir(self)
```

### c051 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      parser.add_argument("--inbox", default=INBOX_DIR, help=f"the inbox directory (default: {INBOX_DIR})")
      parser.add_argument("--db", default=DEFAULT_DB, help=f"the store's SQLite file (default: {DEFAULT_DB})")
      args = parser.parse_args(argv)
>     # before the store is opened, so a mistyped inbox leaves no empty database behind
      if not os.path.isdir(args.inbox):
          parser.error(f"no inbox at {args.inbox}")
  
```

### c052 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """The command line: python3 -m readings [--inbox DIR] [--db PATH].
> 
> Prints one summary line to stdout and one line per file that failed this run to
> stderr. The exit status says whether a person is needed: 0 no, 1 not yet (a file
> will be retried, or the run stopped), 2 usage error, 3 yes (a poisoned file).
> """
  import argparse
  import os
  import sys
```

### c053 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual([m[0] for m in markers], [A])
          self.assertIsNone(self.marker(B))
  
>         # the next run picks up where this one stopped
          self.assertEqual(self.run_once(), Summary(files=2, imported=1, skipped=1, stored=6))
          self.assertEqual(len(dump(self.db)[0]), 9)
```

### c054 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> # (name, Marker) for each file that failed or became poisoned this run
  problems: list = field(default_factory=list)
```

### c055 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  from .store import Marker
  
  INBOX_DIR = "inbox"
> POISON_AFTER = 3  # failed runs; eighteen hours at Phase 3's six-hour interval
  
  
  def key(reading):
```

### c056 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def key(reading):
>     # Station, time and quantity identify a reading in the world; a row number
>     # only identifies it in one file, and overlapping exports differ in rows.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c057 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
              db.close()
  
      def test_overlapping_exports_store_each_reading_once(self):
>         # 01:00 is row 2 of A and row 1 of B: a row key would store it twice.
          self.export(A, rows("2026-01-15T00:00", "2026-01-15T01:00", "2026-01-15T02:00"))
          self.export(B, rows("2026-01-15T01:00", "2026-01-15T02:00", "2026-01-15T03:00"))
          self.assertEqual(self.run_once(), Summary(files=2, imported=2, stored=12, duplicates=6))
```

### c058 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def exit_status(summary):
>     # Phase 3's timer acts on this alone, so a poisoned file wins over everything else.
      if summary.poisoned:
          return NEEDS_A_PERSON
      if summary.failed:
```

### c059 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """python3 -m readings: import the inbox once, and exit with cli.main's status."""
  import sys
  
  from .cli import main
```

### c060 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertTrue(os.path.exists(os.path.join(self.base, "readings.db")))
  
      def test_a_run_that_stops_exits_1(self):
>         result = self.module("--db", "inbox")  # a directory is no database
          self.assertEqual(result.returncode, 1)
          self.assertEqual(result.stdout, "")
          self.assertIn("OperationalError", result.stderr)
```

### c061 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def run(inbox, store, errors=None):
>     """Import every export in inbox into store, one file per transaction."""
      errors = sys.stderr if errors is None else errors
      summary = Summary()
      for name in exports(inbox):
```

### c062 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def write_utf16(directory, name):
>     """A good export as the station with the firmware update writes it: UTF-16 with a BOM."""
      return write_bytes(directory, name, b"\xff\xfe" + (HEADER + row(0)).encode("utf-16-le"))
```

### c063 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def rows(*times):
>     """An export: one row per time, the same three values in each."""
      return HEADER + "".join(f"{time},3.1,1012.4,4.2\n" for time in times)
  
  
```

### c064 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      self.assertEqual(self.run_once(on_problem=report), Summary(files=2, skipped=1, poisoned=1))
      self.assertEqual((self.marker(C).state, self.marker(C).failures), ("poisoned", 3))
  
>     # poisoned: skipped without being opened, failures stop at POISON_AFTER, not reported again
      self.assertEqual(self.run_once(on_problem=report), Summary(files=2, skipped=1, poisoned=1))
      self.assertEqual((self.marker(C).state, self.marker(C).failures), ("poisoned", 3))
  
```

### c065 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      def test_a_file_that_failed_once_imports_on_the_next_run(self):
          self.export(A, "")  # the first instant of a copy
          self.assertEqual(self.run_once().failed, 1)
>         self.export(A, HEADER + ROW[0])  # the copy has finished
          summary = self.run_once()
          self.assertEqual(summary, runner.Summary(files=1, imported=1, stored=3))
          store = self.reopened()
```

### c066 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          write_utf16(self.inbox, D)
  
          runs = [self.main() for _ in range(3)]
>         write(self.inbox, B, HEADER + row(5))  # a new export arrives before the fourth run
          runs.append(self.main())
  
          self.assertEqual([status for status, _, _ in runs], [1, 1, 3, 3])
```

### c067 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def key(reading):
>     # Station, time and quantity identify a reading in the world. Every reading
>     # arrives in two overlapping exports, at different rows, so this is the only
>     # key that can match them.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c068 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  @dataclass
  class Summary:
>     files: int = 0       # *.csv files in the inbox
>     imported: int = 0    # read this run and marked done
>     skipped: int = 0     # already done, not opened
>     failed: int = 0      # failed this run, will be retried
>     poisoned: int = 0    # poisoned, this run or before
      stored: int = 0
      duplicates: int = 0
      rejected: int = 0
```

### c069 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      header, *body = dialect.rows(text, found)
      if not header or header[0] != "time":
          raise FileError("first column is not time")
>     # Checked before any row: an unmapped column is a station sending something
>     # nobody has mapped, not a file full of bad rows.
      unknown = [column for column in header[1:] if column not in units.COLUMNS]
      if unknown:
          raise FileError(f"unknown columns: {', '.join(unknown)}")
```

### c070 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(self.errors.getvalue(), "")
  
      def test_a_store_error_keeps_nothing_of_the_file_and_propagates(self):
>         self.export(A, HEADER + ROW[0] + ROW[1] + ROW[2])   # 9 readings
>         self.export(B, HEADER + ROW[3] + ROW[4])            # 6 readings
>         failing = FailingStore(self.db, fail_after=11)      # B's third add raises
          self.addCleanup(failing.close)
          with self.assertRaises(sqlite3.OperationalError):
              runner.run(self.inbox, failing, errors=self.errors)
```

### c071 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(store.marker(EARLY), Marker("done", 0, "6 stored, 0 duplicates, 1 rejected"))
  
      def test_files_are_imported_in_name_order(self):
>         # The later export carries a different value for 01:00; first stored wins,
>         # and the first is the earlier name, whatever order the files were written in.
          self.export(LATE, HEADER + "2026-01-15T01:00,9.9,1012.1,3.9\n")
          self.export(EARLY, HEADER + ROW_01)
          self.run_once()
```

### c072 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          real_add = self.store.add
  
          def add(key, reading):
>             # B's 02:00 temperature has been added, uncommitted, when this fails.
              if key == "ST014|2026-01-15T02:00|pressure":
                  raise sqlite3.OperationalError("disk I/O error")
              return real_add(key, reading)
```

### c073 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
              store.close()
  
      def utf16(self, name):
>         """An export from the station whose firmware switched it to UTF-16 (§3)."""
          with open(os.path.join(self.inbox, name), "w", encoding="utf-16") as f:
              f.write(rows("2026-01-15T06:00"))
  
```

### c074 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          if store.add(key(reading), asdict(reading)):
              stored += 1
          else:
>             duplicates += 1  # first stored wins
      store.set_marker(name, DONE, 0,
                       f"{stored} stored, {duplicates} duplicates, {len(rejected)} rejected")
      store.commit()
```

### c075 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          return summary
  
      def reopened(self):
>         """The store as another process would see it: committed work only."""
          store = Store(self.db)
          self.addCleanup(store.close)
          return store
```

### c076 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
              duplicates += 1
      store.set_marker(name, "done", 0, f"{stored} stored, {duplicates} duplicates, {len(rejected)} rejected")
      store.commit()
>     # counted only once committed, so the summary never claims what the store lacks
      summary.imported += 1
      summary.stored += stored
      summary.duplicates += duplicates
```

### c077 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  class FailingStore(Store):
>     """A real Store whose n-th add fails the way a full disk does."""
  
      def __init__(self, path, fail_on_add):
          super().__init__(path)
```

### c078 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  @dataclass
  class Summary:
>     files: int = 0       # *.csv files in the inbox
>     imported: int = 0    # read this run and marked done
>     skipped: int = 0     # already done, not opened
>     failed: int = 0      # failed this run, will be retried
>     poisoned: int = 0    # poisoned, this run or before
      stored: int = 0
      duplicates: int = 0
      rejected: int = 0
```

### c079 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """Import every station export in the inbox into the store, unattended.
> 
> Each file's readings and its marker are committed together, so a file is either
> imported and marked done, or nothing of it is kept. A file marked done is not
> opened again.
> """
  import glob
  import os
  from dataclasses import asdict, dataclass, field
```

### c080 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          if store.add(key(reading), asdict(reading)):
              stored += 1
          else:
>             # first stored wins, even when the values differ
              duplicates += 1
      store.set_marker(name, "done", 0, f"{stored} stored, {duplicates} duplicates, {len(rejected)} rejected")
      store.commit()
```

### c081 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def exports(inbox):
>     """Names of the inbox's *.csv files, in name order."""
      return sorted(entry.name for entry in os.scandir(inbox)
                    if entry.name.endswith(".csv") and entry.is_file())
  
```

### c082 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def key(reading):
>     """The store key: two exports carrying the same reading give it the same key."""
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c083 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      """
      station = station_of(path)
      try:
>         # utf-8-sig: a byte-order mark is UTF-8 too, and must not end up in the first column's name
          with open(path, encoding="utf-8-sig") as f:
              text = f.read()
      except UnicodeDecodeError as e:
```

### c084 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  class ModuleTest(unittest.TestCase):
>     """python3 -m readings, through a real interpreter: the exit status the timer sees."""
  
      def setUp(self):
          self.base = temp_dir(self)
```

### c085 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(store.marker(B), Marker("done", 0, "3 stored, 3 duplicates, 0 rejected"))
  
      def test_first_export_in_name_order_wins(self):
>         # B is written first, carrying a different 01:00 temperature; A sorts first.
          self.export(B, HEADER + "2026-01-15T01:00,3.5,1012.1,3.9\n")
          self.export(A, A_TEXT)
          summary = self.run_once()
```

### c086 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> # One row of HEADER per hour: three readings each (temperature, pressure, wind).
  ROW = {hour: f"2026-01-15T{hour:02d}:00,{3.0 + hour / 10:.1f},1012.{hour},4.{hour}\n"
         for hour in range(24)}
```

### c087 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      readings, rejected = [], []
      for row, fields in enumerate(body, 1):
          if not fields:
>             continue  # a blank line holds no reading and is not a bad row
          if len(fields) != len(header):
              rejected.append(row)
              continue
```

### c088 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> # (name, marker) for each file that failed or was poisoned this run; for stderr, not the summary line
  problems: list = field(default_factory=list)
```

### c089 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def key(reading):
>     # Station, time and quantity identify a reading in the world. Every reading
>     # arrives in two overlapping exports, at different rows, and this key is
>     # what lets the second copy match the first.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c090 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def run(inbox, store, on_problem=None):
>     """Import every *.csv file in inbox into store, one file per transaction.
> 
>     on_problem(name, marker), when given, is called for each file that failed or
>     was poisoned this run. An exception that is not a FileError is not the file's
>     fault: the file is rolled back and the exception propagates.
>     """
      summary = Summary()
      for name in inbox_files(inbox):
          summary.files += 1
```

### c091 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
              self.assertIsNone(store.marker(name))
  
      def test_files_are_imported_in_name_order(self):
>         # Written newest first; the older export must still be read first and win.
          self.export(B, HEADER + "2026-01-15T01:00,9.9,1012.1,4.1\n")
          self.export(A, HEADER + "2026-01-15T01:00,3.1,1012.1,4.1\n")
          self.run_once()
```

### c092 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      self.assertEqual(store.count(), 3)  # LATE's readings, stored once on the first run
  
  def test_a_failed_file_is_retried_and_imports_once_complete(self):
>     self.export(EARLY, "time")  # a copy cut short inside the header
      first = self.run_once()
      self.assertEqual((first.failed, self.store.count()), (1, 0))
      self.assertEqual(self.store.marker(EARLY), Marker("failed", 1, "header has no delimiter"))
```

### c093 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  @dataclass
  class Summary:
>     files: int = 0       # *.csv files in the inbox
>     imported: int = 0    # read this run and marked done
>     skipped: int = 0     # already done, not opened
>     failed: int = 0      # failed this run, will be retried
>     poisoned: int = 0    # poisoned, this run or before
      stored: int = 0
      duplicates: int = 0
      rejected: int = 0
```

### c094 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  class FailingStore(Store):
>     """A real store whose add raises on its nth call, as a full disk would."""
  
      def __init__(self, path, fail_on):
          super().__init__(path)
```

### c095 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """The command line: one unattended run over the inbox, answered by exit status."""
  import argparse
  import os
  import sys
```

### c096 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> # A partial copy parses a run later; a file still failing after three runs
> # (eighteen hours at a six-hour interval) will not, and needs a person.
  POISON_AFTER = 3
```

### c097 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def dump(path):
>     """Both tables, read through a fresh connection: what the commits left behind."""
      db = sqlite3.connect(path)
      try:
          return (db.execute("SELECT key, body FROM readings ORDER BY key").fetchall(),
```

### c098 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(runner.key(reading), "ST014|2026-01-15T00:00|temperature")
  
      def test_overlapping_exports_store_each_reading_once(self):
>         # The station dropped an empty row before its second export, so 01:00 is
>         # row 2 in the first file and row 1 in the second.
          self.export(EARLY, HEADER + ROW_00 + ROW_01 + ROW_02)
          self.export(LATE, HEADER + ROW_01 + ROW_02 + ROW_03)
          summary = self.run_once()
```

### c099 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def exports(inbox):
>     """The names of the *.csv files in inbox, in name order.
> 
>     Hidden names are not matched, so a copy still in flight under one is left alone.
>     """
      return sorted(name for name in glob.glob("*.csv", root_dir=inbox)
                    if os.path.isfile(os.path.join(inbox, name)))
  
```

### c100 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """Import every station export in the inbox into the store, with nobody watching.
> 
> A file's readings and its marker are committed together, so a run that stops
> part-way leaves the store consistent with the inbox as far as it got.
> """
  import os
  from dataclasses import asdict, dataclass
  
```

### c101 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.db = os.path.join(self.base, "readings.db")
  
      def main(self, *argv):
>         """(status, stdout, stderr) of cli.main over this test's inbox and store."""
          argv = argv or ("--inbox", self.inbox, "--db", self.db)
          out, err = io.StringIO(), io.StringIO()
          with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
```

### c102 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> # Two consecutive exports of one station. B's window overlaps A's by an hour:
> # the 01:00 reading is A's second row and B's first, as when a station drops an
> # empty row before exporting. Three readings per row.
  A = "ST014_202601150600.csv"
  B = "ST014_202601151200.csv"
  A_TEXT = HEADER + "2026-01-15T00:00,3.1,1012.4,4.2\n" + "2026-01-15T01:00,3.0,1012.1,3.9\n"
```

### c103 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
                  self.run_once()
          self.assertEqual(self.store.count(), 6)  # rolled back on the run's own connection
          store = self.committed()
>         self.assertEqual(store.count(), 6)  # A's, committed before B began
          self.assertIsNone(store.get("ST014|2026-01-15T02:00|temperature"))
          self.assertEqual(store.marker(A).state, "done")
          self.assertIsNone(store.marker(B))
```

### c104 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      self.assertEqual(sorted({r.row for r in readings}), [1, 3])
  
  def test_file_that_cannot_be_opened_fails_the_file(self):
>     # listed in the inbox, then gone (or unreadable) by the time it is opened
      missing = os.path.join(self.dir, NAME)
      with self.assertRaisesRegex(parse.FileError, "^cannot read: "):
          parse.parse_file(missing)
```

### c105 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def _import_file(inbox, name, previous, store, summary):
>     """Import one file and commit it with its marker; the marker when the file failed, else None."""
      try:
          readings, rejected = parse_file(os.path.join(inbox, name))
      except FileError as error:
```

### c106 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """The command line: python3 -m readings [--inbox DIR] [--db PATH].
> 
> Prints one summary line to stdout, one line per file that failed or was poisoned
> this run to stderr, and exits with a status that says whether a person is needed.
> """
  import argparse
  import os
  import sys
```

### c107 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.addCleanup(failing.close)
          with self.assertRaises(sqlite3.OperationalError):
              runner.run(self.inbox, failing, errors=self.errors)
>         self.assertEqual(failing.count(), 9)   # rolled back on this connection too
          store = self.reopened()
          self.assertEqual(store.count(), 9)
          self.assertEqual(store.marker(A).state, "done")
```

### c108 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          return runner.run(self.inbox, self.store)
  
      def committed(self):
>         """The store as a second connection sees it: only what was committed."""
          store = Store(self.db)
          self.addCleanup(store.close)
          return store
```

### c109 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """Import every station export in the inbox into the store.
> 
> Runs unattended. Files are imported one at a time, in name order, and each file's
> readings land in the same transaction as its marker, so a run that stops leaves
> the store consistent with the inbox as far as it got.
> """
  import os
  from dataclasses import asdict, dataclass
  
```

### c110 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def inbox_files(inbox):
>     """The names of the *.csv files in the inbox, in name order."""
      return sorted(name for name in os.listdir(inbox)
                    if name.endswith(".csv") and os.path.isfile(os.path.join(inbox, name)))
  
```

### c111 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(self.marker(A), Marker("done", 0, "6 stored, 0 duplicates, 1 rejected"))
  
      def test_only_csv_files_in_name_order(self):
>         # B is written first, but A sorts first, so A's value is the one stored
          write(self.inbox, B, HEADER + "2026-01-15T01:00,9.9,1012.1,4.1\n")
          write(self.inbox, A, HEADER + row(1))
          write(self.inbox, "notes.txt", "not an export\n")
```

### c112 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(store.marker(B), Marker("done", 0, "3 stored, 6 duplicates, 0 rejected"))
  
      def test_files_are_imported_in_name_order(self):
>         # B is written first, but A comes first by name, so A's copy is the one kept.
          self.export(B, rows("2026-01-15T01:00"))
          self.export(A, rows("2026-01-15T00:00", "2026-01-15T01:00"))
          self.run_once()
```

### c113 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """Import every station export in the inbox into the store, with nobody watching.
> 
> A file's readings and its marker are committed together, so a run that stops
> part-way leaves the store consistent with the inbox as far as it got.
> """
  import os
  from dataclasses import asdict, dataclass
  
```

### c114 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def key(reading):
>     # Station, time and quantity identify a reading in the world; a row number
>     # only identifies it in one file, and overlapping exports differ in rows.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c115 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  def parse_file(path):
>     """(readings, rejected row numbers) for one export.
> 
>     Raises FileError when the file has no station name, cannot be read, is not
>     UTF-8, has no delimiter in its header, has no time column, or has a column
>     units.COLUMNS does not know.
>     """
      station = station_of(path)
      try:
          with open(path, encoding="utf-8") as f:
```

### c116 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def run(inbox, store):
>     """Import every export in inbox that is not done or poisoned into store."""
      summary = Summary()
      for name in exports(inbox):
          summary.files += 1
```

### c117 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """Import every export in the inbox into the store, one file at a time.
> 
> Runs unattended. Every file it reads ends the run with a marker saying what
> became of it, and the Summary says whether a person is needed.
> """
  import os
  from dataclasses import asdict, dataclass
  
```

### c118 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      """
      station = station_of(path)
      try:
>         # utf-8-sig: a byte-order mark is not part of the first column's name
          with open(path, encoding="utf-8-sig") as f:
              text = f.read()
      except UnicodeDecodeError as e:
```

### c119 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def run(inbox, store):
>     """Import every export in inbox that is not yet done into store.
> 
>     Anything that is not the file's fault (the store cannot be written) rolls
>     back that file and propagates.
>     """
      summary = Summary()
      for name in exports(inbox):
          summary.files += 1
```

### c120 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  class FailingStore(Store):
>     """A real Store whose add raises once it has been called fail_after times."""
  
      def __init__(self, path, fail_after):
          super().__init__(path)
```

### c121 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def key(reading):
>     # Station, time and quantity identify a reading in the world, so two exports
>     # whose windows overlap map the same reading to the same key.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c122 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      stored: int = 0
      duplicates: int = 0
      rejected: int = 0
>     # (name, marker) for each file that failed or was poisoned this run, for the
>     # command line's stderr lines. Not a count, so not compared.
      problems: list = field(default_factory=list, compare=False)
  
  
```

### c123 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          raise FileError(f"unknown columns: {', '.join(unknown)}")
  
      readings, rejected = [], []
>     # Row numbers are kept so a person opening the file can find a rejected row.
>     # They are not part of any key: the same reading sits at different rows in
>     # the two exports that carry it.
      for row, fields in enumerate(body, 1):
          if len(fields) != len(header):
              rejected.append(row)
```

### c124 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          for _ in range(runner.POISON_AFTER):
              self.run_once()
          self.assertEqual(self.committed().marker(A).state, "poisoned")
>         # §10: a person clears a poisoned file by deleting its marker row by hand.
          db = sqlite3.connect(self.db)
          db.execute("DELETE FROM markers WHERE name = ?", (A,))
          db.commit()
```

### c125 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def exports(inbox):
>     """The names of the *.csv files in inbox, in name order."""
      return sorted(name for name in os.listdir(inbox)
                    if name.endswith(".csv") and os.path.isfile(os.path.join(inbox, name)))
  
```

### c126 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      def test_only_csv_files_are_work(self):
          self.export(A, A_TEXT)
          write(self.inbox, "README.txt", "not an export\n")
>         write(self.inbox, ".ST014_202601151200.csv", B_TEXT)  # a copy in flight, hidden
          os.mkdir(os.path.join(self.inbox, "old.csv"))
          summary = self.run_once()
          self.assertEqual(summary, Summary(files=1, imported=1, stored=6))
```

### c127 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(summary, runner.Summary(files=2, imported=2, stored=12, duplicates=6))
          store = self.reopened()
          self.assertEqual(store.count(), 12)
>         # First stored wins: the reading is A's, row 2.
          self.assertEqual(store.get("ST014|2026-01-15T01:00|temperature")["row"], 2)
          self.assertEqual(store.marker(A).detail, "9 stored, 0 duplicates, 0 rejected")
          self.assertEqual(store.marker(B).detail, "3 stored, 6 duplicates, 0 rejected")
```

### c128 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          if store.add(key(reading), asdict(reading)):
              stored += 1
          else:
>             # first stored wins, even when the values differ
              duplicates += 1
      store.set_marker(name, "done", 0, f"{stored} stored, {duplicates} duplicates, {len(rejected)} rejected")
      store.commit()
```

### c129 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> # What the station with new firmware sends: a good export, in UTF-16.
  UTF16 = A_TEXT.encode("utf-16")
  
  
```

### c130 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  class ModuleTest(unittest.TestCase):
>     """python3 -m readings, as Phase 3's timer will run it."""
  
      def setUp(self):
          self.base = temp_dir(self)
```

### c131 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  DB_PATH = "readings.db"
  
> # The summary line's fields, in the order runner.Summary declares them.
  COUNTS = ("files", "imported", "skipped", "failed", "poisoned", "stored", "duplicates", "rejected")
  
  
```

### c132 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          if store.add(key(reading), asdict(reading)):
              stored += 1
          else:
>             duplicates += 1  # first stored wins
      store.set_marker(name, DONE, 0,
                       f"{stored} stored, {duplicates} duplicates, {len(rejected)} rejected")
      store.commit()
```

### c133 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  def parse_file(path):
>     """(readings, rejected row numbers) for one export.
> 
>     Raises FileError when the file has no station name, is not UTF-8 text, has no
>     delimiter in its header, has no time column first, or has a column the store
>     does not keep. A row that does not parse is rejected, not a reason to fail.
>     """
      station = station_of(path)
      try:
          with open(path, encoding="utf-8") as f:
```

### c134 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def fail(name, marker, detail, store, summary):
>     store.rollback()  # nothing of a failed file is kept
      failures = (0 if marker is None else marker.failures) + 1
      state = "poisoned" if failures >= POISON_AFTER else "failed"
      store.set_marker(name, state, failures, detail)
```

### c135 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          try:
              import_file(inbox, name, store, summary)
          except BaseException:
>             # Not the file's fault: keep nothing of this file and let the caller
>             # see why.
              store.rollback()
              raise
      return summary
```

### c136 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def run(inbox, store):
>     """Import every export in inbox that is not done or poisoned. Returns a Summary.
> 
>     An exception that is not a FileError is not the file's fault: the file's
>     work is rolled back and the exception propagates.
>     """
      summary = Summary()
      for name in exports(inbox):
          summary.files += 1
```

### c137 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      header, *body = dialect.rows(text, found)
      if not header or header[0] != "time":
          raise FileError("first column is not time")
>     # Checked before any row: a column nobody has mapped is the station's news,
>     # not a file full of bad rows.
      unknown = [column for column in header[1:] if column not in units.COLUMNS]
      if unknown:
          raise FileError(f"unknown column: {', '.join(unknown)}")
```

### c138 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  try:
      stored, duplicates, rejected = import_file(os.path.join(inbox, name), name, store)
  except FileError as e:
>     store.rollback()  # nothing of this file is kept
      failures = (0 if marker is None else marker.failures) + 1
      state = "poisoned" if failures >= POISON_AFTER else "failed"
      store.set_marker(name, state, failures, str(e))
```

### c139 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          parse.parse_file(path)
  
  def test_header_cut_short_is_an_unknown_column(self):
>     # a partial copy that stops inside the header line
      path = write(self.dir, "ST014_202601150600.csv", "time,temp_c,pre")
      with self.assertRaisesRegex(parse.FileError, "unknown columns: pre"):
          parse.parse_file(path)
```

### c140 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  def run(inbox, store, errors=None):
>     """Import every export in inbox into store, one file per transaction.
> 
>     A file that raises FileError is marked failed, or poisoned once it has failed
>     POISON_AFTER runs, and the run goes on. Any other exception is not the file's
>     fault: the file's work is rolled back and the exception propagates.
>     """
      errors = sys.stderr if errors is None else errors
      summary = Summary()
      for name in exports(inbox):
```

### c141 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertIsNone(self.marker("notes.txt"))
  
      def test_store_error_halfway_keeps_nothing_of_that_file(self):
>         write(self.inbox, A, HEADER + row(0))           # adds 1-3, committed
>         write(self.inbox, B, HEADER + row(5) + row(6))  # fails on its second add
          store = FailingStore(self.db, fail_on_add=5)
          try:
              with self.assertRaises(sqlite3.OperationalError):
```

### c142 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def import_file(path, name, store):
>     """Add one export's readings and mark it done, in one commit.
> 
>     Returns (stored, duplicates, rejected).
>     """
      readings, rejected = parse_file(path)
      stored = duplicates = 0
      for reading in readings:
```

### c143 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  def parse_file(path):
>     """(readings, rejected row numbers) for one export.
> 
>     Raises FileError when the file has no station name, is not UTF-8, has no
>     delimiter in its header, has no time column first, or has a column
>     units.COLUMNS does not know. A row that does not parse is rejected, not fatal.
>     """
      station = station_of(path)
      try:
          # utf-8-sig: a byte-order mark is UTF-8 too, and must not end up in the first column's name
```

### c144 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  # The summary line's fields, in the order Summary declares them.
  COUNTS = ("files", "imported", "skipped", "failed", "poisoned", "stored", "duplicates", "rejected")
  
> OK = 0              # nothing failed, and no poisoned file is in the inbox
> RETRY = 1           # a file failed and the next run retries it (the interpreter also exits 1
>                     # when run raises)
> NEEDS_A_PERSON = 3  # a poisoned file is in the inbox
> # 2, a usage error, is argparse's own.
  
  
  def summary_line(summary):
```

### c145 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """The command line: python3 -m readings [--inbox DIR] [--db PATH].
> 
> Prints one summary line to stdout and returns the exit status the timer acts on:
> 0 nothing needs a person, 1 a file failed and will be retried, 3 a poisoned file
> is in the inbox. argparse exits 2 on a usage error.
> """
  import argparse
  import dataclasses
  import os
```

### c146 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      self.addCleanup(store.close)
      with self.assertRaises(sqlite3.OperationalError):
          runner.run(self.inbox, store)
>     # Without the rollback, this commit would land B's first reading.
      store.commit()
      after = self.reopened()
      self.assertEqual(after.count(), 3)
```

### c147 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def exit_status(summary):
>     """0 nothing to do; 1 a file failed and will be retried; 3 a person is needed."""
      if summary.poisoned:
          return 3  # a poisoned file in the inbox outranks everything else
      if summary.failed:
```

