### c001 — tests/test_runner.py

```python
          self.assertEqual(self.run_once(on_problem=report), Summary(files=2, skipped=1, poisoned=1))
          self.assertEqual((self.marker(C).state, self.marker(C).failures), ("poisoned", 3))
  
>         # poisoned: skipped without being opened, failures stop at POISON_AFTER, not reported again
          self.assertEqual(self.run_once(on_problem=report), Summary(files=2, skipped=1, poisoned=1))
          self.assertEqual((self.marker(C).state, self.marker(C).failures), ("poisoned", 3))
  
```

### c002 — tests/test_runner.py

```python
          return runner.run(self.inbox, self.store)
  
      def committed(self):
>         """The store as a second connection sees it: only what was committed."""
          store = Store(self.db)
          self.addCleanup(store.close)
          return store
```

### c003 — tests/test_runner.py

```python
  
  
  class FailingStore(Store):
>     """A real store whose add raises on its nth call, as a full disk would."""
  
      def __init__(self, path, fail_on):
          super().__init__(path)
```

### c004 — readings/runner.py

```python
  
  
  def _import_file(inbox, name, previous, store, summary):
>     """Import one file and commit it with its marker; the marker when the file failed, else None."""
      try:
          readings, rejected = parse_file(os.path.join(inbox, name))
      except FileError as error:
```

### c005 — readings/runner.py

```python
  
  
  def key(reading):
>     # Station, time and quantity identify a reading in the world, so two exports
>     # whose windows overlap map the same reading to the same key.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c006 — tests/test_runner.py

```python
      def test_a_store_error_keeps_nothing_of_that_file_and_propagates(self):
          self.export(EARLY, HEADER + ROW_00)
          self.export(LATE, HEADER + ROW_01)
>         store = FailingStore(self.db, fail_after=4)  # EARLY's 3 adds, then one of LATE's
          self.addCleanup(store.close)
          with self.assertRaises(sqlite3.OperationalError):
              runner.run(self.inbox, store)
```

### c007 — tests/test_runner.py

```python
          self.addCleanup(failing.close)
          with self.assertRaises(sqlite3.OperationalError):
              self.quiet_run(failing)
>         # Whatever run left uncommitted would land here.
          failing.commit()
          reopened = Store(self.db)
          self.addCleanup(reopened.close)
```

### c008 — tests/test_runner.py

```python
          return write(self.inbox, name, HEADER + "".join(row + "\n" for row in rows))
  
      def test_overlapping_exports_store_each_reading_once(self):
>         # 06:00 is row 2 in the early export and row 1 in the late one.
          self.export(EARLY, "2026-01-15T00:00,3.1,1012.4,4.2", "2026-01-15T06:00,3.4,1012.0,4.0")
          self.export(LATE, "2026-01-15T06:00,3.4,1012.0,4.0", "2026-01-15T12:00,5.0,1011.2,3.1")
          summary = runner.run(self.inbox, self.store)
```

### c009 — readings/runner.py

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

### c010 — readings/runner.py

```python
          if store.add(key(reading), asdict(reading)):
              stored += 1
          else:
>             # first stored wins, even when the values differ
              duplicates += 1
      store.set_marker(name, "done", 0, f"{stored} stored, {duplicates} duplicates, {len(rejected)} rejected")
      store.commit()
```

### c011 — readings/parse.py

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

### c012 — tests/test_cli.py

```python
              store.close()
  
      def utf16(self, name):
>         """An export from the station whose firmware switched it to UTF-16 (§3)."""
          with open(os.path.join(self.inbox, name), "w", encoding="utf-16") as f:
              f.write(rows("2026-01-15T06:00"))
  
```

### c013 — readings/cli.py

```python
> """The command line: one import of the inbox, whose exit status says whether a person is needed."""
  import argparse
  import os
  import sys
```

### c014 — readings/runner.py

```python
> """Import every station export in the inbox into the store, one file at a time."""
  import os
  from dataclasses import asdict, dataclass
  
```

### c015 — tests/test_cli.py

```python
  
  
  def rows(*times):
>     """An export: one row per time, the same three values in each."""
      return HEADER + "".join(f"{time},3.1,1012.4,4.2\n" for time in times)
  
  
```

### c016 — tests/test_runner.py

```python
          self.addCleanup(store.close)
          with self.assertRaises(sqlite3.OperationalError):
              runner.run(self.inbox, store)
>         # Without the rollback, this commit would land B's first reading.
          store.commit()
          after = self.reopened()
          self.assertEqual(after.count(), 3)
```

### c017 — readings/parse.py

```python
  @dataclass
  class Reading:
      station: str
>     row: int  # the row's number in its file, for a person opening it; not part of any key
      time: str
      quantity: str
      value: float
```

### c018 — tests/test_runner.py

```python
          write(self.inbox, MORNING, MORNING_TEXT)
          write(self.inbox, NOON, NOON_TEXT)
          runner.run(self.inbox, self.store)
>         # Unparseable now: the second run passes only if it never opens the file.
          write(self.inbox, MORNING, "garbage\n")
          reopened = Store(self.db)
          self.addCleanup(reopened.close)
```

### c019 — tests/test_runner.py

```python
      def test_a_file_that_failed_once_imports_on_the_next_run(self):
          self.export(A, "")  # the first instant of a copy
          self.assertEqual(self.run_once().failed, 1)
>         self.export(A, HEADER + ROW[0])  # the copy has finished
          summary = self.run_once()
          self.assertEqual(summary, runner.Summary(files=1, imported=1, stored=3))
          store = self.reopened()
```

### c020 — readings/runner.py

```python
      stored: int = 0
      duplicates: int = 0
      rejected: int = 0
>     # (name, marker) for each file that failed or was poisoned this run; for stderr, not the summary line
      problems: list = field(default_factory=list)
  
  
```

### c021 — tests/test_runner.py

```python
  
  
  class RunnerCase(unittest.TestCase):
>     """A real Store on a temporary file, and an empty inbox beside it."""
  
      def setUp(self):
          base = temp_dir(self)
```

### c022 — tests/test_cli.py

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

### c023 — readings/parse.py

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

### c024 — tests/test_runner.py

```python
  
  
  class FailingStore(Store):
>     """A real Store whose n-th add fails the way a full disk does."""
  
      def __init__(self, path, fail_on_add):
          super().__init__(path)
```

### c025 — readings/runner.py

```python
  
  
  def key(reading):
>     # Station, time and quantity identify a reading in the world. Every reading
>     # arrives in two overlapping exports, at different rows, so this is the only
>     # key that can match them.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c026 — readings/runner.py

```python
  class Summary:
      """What one run did. files == imported + skipped + failed + poisoned."""
  
>     files: int = 0       # *.csv files in the inbox
>     imported: int = 0    # read this run and marked done
>     skipped: int = 0     # already done, not opened
>     failed: int = 0      # failed this run, will be retried
>     poisoned: int = 0    # poisoned, this run or before
      stored: int = 0
      duplicates: int = 0
      rejected: int = 0
```

### c027 — readings/runner.py

```python
> """Import every export in the inbox into the store, one file at a time."""
  import os
  from dataclasses import asdict, dataclass
  
```

### c028 — readings/cli.py

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

### c029 — readings/runner.py

```python
  
  
  def key(reading):
>     # Each reading arrives in two exports, at different row numbers; station,
>     # time and quantity are what the two copies share.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c030 — tests/test_runner.py

```python
  MORNING = "ST014_202601150600.csv"
  NOON = "ST014_202601151200.csv"
  
> # The 06:00 reading is row 3 of MORNING and row 1 of NOON, as when a station drops
> # empty rows before exporting.
  MORNING_TEXT = HEADER + ("2026-01-15T00:00,3.1,1012.4,4.2\n"
                           "2026-01-15T03:00,2.8,1012.0,3.9\n"
                           "2026-01-15T06:00,2.5,1011.6,3.5\n")
```

### c031 — tests/test_runner.py

```python
          first = self.run_once()
          self.assertEqual((first.failed, self.store.count()), (1, 0))
          self.assertEqual(self.store.marker(EARLY), Marker("failed", 1, "header has no delimiter"))
>         self.export(EARLY, HEADER + ROW_00)  # the complete copy arrives under the same name
          second = self.run_once()
          self.assertEqual((second.imported, second.failed, second.stored, second.problems), (1, 0, 3, []))
          store = self.reopened()
```

### c032 — readings/runner.py

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

### c033 — readings/runner.py

```python
> """Import every station export in the inbox into the store.
> 
> Runs unattended. Files are imported one at a time, in name order, and each file's
> readings land in the same transaction as its marker, so a run that stops leaves
> the store consistent with the inbox as far as it got.
> """
  import os
  from dataclasses import asdict, dataclass, field
  
```

### c034 — readings/runner.py

```python
  
  
  def key(reading):
>     # Each reading arrives in two exports, at different row numbers; station,
>     # time and quantity are what the two copies share.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c035 — tests/test_runner.py

```python
          self.assertIsNone(reopened.marker(LATE))
  
      def utf16_export(self, name):
>         # the firmware-updated station: every run will fail it
          with open(os.path.join(self.inbox, name), "wb") as f:
              f.write((HEADER + ROW_00).encode("utf-16"))
  
```

### c036 — tests/test_cli.py

```python
  
      def test_store_that_cannot_open_stops_the_run_with_1(self):
          write(self.inbox, GOOD, HEADER + ROW_0000)
>         result = self.module(temp_dir(self))  # a directory: sqlite cannot open it
          self.assertEqual((result.returncode, result.stdout), (1, ""))
          self.assertIn("OperationalError", result.stderr)
```

### c037 — tests/test_runner.py

```python
          self.addCleanup(failing.close)
          with self.assertRaises(sqlite3.OperationalError):
              runner.run(self.inbox, failing, errors=self.errors)
>         self.assertEqual(failing.count(), 9)   # rolled back on this connection too
          store = self.reopened()
          self.assertEqual(store.count(), 9)
          self.assertEqual(store.marker(A).state, "done")
```

### c038 — readings/__main__.py

```python
> """python3 -m readings: one import run over the inbox."""
  import sys
  
  from .cli import main
```

### c039 — tests/test_cli.py

```python
  
  
  class ModuleTest(unittest.TestCase):
>     """python3 -m readings, as Phase 3's timer will run it."""
  
      def setUp(self):
          self.base = temp_dir(self)
```

### c040 — readings/parse.py

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

### c041 — tests/test_runner.py

```python
  
  
  class FailingStore(Store):
>     """A real Store whose nth add raises, as a full disk would."""
  
      def __init__(self, path, fail_on):
          super().__init__(path)
```

### c042 — tests/test_runner.py

```python
  
  
  class BreaksOnAdd(Store):
>     """A real Store whose nth add fails, as a full disk would."""
  
      def __init__(self, path, fail_on):
          super().__init__(path)
```

### c043 — readings/runner.py

```python
  
  
  def exports(inbox):
>     """Names of the *.csv files in inbox, in name order."""
      return sorted(name for name in os.listdir(inbox)
                    if name.endswith(".csv") and os.path.isfile(os.path.join(inbox, name)))
  
```

### c044 — tests/test_cli.py

```python
          self.assertTrue(os.path.exists(os.path.join(self.base, "readings.db")))
  
      def test_a_run_that_stops_exits_1(self):
>         result = self.module("--db", "inbox")  # a directory is no database
          self.assertEqual(result.returncode, 1)
          self.assertEqual(result.stdout, "")
          self.assertIn("OperationalError", result.stderr)
```

### c045 — readings/runner.py

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

### c046 — readings/cli.py

```python
> """python3 -m readings: import the inbox once, and say by exit status whether a person is needed."""
  import argparse
  import os
  import sys
```

### c047 — readings/cli.py

```python
          if not os.path.isdir(args.inbox):
              parser.error(f"inbox not found: {args.inbox}")
      except SystemExit as e:
>         # argparse exits on a usage error; main returns the status instead.
          return e.code
      store = Store(args.db)
      try:
```

### c048 — readings/runner.py

```python
              duplicates += 1
      store.set_marker(name, "done", 0, f"{stored} stored, {duplicates} duplicates, {len(rejected)} rejected")
      store.commit()
>     # counted only once committed, so the summary never claims what the store lacks
      summary.imported += 1
      summary.stored += stored
      summary.duplicates += duplicates
```

### c049 — tests/test_parse.py

```python
          self.assertEqual(sorted({r.row for r in readings}), [1, 3])
  
      def test_file_that_cannot_be_opened_fails_the_file(self):
>         # listed in the inbox, then gone (or unreadable) by the time it is opened
          missing = os.path.join(self.dir, NAME)
          with self.assertRaisesRegex(parse.FileError, "^cannot read: "):
              parse.parse_file(missing)
```

### c050 — readings/runner.py

```python
  
  
  def _import(path, name, previous, store, summary):
>     """Stage one file's readings and its new marker in store, uncommitted; return the marker."""
      try:
          readings, rejected = parse_file(path)
      except FileError as e:
```

### c051 — readings/runner.py

```python
  
  INBOX_DIR = "inbox"
  
> # A file that has failed this many runs is poisoned and skipped from then on.
> # Eighteen hours at Phase 3's six-hour interval; no partial copy in the measured
> # fortnight took more than one retry.
  POISON_AFTER = 3
  
  DONE = "done"
```

### c052 — readings/cli.py

```python
> """The command line: import the inbox once, and exit with a status a timer can act on."""
  import argparse
  import os
  from dataclasses import fields
```

### c053 — tests/test_runner.py

```python
          self.export(A, A_TEXT[:20])  # cut mid-header: "time,temp_c,pressure"
          self.assertEqual(self.run_once(), Summary(files=1, failed=1))
          self.assertEqual(self.committed().marker(A).failures, 1)
>         self.export(A, A_TEXT)  # the copy has finished
          summary = self.run_once()
          self.assertEqual(summary, Summary(files=1, imported=1, stored=6))
          self.assertEqual(summary.problems, [])
```

### c054 — readings/cli.py

```python
  
  
  def status(summary):
>     # A poisoned file needs a person whatever else happened, so it outranks a failure.
      if summary.poisoned:
          return 3
      if summary.failed:
```

### c055 — tests/test_runner.py

```python
          self.assertEqual(self.marker(A), Marker("failed", 1, "unknown columns: humidity"))
  
      def test_partial_copy_that_fails_imports_on_the_next_run(self):
>         # copied up to the middle of the header, then completed before the next run
          write(self.inbox, A, "time,temp_c,pres")
          self.assertEqual(self.run_once(), Summary(files=1, failed=1))
          self.assertEqual(self.marker(A), Marker("failed", 1, "unknown columns: pres"))
```

### c056 — readings/runner.py

```python
  from .parse import FileError, parse_file
  
  INBOX_DIR = "inbox"
> POISON_AFTER = 3  # failed runs before a file is skipped for good
  
  
  @dataclass
```

### c057 — tests/test_runner.py

```python
          self.addCleanup(failing.close)
          with self.assertRaises(sqlite3.OperationalError):
              self.run_once(failing)
>         failing.commit()  # would land anything the run left uncommitted
          self.assertEqual(self.store.count(), 3)
          self.assertEqual(self.store.marker(FIRST), Marker("done", 0, "3 stored, 0 duplicates, 0 rejected"))
          self.assertIsNone(self.store.marker(SECOND))
```

### c058 — readings/runner.py

```python
          if store.add(key(reading), asdict(reading)):
              stored += 1
          else:
>             duplicates += 1  # first stored wins
      store.set_marker(name, DONE, 0,
                       f"{stored} stored, {duplicates} duplicates, {len(rejected)} rejected")
      store.commit()
```

### c059 — readings/cli.py

```python
      parser.add_argument("--inbox", default=INBOX_DIR, help=f"the inbox directory (default: {INBOX_DIR})")
      parser.add_argument("--db", default=DEFAULT_DB, help=f"the store's SQLite file (default: {DEFAULT_DB})")
      args = parser.parse_args(argv)
>     # before the store is opened, so a mistyped inbox leaves no empty database behind
      if not os.path.isdir(args.inbox):
          parser.error(f"no inbox at {args.inbox}")
  
```

### c060 — readings/runner.py

```python
  
  
  def exports(inbox):
>     """(name, path) for each *.csv file in inbox, in name order."""
      found = []
      for name in sorted(os.listdir(inbox)):
          path = os.path.join(inbox, name)
```

### c061 — readings/runner.py

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

### c062 — readings/cli.py

```python
  
  
  def summary_line(summary):
>     """The summary's fields as name=value, space-separated, in declaration order."""
      return " ".join(f"{field.name}={getattr(summary, field.name)}" for field in fields(summary))
  
  
```

### c063 — readings/runner.py

```python
  
  @dataclass
  class Summary:
>     """What one run did. files == imported + skipped + failed + poisoned."""
  
      files: int = 0       # *.csv files in the inbox
      imported: int = 0    # read this run and marked done
```

### c064 — readings/runner.py

```python
  
  
  def run(inbox, store):
>     """Import every export in inbox that is not done or poisoned into store."""
      summary = Summary()
      for name in exports(inbox):
          summary.files += 1
```

### c065 — readings/cli.py

```python
  
  
  def main(argv):
>     """Import the inbox once, print the summary line, and return the exit status.
> 
>     0: nothing failed and no poisoned file is in the inbox. 1: a file failed this
>     run and will be retried. 3: a poisoned file is in the inbox, whatever else
>     happened. A usage error exits 2 through argparse.
>     """
      parser = argparse.ArgumentParser(prog="python3 -m readings",
                                       description="Import the station exports in the inbox.")
      parser.add_argument("--inbox", default=INBOX_DIR, help=f"default: {INBOX_DIR}")
```

### c066 — readings/parse.py

```python
      """
      station = station_of(path)
      try:
>         # utf-8-sig: a byte-order mark is UTF-8 too, and must not end up in the first column's name
          with open(path, encoding="utf-8-sig") as f:
              text = f.read()
      except UnicodeDecodeError as e:
```

### c067 — readings/runner.py

```python
  
  
  def run(inbox, store, report=None):
>     """Import every *.csv file in inbox, in name order, into store; return a Summary.
> 
>     A file's readings and its marker are committed together. report(name, marker),
>     when given, is called for each file that failed or was poisoned this run. An
>     exception that is not a FileError rolls back the file in hand and propagates.
>     """
      summary = Summary()
      for name in sorted(os.listdir(inbox)):
          path = os.path.join(inbox, name)
```

### c068 — readings/cli.py

```python
  from .store import Store
  
  OK = 0
> RETRYING = 1   # a file failed and will be retried; also the interpreter's status for an uncaught error
> POISONED = 3   # a poisoned file is in the inbox: a person must clear its marker
  
  
  def summary_line(summary):
```

### c069 — tests/test_runner.py

```python
  
  
  class FailingStore(Store):
>     """A real Store whose nth add raises, as a full disk would."""
  
      def __init__(self, path, fail_on):
          super().__init__(path)
```

### c070 — readings/cli.py

```python
  
  
  def summary_line(summary):
>     """'files=4 imported=2 ...': every Summary field, in declaration order."""
      return " ".join(f"{field.name}={getattr(summary, field.name)}"
                      for field in dataclasses.fields(summary))
  
```

### c071 — tests/test_runner.py

```python
          real_add = self.store.add
  
          def add(key, reading):
>             # B's 02:00 temperature has been added, uncommitted, when this fails.
              if key == "ST014|2026-01-15T02:00|pressure":
                  raise sqlite3.OperationalError("disk I/O error")
              return real_add(key, reading)
```

### c072 — readings/runner.py

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

### c073 — tests/test_cli.py

```python
          write_utf16(self.inbox, D)
  
          runs = [self.main() for _ in range(3)]
>         write(self.inbox, B, HEADER + row(5))  # a new export arrives before the fourth run
          runs.append(self.main())
  
          self.assertEqual([status for status, _, _ in runs], [1, 1, 3, 3])
```

### c074 — readings/runner.py

```python
  
  
  def _fail(name, previous, error, store, summary):
>     store.rollback()  # nothing of this file is kept
      failures = (previous.failures if previous is not None else 0) + 1
      marker = Marker(POISONED if failures >= POISON_AFTER else FAILED, failures, str(error))
      store.set_marker(name, marker.state, marker.failures, marker.detail)
```

### c075 — tests/test_runner.py

```python
          self.assertEqual(store.marker(A), Marker("failed", 1, "unknown column: humidity"))
  
      def test_a_file_that_failed_once_imports_on_the_next_run(self):
>         self.export(A, "")  # the first instant of a copy
          self.assertEqual(self.run_once().failed, 1)
          self.export(A, HEADER + ROW[0])  # the copy has finished
          summary = self.run_once()
```

### c076 — readings/parse.py

```python
  
  
  def parse_file(path):
>     """(readings, rejected row numbers) for one export.
> 
>     Raises FileError when the file's name is not a station export's, it is not
>     UTF-8, its header has no delimiter, its first column is not time, or it has a
>     column units.COLUMNS does not know.
>     """
      station = station_of(path)
      try:
          with open(path, encoding="utf-8") as f:
```

### c077 — readings/runner.py

```python
> """Import every export in the inbox into the store, one file at a time.
> 
> Runs unattended. Every file it reads ends the run with a marker saying what
> became of it, and the Summary says whether a person is needed.
> """
  import os
  from dataclasses import asdict, dataclass, field
  
```

### c078 — tests/test_runner.py

```python
          for _ in range(runner.POISON_AFTER):
              self.run_once()
          self.assertEqual(self.committed().marker(A).state, "poisoned")
>         # §10: a person clears a poisoned file by deleting its marker row by hand.
          db = sqlite3.connect(self.db)
          db.execute("DELETE FROM markers WHERE name = ?", (A,))
          db.commit()
```

### c079 — readings/runner.py

```python
  
  
  def key(reading):
>     # Station, time and quantity identify a reading in the world; a row number
>     # only identifies it in one file, and overlapping exports differ in rows.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c080 — readings/runner.py

```python
  
  @dataclass
  class Summary:
>     """What one run did. files == imported + skipped + failed + poisoned.
> 
>     Attributes:
>         files: *.csv files in the inbox.
>         imported: read this run and marked done.
>         skipped: already done, not opened.
>         failed: failed this run, will be retried.
>         poisoned: poisoned, this run or before.
>         stored, duplicates: readings of the files imported this run.
>         rejected: rows of the files imported this run that did not parse.
>     """
      files: int = 0
      imported: int = 0
      skipped: int = 0
```

### c081 — tests/test_runner.py

```python
          self.addCleanup(self.store.close)
  
      def run_once(self, store=None):
>         """(Summary, stderr) of one run."""
          err = io.StringIO()
          with contextlib.redirect_stderr(err):
              summary = runner.run(self.inbox, store or self.store)
```

### c082 — tests/test_runner.py

```python
              db.close()
  
      def test_overlapping_exports_store_each_reading_once(self):
>         # 01:00 is row 2 of A and row 1 of B: a row key would store it twice.
          self.export(A, rows("2026-01-15T00:00", "2026-01-15T01:00", "2026-01-15T02:00"))
          self.export(B, rows("2026-01-15T01:00", "2026-01-15T02:00", "2026-01-15T03:00"))
          self.assertEqual(self.run_once(), Summary(files=2, imported=2, stored=12, duplicates=6))
```

### c083 — tests/test_runner.py

```python
          self.assertEqual(summary, runner.Summary(files=2, imported=2, stored=12, duplicates=6))
          store = self.reopened()
          self.assertEqual(store.count(), 12)
>         # First stored wins: the reading is A's, row 2.
          self.assertEqual(store.get("ST014|2026-01-15T01:00|temperature")["row"], 2)
          self.assertEqual(store.marker(A).detail, "9 stored, 0 duplicates, 0 rejected")
          self.assertEqual(store.marker(B).detail, "3 stored, 6 duplicates, 0 rejected")
```

### c084 — readings/runner.py

```python
      stored: int = 0
      duplicates: int = 0
      rejected: int = 0
>     # (name, marker) for each file that failed or was poisoned this run, for the
>     # command line's stderr lines. Not a count, so not compared.
      problems: list = field(default_factory=list, compare=False)
  
  
```

### c085 — tests/test_cli.py

```python
  OTHER = "ST031_202601150600.csv"
  
  EARLY_TEXT = HEADER + "2026-01-15T00:00,3.1,1012.4,4.2\n"
> # One reading row repeats EARLY's, one is a clock reset, one is new.
  LATER_TEXT = HEADER + ("2026-01-15T00:00,3.1,1012.4,4.2\n"
                         "--:--,3.0,1012.1,4.0\n"
                         "2026-01-15T06:00,2.5,1011.6,3.5\n")
```

### c086 — tests/test_runner.py

```python
          for number, (summary, marker) in enumerate(expected, 1):
              with self.subTest(run=number):
                  if number == 4:
>                     # Parseable now: the fourth run passes only if it never opens the file.
                      write(self.inbox, BROKEN, MORNING_TEXT)
                  got, problems = self.run_once()
                  self.assertEqual(got, summary)
```

### c087 — readings/runner.py

```python
  
  
  def key(reading):
>     """The store key: two exports carrying the same reading give it the same key."""
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c088 — tests/test_runner.py

```python
          self.assertEqual(store.marker(other).state, "done")
  
      def test_partial_copy_imports_once_complete(self):
>         self.export(A, A_TEXT[:20])  # cut mid-header: "time,temp_c,pressure"
          self.assertEqual(self.run_once(), Summary(files=1, failed=1))
          self.assertEqual(self.committed().marker(A).failures, 1)
          self.export(A, A_TEXT)  # the copy has finished
```

### c089 — readings/cli.py

```python
  
  
  def exit_status(summary):
>     """3 when a poisoned file is in the inbox, else 1 when a file failed this run, else 0."""
      if summary.poisoned:
          return 3
      if summary.failed:
```

### c090 — tests/test_runner.py

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

### c091 — readings/runner.py

```python
  
  
  def run(inbox, store):
>     """Import every export in inbox that is not done or poisoned. Returns a Summary.
> 
>     An exception that is not a FileError is not the file's fault: the file's
>     work is rolled back and the exception propagates. A FileError fails the file,
>     which is retried on the next run and poisoned after POISON_AFTER failed runs.
>     """
      summary = Summary()
      for name in exports(inbox):
          summary.files += 1
```

### c092 — tests/helpers.py

```python
  
  
  def row(hour):
>     """One good row of HEADER at <hour>:00 on 2026-01-15, holding three readings."""
      return f"2026-01-15T{hour:02d}:00,3.{hour},1012.{hour},4.{hour}\n"
  
  
```

### c093 — readings/runner.py

```python
  
  
  def exports(inbox):
>     """The names of the *.csv files in inbox, in name order."""
      return sorted(name for name in os.listdir(inbox)
                    if name.endswith(".csv") and os.path.isfile(os.path.join(inbox, name)))
  
```

### c094 — tests/helpers.py

```python
      return handle.name
  
  
> # One row of HEADER per hour: three readings each (temperature, pressure, wind).
  ROW = {hour: f"2026-01-15T{hour:02d}:00,{3.0 + hour / 10:.1f},1012.{hour},4.{hour}\n"
         for hour in range(24)}
```

### c095 — readings/cli.py

```python
  
  
  def summary_line(summary):
>     """'files=4 imported=2 ...', every Summary field in declaration order."""
      return " ".join(f"{field.name}={getattr(summary, field.name)}"
                      for field in dataclasses.fields(summary))
  
```

### c096 — tests/test_runner.py

```python
          self.assertEqual(store.count(), 3)  # LATE's readings, stored once on the first run
  
      def test_a_failed_file_is_retried_and_imports_once_complete(self):
>         self.export(EARLY, "time")  # a copy cut short inside the header
          first = self.run_once()
          self.assertEqual((first.failed, self.store.count()), (1, 0))
          self.assertEqual(self.store.marker(EARLY), Marker("failed", 1, "header has no delimiter"))
```

### c097 — readings/__main__.py

```python
> """python3 -m readings: one run over the inbox, exiting with its status."""
  import sys
  
  from .cli import main
```

### c098 — tests/test_runner.py

```python
          self.assertEqual(store.marker(A), Marker("done", 0, "3 stored, 0 duplicates, 0 rejected"))
  
      def test_a_poisoned_file_is_not_opened(self):
>         self.export(A, HEADER + ROW[0])  # would import, if it were opened
          self.store.set_marker(A, "poisoned", 3, "not text")
          self.store.commit()
          summary = self.run_once()
```

### c099 — tests/test_cli.py

```python
      def test_store_error_propagates(self):
          write(self.inbox, A, HEADER + row(0))
          with self.assertRaises(sqlite3.OperationalError):
>             self.main("--inbox", self.inbox, "--db", self.inbox)  # a directory is no database
  
  
  class ModuleTest(unittest.TestCase):
```

### c100 — tests/helpers.py

```python
      return handle.name
  
  
> # Two consecutive exports of one station. B's window overlaps A's by an hour:
> # the 01:00 reading is A's second row and B's first, as when a station drops an
> # empty row before exporting. Three readings per row.
  A = "ST014_202601150600.csv"
  B = "ST014_202601151200.csv"
  A_TEXT = HEADER + "2026-01-15T00:00,3.1,1012.4,4.2\n" + "2026-01-15T01:00,3.0,1012.1,3.9\n"
```

### c101 — readings/parse.py

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

### c102 — readings/runner.py

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

### c103 — tests/test_runner.py

```python
  
  
  class FailingStore(Store):
>     """A real Store whose writes start failing partway, as a full disk would."""
  
      def __init__(self, path, fail_after):
          super().__init__(path)
```

### c104 — readings/cli.py

```python
  
  
  def main(argv):
>     """Run one import and return the exit status.
> 
>     A usage error, including an inbox that is not a directory, raises
>     SystemExit(2) through argparse.
>     """
      parser = argparse.ArgumentParser(prog="python3 -m readings",
                                       description="Import station exports from the inbox into the store.")
      parser.add_argument("--inbox", default=runner.INBOX_DIR)
```

### c105 — readings/runner.py

```python
  
  
  def run(inbox, store):
>     """Import every *.csv file in inbox into store, in name order; return a Summary.
> 
>     A file's readings and its marker are committed together. A FileError fails
>     that file and the run goes on; any other exception rolls back the file in
>     hand and propagates.
>     """
      summary = Summary()
      for name in exports(inbox):
          summary.files += 1
```

### c106 — readings/cli.py

```python
  
  
  def exit_status(summary):
>     # Phase 3's timer acts on this alone, so a poisoned file wins over everything else.
      if summary.poisoned:
          return NEEDS_A_PERSON
      if summary.failed:
```

### c107 — tests/test_runner.py

```python
      def test_only_csv_files_are_work(self):
          self.export(A, A_TEXT)
          write(self.inbox, "README.txt", "not an export\n")
>         write(self.inbox, ".ST014_202601151200.csv", B_TEXT)  # a copy in flight, hidden
          os.mkdir(os.path.join(self.inbox, "old.csv"))
          summary = self.run_once()
          self.assertEqual(summary, Summary(files=1, imported=1, stored=6))
```

### c108 — readings/runner.py

```python
> """Import every export in the inbox into the store, one file at a time."""
  import dataclasses
  import os
  from dataclasses import dataclass
```

### c109 — tests/test_cli.py

```python
          self.db = os.path.join(temp_dir(self), "readings.db")
  
      def main(self, argv=None):
>         """(status, stdout, stderr) of one cli.main call."""
          out, err = io.StringIO(), io.StringIO()
          with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
              status = cli.main(["--inbox", self.inbox, "--db", self.db] if argv is None else argv)
```

### c110 — readings/parse.py

```python
      """
      station = station_of(path)
      try:
>         # An editor that saves an export as UTF-8 may put a byte-order mark
>         # in front of "time"; utf-8-sig drops it.
          with open(path, encoding="utf-8-sig") as f:
              text = f.read()
      except UnicodeDecodeError as e:
```

### c111 — readings/parse.py

```python
  
  
  def parse_file(path):
>     """(readings, rejected row numbers) for one export.
> 
>     Raises FileError when the file's name is not a station export, it is not
>     UTF-8, its header has no delimiter, its first column is not time, or it has
>     a column units.COLUMNS does not know.
>     """
      station = station_of(path)
      try:
          with open(path, encoding="utf-8") as f:
```

### c112 — tests/helpers.py

```python
  
  
  def row(hour, temp):
>     """One line of an export under HEADER, for 2026-01-15 at the given hour."""
      return f"2026-01-15T{hour:02d}:00,{temp},1012.4,4.2\n"
```

### c113 — readings/parse.py

```python
      header, *body = dialect.rows(text, found)
      if not header or header[0] != "time":
          raise FileError("first column is not time")
>     # Checked before any row, so an unmapped column fails the file instead of
>     # rejecting each of its rows.
      unknown = [column for column in header[1:] if column not in units.COLUMNS]
      if unknown:
          raise FileError(f"unknown columns: {', '.join(unknown)}")
```

### c114 — readings/cli.py

```python
  
  
  def summary_line(summary):
>     """'files=4 imported=2 ...', every Summary field in declaration order."""
      return " ".join(f"{field.name}={getattr(summary, field.name)}" for field in fields(summary))
  
  
```

### c115 — tests/test_cli.py

```python
          self.db = os.path.join(base, "readings.db")
  
      def main(self, *extra):
>         """(status, stdout, stderr) of one cli.main run against this test's inbox and db."""
          out, err = io.StringIO(), io.StringIO()
          with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
              status = cli.main(["--inbox", self.inbox, "--db", self.db, *extra])
```

### c116 — tests/test_parse.py

```python
              parse.parse_file(path)
  
      def test_header_cut_short_is_an_unknown_column(self):
>         # a partial copy that stops inside the header line
          path = write(self.dir, "ST014_202601150600.csv", "time,temp_c,pre")
          with self.assertRaisesRegex(parse.FileError, "unknown columns: pre"):
              parse.parse_file(path)
```

### c117 — tests/test_runner.py

```python
  
      def test_overlapping_exports_store_each_reading_once(self):
          write(self.inbox, A, HEADER + row(0) + row(1) + row(2))
>         # the next export: 01:00 is row 1 here and row 2 in A
          write(self.inbox, B, HEADER + row(1) + row(2) + row(3))
  
          self.assertEqual(self.run_once(), Summary(files=2, imported=2, stored=12, duplicates=6))
```

### c118 — readings/runner.py

```python
  from .store import Marker
  
  INBOX_DIR = "inbox"
> # A partial copy parses a run later; a file still failing after three runs
> # (eighteen hours at a six-hour interval) will not, and needs a person.
  POISON_AFTER = 3
  
  
```

### c119 — readings/parse.py

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

### c120 — readings/__main__.py

```python
> """python3 -m readings: import the inbox once, and exit with cli.main's status."""
  import sys
  
  from .cli import main
```

### c121 — tests/test_runner.py

```python
              self.assertIsNone(store.marker(name))
  
      def test_files_are_imported_in_name_order(self):
>         # Written newest first; the older export must still be read first and win.
          self.export(B, HEADER + "2026-01-15T01:00,9.9,1012.1,4.1\n")
          self.export(A, HEADER + "2026-01-15T01:00,3.1,1012.1,4.1\n")
          self.run_once()
```

### c122 — readings/runner.py

```python
  
  
  def run(inbox, store, on_problem=None):
>     """Import every *.csv file in inbox, in name order, into store.
> 
>     Each file's readings and its marker are committed together. A file that raises
>     FileError is marked failed, or poisoned once it has failed POISON_AFTER runs, and
>     the run goes on; a poisoned file is not opened again. on_problem, if given, is
>     called as on_problem(name, marker) for each file counted failed or poisoned.
>     Any other exception is rolled back, keeping nothing of the file being read, and
>     propagates.
>     """
      summary = Summary()
      for name in _exports(inbox):
          summary.files += 1
```

### c123 — readings/parse.py

```python
  
  
  def parse_file(path):
>     """(readings, rejected row numbers) for one export.
> 
>     Raises FileError when the file's name is not a station export's, it is not
>     UTF-8, its header has no delimiter, its first column is not time, or it has a
>     column units.COLUMNS does not know.
>     """
      station = station_of(path)
      try:
          # An editor that saves an export as UTF-8 may put a byte-order mark
```

### c124 — readings/cli.py

```python
                          help="the store's SQLite file (default: readings.db)")
      args = parser.parse_args(argv)
      if not os.path.isdir(args.inbox):
>         parser.error(f"inbox is not a directory: {args.inbox}")  # exits 2
  
      store = Store(args.db)
      try:
```

### c125 — tests/test_runner.py

```python
          self.assertEqual(store.marker(B), Marker("done", 0, "3 stored, 3 duplicates, 0 rejected"))
  
      def test_first_export_in_name_order_wins(self):
>         # B is written first, carrying a different 01:00 temperature; A sorts first.
          self.export(B, HEADER + "2026-01-15T01:00,3.5,1012.1,3.9\n")
          self.export(A, A_TEXT)
          summary = self.run_once()
```

### c126 — readings/cli.py

```python
> """python3 -m readings: import the inbox once, and say by exit status whether a person is needed."""
  import argparse
  import dataclasses
  import os
```

### c127 — tests/test_runner.py

```python
          self.assertEqual(store.marker(A), Marker("done", 0, "3 stored, 0 duplicates, 0 rejected"))
  
      def test_overlapping_exports_store_each_reading_once(self):
>         # A station that drops empty rows: 01:00 is row 2 in A and row 1 in B.
          self.export(A, HEADER + ROW[0] + ROW[1] + ROW[2])
          self.export(B, HEADER + ROW[1] + ROW[2] + ROW[3])
          summary = self.run_once()
```

### c128 — tests/test_cli.py

```python
          self.db = os.path.join(base, "readings.db")
  
      def invoke(self, argv):
>         """(exit status, stdout, stderr) of cli.main(argv)."""
          out, err = io.StringIO(), io.StringIO()
          with redirect_stdout(out), redirect_stderr(err):
              try:
```

### c129 — readings/runner.py

```python
  
  
  def key(reading):
>     """The store key of a reading: its station, time and quantity."""
      # A reading arrives in two overlapping exports, at a different row in each;
      # only station, time and quantity match across them.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
```

### c130 — readings/runner.py

```python
  
  
  def key(reading):
>     """The store key of a reading: the same in every export that carries it."""
      # Not the row: the two exports that carry a reading carry it at different rows.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
```

### c131 — readings/runner.py

```python
      stored: int = 0
      duplicates: int = 0
      rejected: int = 0
>     # (name, Marker) for each file that failed or became poisoned this run
      problems: list = field(default_factory=list)
  
  
```

### c132 — tests/test_cli.py

```python
          self.db = os.path.join(directory, "readings.db")
  
      def main(self, *argv):
>         """(exit status, stdout, stderr) of one cli.main over the test inbox and store."""
          out, err = io.StringIO(), io.StringIO()
          with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
              status = cli.main(["--inbox", self.inbox, "--db", self.db, *argv])
```

### c133 — tests/test_runner.py

```python
          self.assertEqual(runner.key(reading), "ST014|2026-01-15T00:00|temperature")
  
      def test_overlapping_exports_store_each_reading_once(self):
>         # Written in reverse name order: the run's order must come from the names.
          write(self.inbox, SECOND, HEADER + ROW_0100 + ROW_0200)
          write(self.inbox, FIRST, HEADER + ROW_0000 + ROW_0100)
          self.assertEqual(self.run_once(),
```

### c134 — readings/cli.py

```python
> """The command line: one unattended run over the inbox, answered by exit status."""
  import argparse
  import os
  import sys
```

### c135 — readings/parse.py

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

### c136 — readings/runner.py

```python
> """Import every export in the inbox into the store, one file at a time."""
  import os
  import sys
  from dataclasses import asdict, dataclass
```

### c137 — readings/runner.py

```python
  
  
  def exports(inbox):
>     """Names of the inbox's *.csv files, in name order."""
      return sorted(entry.name for entry in os.scandir(inbox)
                    if entry.name.endswith(".csv") and entry.is_file())
  
```

### c138 — readings/runner.py

```python
          try:
              import_file(inbox, name, store, summary)
          except BaseException:
>             # Not the file's fault (import_file handles FileError): keep nothing
>             # of this file and let the caller see why.
              store.rollback()
              raise
      return summary
```

### c139 — readings/cli.py

```python
  
  DB_PATH = "readings.db"
  
> # The summary line's fields, in the order runner.Summary declares them.
  COUNTS = ("files", "imported", "skipped", "failed", "poisoned", "stored", "duplicates", "rejected")
  
  
```

### c140 — tests/test_runner.py

```python
          self.assertEqual(store.marker(EARLY), Marker("done", 0, "6 stored, 0 duplicates, 1 rejected"))
  
      def test_files_are_imported_in_name_order(self):
>         # The later export carries a different value for 01:00; first stored wins,
>         # and the first is the earlier name, whatever order the files were written in.
          self.export(LATE, HEADER + "2026-01-15T01:00,9.9,1012.1,3.9\n")
          self.export(EARLY, HEADER + ROW_01)
          self.run_once()
```

### c141 — readings/cli.py

```python
  
  
  def main(argv=None):
>     """Run one import over the inbox and return the process's exit status.
> 
>     0: nothing needs a person. 1: a file failed and will be retried. 2: usage
>     error. 3: a poisoned file is in the inbox. An exception from the store
>     propagates.
>     """
      parser = argparse.ArgumentParser(prog="python3 -m readings")
      parser.add_argument("--inbox", default=runner.INBOX_DIR)
      parser.add_argument("--db", default=DB_PATH)
```

### c142 — tests/test_runner.py

```python
          self.assertEqual(self.store.marker(EARLY), Marker("done", 0, "3 stored, 0 duplicates, 1 rejected"))
  
      def test_files_are_imported_in_name_order(self):
>         # Written late first, so directory order and name order are likely to differ.
          self.export(LATE, "2026-01-15T06:00,9.9,1012.0,4.0")
          self.export(EARLY, "2026-01-15T06:00,3.4,1012.0,4.0")
          runner.run(self.inbox, self.store)
```

### c143 — readings/runner.py

```python
  from .store import Marker
  
  INBOX_DIR = "inbox"
> POISON_AFTER = 3  # failed runs; eighteen hours at Phase 3's six-hour interval
  
  
  def key(reading):
```

### c144 — tests/test_runner.py

```python
          self.assertEqual(summary, Summary(files=2, imported=2, stored=9, duplicates=3))
          store = self.open_store()
          self.assertEqual(store.count(), 9)
>         # Name order imports EARLY first, so the overlapping reading keeps EARLY's row.
          self.assertEqual(store.get("ST014|2026-01-15T01:00|temperature"),
                           {"station": "ST014", "row": 2, "time": "2026-01-15T01:00",
                            "quantity": "temperature", "value": 3.0})
```

### c145 — readings/runner.py

```python
  
  def key(reading):
      """The store key of a reading: the same in every export that carries it."""
>     # Not the row: the two exports that carry a reading carry it at different rows.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c146 — readings/cli.py

```python
  def exit_status(summary):
      """0 nothing to do; 1 a file failed and will be retried; 3 a person is needed."""
      if summary.poisoned:
>         return 3  # a poisoned file in the inbox outranks everything else
      if summary.failed:
          return 1
      return 0
```

### c147 — readings/parse.py

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

### c148 — readings/cli.py

```python
  
  
  def exit_status(summary):
>     """0 nothing needs a person; 1 a failure the next run retries; 3 a person is needed."""
      if summary.poisoned:
          return 3
      if summary.failed:
```

### c149 — readings/cli.py

```python
  
  
  def main(argv=None):
>     """Run one import and return its exit status.
> 
>     0: nothing needs a person. 1: a file failed and will be retried. 3: a
>     poisoned file is in the inbox, whatever else happened. A usage error exits 2
>     through argparse; an exception from the run propagates.
>     """
      parser = argparse.ArgumentParser(prog="python3 -m readings",
                                       description="Import station exports from the inbox.")
      parser.add_argument("--inbox", default=runner.INBOX_DIR, help="the inbox directory")
```

### c150 — tests/test_runner.py

```python
          self.assertTrue(markers[0].detail.startswith("not text: "))
          self.assertEqual(summaries[0].problems, [(A, markers[0])])
          self.assertEqual(summaries[2].problems, [(A, markers[2])])
>         self.assertEqual(summaries[3].problems, [])  # poisoned before, not opened this run
          self.assertEqual(self.committed().count(), 0)
  
      def test_unknown_column_fails_the_file_and_the_run_goes_on(self):
```

### c151 — readings/cli.py

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

### c152 — readings/runner.py

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

### c153 — tests/test_cli.py

```python
  
  
  class ModuleTest(unittest.TestCase):
>     """python3 -m readings, through a real interpreter: the exit status the timer sees."""
  
      def setUp(self):
          self.base = temp_dir(self)
```

### c154 — tests/helpers.py

```python
  
  
  def write_utf16(directory, name):
>     """A good export as the station with the firmware update writes it: UTF-16 with a BOM."""
      return write_bytes(directory, name, b"\xff\xfe" + (HEADER + row(0)).encode("utf-16-le"))
```

### c155 — readings/runner.py

```python
> """Import every station export in the inbox into the store, with nobody watching.
> 
> A file's readings and its marker are committed together, so a run that stops
> part-way leaves the store consistent with the inbox as far as it got.
> """
  import os
  from dataclasses import asdict, dataclass
  
```

### c156 — readings/parse.py

```python
          raise FileError(f"unknown column: {', '.join(unknown)}")
  
      readings, rejected = [], []
>     # Numbered for a person looking for the row in the file; no key uses it.
      for row, fields in enumerate(body, 1):
          if len(fields) != len(header):
              rejected.append(row)
```

### c157 — readings/runner.py

```python
          try:
              stored, duplicates, rejected = import_file(os.path.join(inbox, name), name, store)
          except FileError as e:
>             store.rollback()  # nothing of this file is kept
              failures = (0 if marker is None else marker.failures) + 1
              state = "poisoned" if failures >= POISON_AFTER else "failed"
              store.set_marker(name, state, failures, str(e))
```

### c158 — readings/runner.py

```python
  
  
  def key(reading):
>     """The reading's store key: the same in every export that carries it."""
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c159 — readings/parse.py

```python
  
  
  def parse_file(path):
>     """(readings, rejected row numbers) for one export.
> 
>     Raises FileError when the file has no station name, is not UTF-8 text, has no
>     delimiter in its header, does not start with a time column, or has a column
>     units.COLUMNS does not know.
>     """
      station = station_of(path)
      try:
          with open(path, encoding="utf-8") as f:
```

### c160 — tests/test_runner.py

```python
  
  
  def rows(*times):
>     """An export: one row per time, the same three values in each."""
      return HEADER + "".join(f"{time},3.1,1012.4,4.2\n" for time in times)
  
  
```

### c161 — readings/runner.py

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

### c162 — readings/runner.py

```python
  
  
  def exports(inbox):
>     """The names of the *.csv files in inbox, in name order.
> 
>     Hidden names are not matched, so a copy still in flight under one is left alone.
>     """
      return sorted(name for name in glob.glob("*.csv", root_dir=inbox)
                    if os.path.isfile(os.path.join(inbox, name)))
  
```

### c163 — readings/runner.py

```python
  
  
  def exports(inbox):
>     """The names of the inbox's *.csv files, in name order."""
      return sorted(name for name in os.listdir(inbox)
                    if name.endswith(".csv") and os.path.isfile(os.path.join(inbox, name)))
  
```

### c164 — readings/runner.py

```python
  
  
  def key(reading):
>     # Station, time and quantity identify a reading in the world. Every reading
>     # arrives in two overlapping exports, at different rows, and this key is
>     # what lets the second copy match the first.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c165 — tests/test_runner.py

```python
  
  
  class FailingStore(Store):
>     """A real Store whose add raises once it has been called fail_after times."""
  
      def __init__(self, path, fail_after):
          super().__init__(path)
```

### c166 — readings/cli.py

```python
> """The command line: import the inbox once, and say by exit status whether a person is needed.
> 
>     python3 -m readings [--inbox DIR] [--db PATH]
> """
  import argparse
  import os
  import sys
```

### c167 — readings/cli.py

```python
> """The command line: python3 -m readings [--inbox DIR] [--db PATH]."""
  import argparse
  import dataclasses
  import os
```

### c168 — readings/cli.py

```python
  
  
  def exit_status(summary):
>     """0 nothing to do; 1 a file failed and will be retried; 3 a person is needed."""
      if summary.poisoned:
          return 3  # a poisoned file in the inbox outranks everything else
      if summary.failed:
```

### c169 — tests/test_cli.py

```python
          self.assertFalse(os.path.exists(self.db))
  
      def test_module_runs_with_defaults(self):
>         # Defaults are relative to the working directory: ./inbox and ./readings.db.
          write(self.inbox, EARLY, HEADER + "2026-01-15T00:00,3.1,1012.4,4.2\n")
          done = subprocess.run([sys.executable, "-m", "readings"], cwd=self.base,
                                env={**os.environ, "PYTHONPATH": ROOT},
```

### c170 — readings/runner.py

```python
> """Import every station export in the inbox into the store, one file at a time."""
  import dataclasses
  import os
  import sys
```

### c171 — tests/test_cli.py

```python
          self.assertEqual(store.count(), 3)
  
      def test_a_store_that_cannot_be_opened_stops_the_run(self):
>         # A directory where the store file should be: sqlite3 cannot open it.
          result = self.python_m("--db", self.base)
          self.assertEqual(result.returncode, 1)
          self.assertEqual(result.stdout, "")
```

### c172 — readings/cli.py

```python
      parser.add_argument("--inbox", default=runner.INBOX_DIR, help="the inbox directory")
      parser.add_argument("--db", default=DEFAULT_DB, help="the reading store's SQLite file")
      args = parser.parse_args(argv)
>     # Checked before the store opens, because opening it creates the file.
      if not os.path.isdir(args.inbox):
          parser.error(f"no inbox at {args.inbox}")
  
```

### c173 — tests/test_runner.py

```python
                                    ("poisoned", 3, 0, 1, [])])
          store = self.reopened()
          self.assertTrue(store.marker(EARLY).detail.startswith("not text: "))
>         self.assertEqual(store.count(), 3)  # LATE's readings, stored once on the first run
  
      def test_a_failed_file_is_retried_and_imports_once_complete(self):
          self.export(EARLY, "time")  # a copy cut short inside the header
```

### c174 — readings/runner.py

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

### c175 — tests/test_runner.py

```python
          self.assertEqual([m[0] for m in markers], [A])
          self.assertIsNone(self.marker(B))
  
>         # the next run picks up where this one stopped
          self.assertEqual(self.run_once(), Summary(files=2, imported=1, skipped=1, stored=6))
          self.assertEqual(len(dump(self.db)[0]), 9)
  
```

### c176 — tests/test_cli.py

```python
          self.db = os.path.join(self.base, "readings.db")
  
      def main(self, *argv):
>         """(status, stdout, stderr) of cli.main over this test's inbox and store."""
          argv = argv or ("--inbox", self.inbox, "--db", self.db)
          out, err = io.StringIO(), io.StringIO()
          with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
```

### c177 — readings/parse.py

```python
      """
      station = station_of(path)
      try:
>         # utf-8-sig: a byte-order mark is not part of the first column's name
          with open(path, encoding="utf-8-sig") as f:
              text = f.read()
      except UnicodeDecodeError as e:
```

### c178 — tests/test_runner.py

```python
          self.assertEqual([name for name, _ in runner.exports(self.inbox)], [EARLY])
  
      def test_done_and_poisoned_files_are_not_opened(self):
>         # Both files would raise FileError if they were read.
          write(self.inbox, EARLY, "garbage\n")
          write(self.inbox, LATE, "garbage\n")
          self.store.set_marker(EARLY, "done", 0, "3 stored, 0 duplicates, 0 rejected")
```

### c179 — tests/test_runner.py

```python
          self.assertIsNone(self.marker("notes.txt"))
  
      def test_store_error_halfway_keeps_nothing_of_that_file(self):
>         write(self.inbox, A, HEADER + row(0))           # adds 1-3, committed
>         write(self.inbox, B, HEADER + row(5) + row(6))  # fails on its second add
          store = FailingStore(self.db, fail_on_add=5)
          try:
              with self.assertRaises(sqlite3.OperationalError):
```

### c180 — readings/runner.py

```python
  
  
  def fail(name, marker, detail, store, summary):
>     store.rollback()  # nothing of a failed file is kept
      failures = (0 if marker is None else marker.failures) + 1
      state = "poisoned" if failures >= POISON_AFTER else "failed"
      store.set_marker(name, state, failures, detail)
```

### c181 — tests/test_runner.py

```python
          self.addCleanup(store.close)
          with self.assertRaises(sqlite3.OperationalError):
              runner.run(self.inbox, store)
>         # rolled back on this connection, not merely left uncommitted
          self.assertEqual(store.count(), 3)
          self.assertIsNone(store.marker(LATE))
          reopened = self.reopened()
```

### c182 — readings/parse.py

```python
              rejected.append(row)
              continue
          values = [v for v in values if v is not None]
>         # float() accepts "nan" and "inf", but neither is a reading
          if not all(math.isfinite(value) for _, value in values):
              rejected.append(row)
              continue
```

### c183 — tests/test_runner.py

```python
  
  
  class FailingStore(Store):
>     """A real Store whose nth add raises, as a full disk would."""
  
      def __init__(self, path, fail_on):
          super().__init__(path)
```

### c184 — readings/cli.py

```python
  
  
  def main(argv=None):
>     """Run one import over the inbox, print its summary line, and return the exit status.
> 
>     Returns 2 for a usage error. An exception from the run propagates.
>     """
      parser = argparse.ArgumentParser(prog="python3 -m readings",
                                       description="Import station exports from the inbox.")
      parser.add_argument("--inbox", default=INBOX_DIR,
```

### c185 — tests/test_runner.py

```python
          with mock.patch.object(self.store, "add", side_effect=add):
              with self.assertRaises(sqlite3.OperationalError):
                  self.run_once()
>         self.assertEqual(self.store.count(), 6)  # rolled back on the run's own connection
          store = self.committed()
          self.assertEqual(store.count(), 6)  # A's, committed before B began
          self.assertIsNone(store.get("ST014|2026-01-15T02:00|temperature"))
```

### c186 — tests/test_runner.py

```python
  
          self.assertEqual(problems, [(C, "failed", 1), (C, "failed", 2), (C, "poisoned", 3)])
          readings, _ = dump(self.db)
>         self.assertEqual(len(readings), 3)  # only A's; nothing of C, ever
  
      def test_unknown_column_fails_the_file_and_stores_nothing_of_it(self):
          write(self.inbox, A, "time,temp_c,humidity\n2026-01-15T00:00,3.1,80\n")
```

### c187 — readings/runner.py

```python
  
  def key(reading):
      """The store key of a reading: its station, time and quantity."""
>     # A reading arrives in two overlapping exports, at a different row in each;
>     # only station, time and quantity match across them.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c188 — tests/test_runner.py

```python
          self.addCleanup(failing.close)
          with self.assertRaises(sqlite3.OperationalError):
              self.run_once(failing)
>         failing.commit()  # would land anything the run left uncommitted
          self.assertEqual(self.store.count(), 0)
          self.assertIsNone(self.store.marker(FIRST))
  
```

### c189 — tests/test_runner.py

```python
  
  
  class FailingStore(Store):
>     """A real store whose add raises once `adds` readings have been added."""
  
      def __init__(self, path, adds):
          super().__init__(path)
```

### c190 — readings/parse.py

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

### c191 — readings/runner.py

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

### c192 — readings/cli.py

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

### c193 — tests/helpers.py

```python
  B_TEXT = HEADER + "2026-01-15T01:00,3.0,1012.1,3.9\n" + "2026-01-15T02:00,2.9,1011.9,3.8\n"
  
  
> # What the station with new firmware sends: a good export, in UTF-16.
  UTF16 = A_TEXT.encode("utf-16")
  
  
```

### c194 — readings/runner.py

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

### c195 — tests/test_runner.py

```python
                  self.run_once()
          self.assertEqual(self.store.count(), 6)  # rolled back on the run's own connection
          store = self.committed()
>         self.assertEqual(store.count(), 6)  # A's, committed before B began
          self.assertIsNone(store.get("ST014|2026-01-15T02:00|temperature"))
          self.assertEqual(store.marker(A).state, "done")
          self.assertIsNone(store.marker(B))
```

### c196 — readings/runner.py

```python
  
  
  def run(inbox, store):
>     """Import each export in inbox that is not done or poisoned; returns a Summary.
> 
>     A file's readings and its marker are committed together, one file at a time.
>     A FileError fails that file and the run goes on; any other exception rolls
>     back the file being imported and propagates.
>     """
      summary = Summary()
      try:
          for name, path in exports(inbox):
```

### c197 — readings/parse.py

```python
      readings, rejected = [], []
      for row, fields in enumerate(body, 1):
          if not fields:
>             continue  # a blank line holds no reading and is not a bad row
          if len(fields) != len(header):
              rejected.append(row)
              continue
```

### c198 — readings/cli.py

```python
  
  
  def exit_status(summary):
>     """3 if a poisoned file is in the inbox, else 1 if a file failed this run, else 0."""
      if summary.poisoned:
          return 3
      if summary.failed:
```

### c199 — readings/runner.py

```python
  
  
  def run(inbox, store, report=lambda line: None):
>     """Import every *.csv file in inbox into store; return a Summary.
> 
>     A file's readings and its marker are committed together. report is called
>     with one line for each file that failed or was poisoned this run. Any
>     exception other than FileError rolls back the file being imported and
>     propagates.
>     """
      summary = Summary()
      try:
          for name in exports(inbox):
```

### c200 — readings/parse.py

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

### c201 — tests/test_runner.py

```python
  
  
  def dump(path):
>     """Both tables, read through a fresh connection: what the commits left behind."""
      db = sqlite3.connect(path)
      try:
          return (db.execute("SELECT key, body FROM readings ORDER BY key").fetchall(),
```

### c202 — tests/test_runner.py

```python
          self.assertEqual(store.marker(B), Marker("done", 0, "3 stored, 6 duplicates, 0 rejected"))
  
      def test_files_are_imported_in_name_order(self):
>         # B is written first, but A comes first by name, so A's copy is the one kept.
          self.export(B, rows("2026-01-15T01:00"))
          self.export(A, rows("2026-01-15T00:00", "2026-01-15T01:00"))
          self.run_once()
```

### c203 — readings/runner.py

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

### c204 — readings/cli.py

```python
  
  DEFAULT_DB = "readings.db"
  
> # the summary line's fields, in the order it prints them
  COUNTS = ("files", "imported", "skipped", "failed", "poisoned", "stored", "duplicates", "rejected")
  
  
```

### c205 — readings/runner.py

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

### c206 — readings/runner.py

```python
  
  
  def inbox_files(inbox):
>     """The names of the *.csv files in the inbox, in name order."""
      return sorted(name for name in os.listdir(inbox)
                    if name.endswith(".csv") and os.path.isfile(os.path.join(inbox, name)))
  
```

### c207 — readings/cli.py

```python
  from . import runner
  from .store import Store
  
> # The summary line's fields, in the order Summary declares them.
  COUNTS = ("files", "imported", "skipped", "failed", "poisoned", "stored", "duplicates", "rejected")
  
  OK = 0              # nothing failed, and no poisoned file is in the inbox
```

### c208 — readings/runner.py

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

### c209 — readings/parse.py

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

### c210 — readings/parse.py

```python
          raise FileError("first column is not time")
      unknown = [column for column in header[1:] if column not in units.COLUMNS]
      if unknown:
>         # A station sending a column nobody has mapped, not a file full of bad rows.
          raise FileError(f"unknown columns: {', '.join(unknown)}")
  
      readings, rejected = [], []
```

### c211 — readings/cli.py

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

### c212 — tests/test_runner.py

```python
  
  EARLY = "ST014_202601150600.csv"
  LATE = "ST014_202601151200.csv"
> # The two exports overlap at 01:00, which is row 2 of EARLY and row 1 of LATE.
  EARLY_TEXT = HEADER + "2026-01-15T00:00,3.1,1012.4,4.2\n2026-01-15T01:00,3.0,1012.1,3.9\n"
  LATE_TEXT = HEADER + "2026-01-15T01:00,3.0,1012.1,3.9\n2026-01-15T02:00,2.9,1011.9,3.8\n"
  GOOD_TEXT = HEADER + "2026-01-15T00:00,3.1,1012.4,4.2\n"
```

### c213 — tests/test_runner.py

```python
          self.assertEqual(self.marker(A), Marker("done", 0, "6 stored, 0 duplicates, 1 rejected"))
  
      def test_only_csv_files_in_name_order(self):
>         # B is written first, but A sorts first, so A's value is the one stored
          write(self.inbox, B, HEADER + "2026-01-15T01:00,9.9,1012.1,4.1\n")
          write(self.inbox, A, HEADER + row(1))
          write(self.inbox, "notes.txt", "not an export\n")
```

### c214 — tests/test_runner.py

```python
                           Marker("done", 0, "3 stored, 0 duplicates, 0 rejected"))
  
      def test_store_error_keeps_nothing_of_the_file_and_propagates(self):
>         self.export(A, rows("2026-01-15T00:00"))                     # adds 1-3
>         self.export(B, rows("2026-01-15T06:00", "2026-01-15T07:00"))  # fails on its second add
          store = FailingStore(self.db, fail_on=5)
          self.addCleanup(store.close)
          with self.assertRaises(sqlite3.OperationalError):
```

### c215 — tests/test_runner.py

```python
          self.assertEqual(runner.key(reading), "ST014|2026-01-15T00:00|temperature")
  
      def test_overlapping_exports_store_each_reading_once(self):
>         # The station dropped an empty row before its second export, so 01:00 is
>         # row 2 in the first file and row 1 in the second.
          self.export(EARLY, HEADER + ROW_00 + ROW_01 + ROW_02)
          self.export(LATE, HEADER + ROW_01 + ROW_02 + ROW_03)
          summary = self.run_once()
```

### c216 — tests/test_runner.py

```python
      def test_store_error_keeps_nothing_of_the_file(self):
          write(self.inbox, MORNING, MORNING_TEXT)
          write(self.inbox, NOON, NOON_TEXT)
>         # MORNING's 9 adds, then NOON's 3 duplicates, 1 stored, and the 14th add fails.
          store = FailingStore(self.db, fail_on=14)
          self.addCleanup(store.close)
  
```

### c217 — tests/test_runner.py

```python
  
  class RunTest(InboxCase):
      def test_overlapping_exports_store_each_reading_once(self):
>         # Written first, so name order and not creation order has to decide.
          write(self.inbox, NOON, NOON_TEXT)
          write(self.inbox, MORNING, MORNING_TEXT)
  
```

### c218 — readings/runner.py

```python
  
  
  def exports(inbox):
>     """The names of the *.csv files in inbox, in name order."""
      return sorted(name for name in os.listdir(inbox)
                    if name.endswith(".csv") and os.path.isfile(os.path.join(inbox, name)))
  
```

### c219 — tests/test_runner.py

```python
          return summary
  
      def reopened(self):
>         """The store as another process would see it: committed work only."""
          store = Store(self.db)
          self.addCleanup(store.close)
          return store
```

### c220 — readings/cli.py

```python
          args = parser.parse_args(argv)
          if not os.path.isdir(args.inbox):
              parser.error(f"no inbox directory at {args.inbox}")
>         # Left to sqlite3, a missing directory fails every run with status 1, which
>         # never asks for a person.
          if not os.path.isdir(os.path.dirname(os.path.abspath(args.db))):
              parser.error(f"no directory for the store at {args.db}")
      except SystemExit as e:
```

