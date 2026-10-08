### c001 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def key(reading):
>     # Station, time and quantity identify a reading in the world. Every reading
>     # arrives in two overlapping exports, at different rows, so this is the only
>     # key that can match them.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c002 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c003 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """python3 -m readings: one run over the inbox, exiting with its status."""
  import sys
  
  from .cli import main
```

### c004 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def exit_status(summary):
>     # Phase 3's timer acts on this alone, so a poisoned file wins over everything else.
      if summary.poisoned:
          return NEEDS_A_PERSON
      if summary.failed:
```

### c005 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  class FailingStore(Store):
>     """A real Store whose n-th add fails the way a full disk does."""
  
      def __init__(self, path, fail_on_add):
          super().__init__(path)
```

### c006 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def rows(*times):
>     """An export: one row per time, the same three values in each."""
      return HEADER + "".join(f"{time},3.1,1012.4,4.2\n" for time in times)
  
  
```

### c007 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          if store.add(key(reading), asdict(reading)):
              stored += 1
          else:
>             # first stored wins, even when the values differ
              duplicates += 1
      store.set_marker(name, "done", 0, f"{stored} stored, {duplicates} duplicates, {len(rejected)} rejected")
      store.commit()
```

### c008 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  class ModuleTest(unittest.TestCase):
>     """python3 -m readings, as Phase 3's timer will run it."""
  
      def setUp(self):
          self.base = temp_dir(self)
```

### c009 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> # (name, marker) for each file that failed or was poisoned this run; for stderr, not the summary line
  problems: list = field(default_factory=list)
```

### c010 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def exit_status(summary):
>     """0 nothing to do; 1 a file failed and will be retried; 3 a person is needed."""
      if summary.poisoned:
          return 3  # a poisoned file in the inbox outranks everything else
      if summary.failed:
```

### c011 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      self.addCleanup(store.close)
      with self.assertRaises(sqlite3.OperationalError):
          runner.run(self.inbox, store)
>     # Without the rollback, this commit would land B's first reading.
      store.commit()
      after = self.reopened()
      self.assertEqual(after.count(), 3)
```

### c012 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def run(inbox, store, errors=None):
>     """Import every export in inbox into store, one file per transaction."""
      errors = sys.stderr if errors is None else errors
      summary = Summary()
      for name in exports(inbox):
```

### c013 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  def exit_status(summary):
      """0 nothing to do; 1 a file failed and will be retried; 3 a person is needed."""
      if summary.poisoned:
>         return 3  # a poisoned file in the inbox outranks everything else
      if summary.failed:
          return 1
      return 0
```

### c014 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      def test_a_store_error_keeps_nothing_of_that_file_and_propagates(self):
          self.export(EARLY, HEADER + ROW_00)
          self.export(LATE, HEADER + ROW_01)
>         store = FailingStore(self.db, fail_after=4)  # EARLY's 3 adds, then one of LATE's
          self.addCleanup(store.close)
          with self.assertRaises(sqlite3.OperationalError):
              runner.run(self.inbox, store)
```

### c015 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def exit_status(summary):
>     """0 nothing needs a person; 1 a failure the next run retries; 3 a person is needed."""
      if summary.poisoned:
          return 3
      if summary.failed:
```

### c016 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def key(reading):
>     """The store key of a reading: its station, time and quantity."""
      # A reading arrives in two overlapping exports, at a different row in each;
      # only station, time and quantity match across them.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
```

### c017 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def _import_file(inbox, name, previous, store, summary):
>     """Import one file and commit it with its marker; the marker when the file failed, else None."""
      try:
          readings, rejected = parse_file(os.path.join(inbox, name))
      except FileError as error:
```

### c018 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  def row(hour, temp):
>     """One line of an export under HEADER, for 2026-01-15 at the given hour."""
      return f"2026-01-15T{hour:02d}:00,{temp},1012.4,4.2\n"
```

### c019 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def summary_line(summary):
>     """'files=4 imported=2 ...': every Summary field, in declaration order."""
      return " ".join(f"{field.name}={getattr(summary, field.name)}"
                      for field in dataclasses.fields(summary))
  
```

### c020 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """python3 -m readings: import the inbox once, and say by exit status whether a person is needed."""
  import argparse
  import dataclasses
  import os
```

### c021 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def _import(path, name, previous, store, summary):
>     """Stage one file's readings and its new marker in store, uncommitted; return the marker."""
      try:
          readings, rejected = parse_file(path)
      except FileError as e:
```

### c022 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  class FailingStore(Store):
>     """A real store whose add raises on its nth call, as a full disk would."""
  
      def __init__(self, path, fail_on):
          super().__init__(path)
```

### c023 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      self.addCleanup(failing.close)
      with self.assertRaises(sqlite3.OperationalError):
          self.run_once(failing)
>     failing.commit()  # would land anything the run left uncommitted
      self.assertEqual(self.store.count(), 0)
      self.assertIsNone(self.store.marker(FIRST))
  
```

### c024 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertIsNone(self.marker("notes.txt"))
  
      def test_store_error_halfway_keeps_nothing_of_that_file(self):
>         write(self.inbox, A, HEADER + row(0))           # adds 1-3, committed
>         write(self.inbox, B, HEADER + row(5) + row(6))  # fails on its second add
          store = FailingStore(self.db, fail_on_add=5)
          try:
              with self.assertRaises(sqlite3.OperationalError):
```

### c025 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c026 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def key(reading):
>     # Station, time and quantity identify a reading in the world; a row number
>     # only identifies it in one file, and overlapping exports differ in rows.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c027 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def run(inbox, store):
>     """Import every *.csv file in inbox, in name order, into store.
> 
>     Each file's readings and its marker are committed together. Any exception is
>     rolled back, keeping nothing of the file being read, and propagates.
>     """
      summary = Summary()
      for name in _exports(inbox):
          summary.files += 1
```

### c028 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(summary, Summary(files=2, imported=2, stored=9, duplicates=3))
          store = self.open_store()
          self.assertEqual(store.count(), 9)
>         # Name order imports EARLY first, so the overlapping reading keeps EARLY's row.
          self.assertEqual(store.get("ST014|2026-01-15T01:00|temperature"),
                           {"station": "ST014", "row": 2, "time": "2026-01-15T01:00",
                            "quantity": "temperature", "value": 3.0})
```

### c029 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          real_add = self.store.add
  
          def add(key, reading):
>             # B's 02:00 temperature has been added, uncommitted, when this fails.
              if key == "ST014|2026-01-15T02:00|pressure":
                  raise sqlite3.OperationalError("disk I/O error")
              return real_add(key, reading)
```

### c030 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """Import every export in the inbox into the store, one file at a time."""
  import os
  from dataclasses import asdict, dataclass
  
```

### c031 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def run(inbox, store):
>     """Import each export in inbox that is not done or poisoned; returns a Summary.
> 
>     A file's readings and its marker are committed together, one file at a time.
>     """
      summary = Summary()
      for name, path in exports(inbox):
          summary.files += 1
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
>     """Names of the *.csv files in inbox, in name order."""
      return sorted(name for name in os.listdir(inbox)
                    if name.endswith(".csv") and os.path.isfile(os.path.join(inbox, name)))
  
```

### c034 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          raise FileError(f"unknown column: {', '.join(unknown)}")
  
      readings, rejected = [], []
>     # row numbers are stable because a station never rewrites a file it has exported
      for row, fields in enumerate(body, 1):
          if len(fields) != len(header):
              rejected.append(row)
```

### c035 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.addCleanup(self.store.close)
  
      def run_once(self, store=None):
>         """(Summary, stderr) of one run."""
          err = io.StringIO()
          with contextlib.redirect_stderr(err):
              summary = runner.run(self.inbox, store or self.store)
```

### c036 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          if store.add(key(reading), asdict(reading)):
              stored += 1
          else:
>             duplicates += 1  # first stored wins
      store.set_marker(name, DONE, 0,
                       f"{stored} stored, {duplicates} duplicates, {len(rejected)} rejected")
      store.commit()
```

### c037 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> # row numbers are stable because a station never rewrites a file it has exported
```

### c038 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """Import every export in the inbox into the store, one file at a time."""
  import os
  from dataclasses import asdict, dataclass
  
```

### c039 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(store.marker(EARLY), Marker("done", 0, "6 stored, 0 duplicates, 1 rejected"))
  
      def test_files_are_imported_in_name_order(self):
>         # The later export carries a different value for 01:00; first stored wins,
>         # and the first is the earlier name, whatever order the files were written in.
          self.export(LATE, HEADER + "2026-01-15T01:00,9.9,1012.1,3.9\n")
          self.export(EARLY, HEADER + ROW_01)
          self.run_once()
```

### c040 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c041 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c042 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(store.marker(other).state, "done")
  
      def test_partial_copy_imports_once_complete(self):
>         self.export(A, A_TEXT[:20])  # cut mid-header: "time,temp_c,pressure"
          self.assertEqual(self.run_once(), Summary(files=1, failed=1))
          self.assertEqual(self.committed().marker(A).failures, 1)
          self.export(A, A_TEXT)  # the copy has finished
```

### c043 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      first = self.run_once()
      self.assertEqual((first.failed, self.store.count()), (1, 0))
      self.assertEqual(self.store.marker(EARLY), Marker("failed", 1, "header has no delimiter"))
>     self.export(EARLY, HEADER + ROW_00)  # the complete copy arrives under the same name
      second = self.run_once()
      self.assertEqual((second.imported, second.failed, second.stored, second.problems), (1, 0, 3, []))
      store = self.reopened()
```

### c044 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.export(A, A_TEXT[:20])  # cut mid-header: "time,temp_c,pressure"
          self.assertEqual(self.run_once(), Summary(files=1, failed=1))
          self.assertEqual(self.committed().marker(A).failures, 1)
>         self.export(A, A_TEXT)  # the copy has finished
          summary = self.run_once()
          self.assertEqual(summary, Summary(files=1, imported=1, stored=6))
          self.assertEqual(summary.problems, [])
```

### c045 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  class FailingStore(Store):
>     """A real Store whose nth add raises, as a full disk would."""
  
      def __init__(self, path, fail_on):
          super().__init__(path)
```

### c046 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c047 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c048 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  class FailingStore(Store):
>     """A real store whose add raises once `adds` readings have been added."""
  
      def __init__(self, path, adds):
          super().__init__(path)
```

### c049 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      def test_a_file_that_failed_once_imports_on_the_next_run(self):
          self.export(A, "")  # the first instant of a copy
          self.assertEqual(self.run_once().failed, 1)
>         self.export(A, HEADER + ROW[0])  # the copy has finished
          summary = self.run_once()
          self.assertEqual(summary, runner.Summary(files=1, imported=1, stored=3))
          store = self.reopened()
```

### c050 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  class FailingStore(Store):
>     """A real Store whose nth add raises, as a full disk would."""
  
      def __init__(self, path, fail_on):
          super().__init__(path)
```

### c051 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  def key(reading):
      """The store key of a reading: its station, time and quantity."""
>     # A reading arrives in two overlapping exports, at a different row in each;
>     # only station, time and quantity match across them.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c052 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c053 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """Import every station export in the inbox into the store, one file at a time."""
  import dataclasses
  import os
  from dataclasses import dataclass
```

### c054 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  class FailingStore(Store):
>     """A real Store whose writes start failing partway, as a full disk would."""
  
      def __init__(self, path, fail_after):
          super().__init__(path)
```

### c055 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(store.marker(A), Marker("done", 0, "3 stored, 0 duplicates, 0 rejected"))
  
      def test_a_poisoned_file_is_not_opened(self):
>         self.export(A, HEADER + ROW[0])  # would import, if it were opened
          self.store.set_marker(A, "poisoned", 3, "not text")
          self.store.commit()
          summary = self.run_once()
```

### c056 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c057 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  class RunTest(InboxCase):
      def test_overlapping_exports_store_each_reading_once(self):
>         # Written first, so name order and not creation order has to decide.
          write(self.inbox, NOON, NOON_TEXT)
          write(self.inbox, MORNING, MORNING_TEXT)
  
```

### c058 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c059 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
              duplicates += 1
      store.set_marker(name, "done", 0, f"{stored} stored, {duplicates} duplicates, {len(rejected)} rejected")
      store.commit()
>     # counted only once committed, so the summary never claims what the store lacks
      summary.imported += 1
      summary.stored += stored
      summary.duplicates += duplicates
```

### c060 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      """
      station = station_of(path)
      try:
>         # utf-8-sig: a byte-order mark is UTF-8 too, and must not end up in the first column's name
          with open(path, encoding="utf-8-sig") as f:
              text = f.read()
      except UnicodeDecodeError as e:
```

### c061 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def _fail(name, previous, error, store, summary):
>     store.rollback()  # nothing of this file is kept
      failures = (previous.failures if previous is not None else 0) + 1
      marker = Marker(POISONED if failures >= POISON_AFTER else FAILED, failures, str(error))
      store.set_marker(name, marker.state, marker.failures, marker.detail)
```

### c062 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      parser.add_argument("--inbox", default=INBOX_DIR, help=f"the inbox directory (default: {INBOX_DIR})")
      parser.add_argument("--db", default=DEFAULT_DB, help=f"the store's SQLite file (default: {DEFAULT_DB})")
      args = parser.parse_args(argv)
>     # before the store is opened, so a mistyped inbox leaves no empty database behind
      if not os.path.isdir(args.inbox):
          parser.error(f"no inbox at {args.inbox}")
  
```

### c063 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c064 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(self.marker(A), Marker("done", 0, "6 stored, 0 duplicates, 1 rejected"))
  
      def test_only_csv_files_in_name_order(self):
>         # B is written first, but A sorts first, so A's value is the one stored
          write(self.inbox, B, HEADER + "2026-01-15T01:00,9.9,1012.1,4.1\n")
          write(self.inbox, A, HEADER + row(1))
          write(self.inbox, "notes.txt", "not an export\n")
```

### c065 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c066 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """Import every station export in the inbox into the store, with nobody watching.
> 
> A file's readings and its marker are committed together, so a run that stops
> part-way leaves the store consistent with the inbox as far as it got.
> """
  import os
  from dataclasses import asdict, dataclass
  
```

### c067 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c068 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
      def test_overlapping_exports_store_each_reading_once(self):
          write(self.inbox, A, HEADER + row(0) + row(1) + row(2))
>         # the next export: 01:00 is row 1 here and row 2 in A
          write(self.inbox, B, HEADER + row(1) + row(2) + row(3))
  
          self.assertEqual(self.run_once(), Summary(files=2, imported=2, stored=12, duplicates=6))
```

### c069 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c070 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def run(inbox, store):
>     """Import every export in inbox that is not done or poisoned into store."""
      summary = Summary()
      for name in exports(inbox):
          summary.files += 1
```

### c071 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """Import every export in the inbox into the store, one file at a time."""
  import os
  from dataclasses import asdict, dataclass
  
```

### c072 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def summary_line(summary):
>     """'files=4 imported=2 ...', every Summary field in declaration order."""
      return " ".join(f"{field.name}={getattr(summary, field.name)}"
                      for field in dataclasses.fields(summary))
  
```

### c073 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(runner.key(reading), "ST014|2026-01-15T00:00|temperature")
  
      def test_overlapping_exports_store_each_reading_once(self):
>         # The station dropped an empty row before its second export, so 01:00 is
>         # row 2 in the first file and row 1 in the second.
          self.export(EARLY, HEADER + ROW_00 + ROW_01 + ROW_02)
          self.export(LATE, HEADER + ROW_01 + ROW_02 + ROW_03)
          summary = self.run_once()
```

### c074 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  MORNING = "ST014_202601150600.csv"
  NOON = "ST014_202601151200.csv"
  
> # The 06:00 reading is row 3 of MORNING and row 1 of NOON, as when a station drops
> # empty rows before exporting.
  MORNING_TEXT = HEADER + ("2026-01-15T00:00,3.1,1012.4,4.2\n"
                           "2026-01-15T03:00,2.8,1012.0,3.9\n"
                           "2026-01-15T06:00,2.5,1011.6,3.5\n")
```

### c075 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c076 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c077 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def key(reading):
>     # Each reading arrives in two exports, at different row numbers; station,
>     # time and quantity are what the two copies share.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c078 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c079 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c080 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c081 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.addCleanup(store.close)
          with self.assertRaises(sqlite3.OperationalError):
              runner.run(self.inbox, store)
>         # rolled back on this connection, not merely left uncommitted
          self.assertEqual(store.count(), 3)
          self.assertIsNone(store.marker(LATE))
          reopened = self.reopened()
```

### c082 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  class FailingStore(Store):
>     """A real Store whose add raises once it has been called fail_after times."""
  
      def __init__(self, path, fail_after):
          super().__init__(path)
```

### c083 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  @dataclass
  class Summary:
>     """What one run did. files == imported + skipped + failed + poisoned."""
  
      files: int = 0       # *.csv files in the inbox
      imported: int = 0    # read this run and marked done
```

### c084 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(store.marker(B), Marker("done", 0, "3 stored, 6 duplicates, 0 rejected"))
  
      def test_files_are_imported_in_name_order(self):
>         # B is written first, but A comes first by name, so A's copy is the one kept.
          self.export(B, rows("2026-01-15T01:00"))
          self.export(A, rows("2026-01-15T00:00", "2026-01-15T01:00"))
          self.run_once()
```

### c085 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
                          help="the store's SQLite file (default: readings.db)")
      args = parser.parse_args(argv)
      if not os.path.isdir(args.inbox):
>         parser.error(f"inbox is not a directory: {args.inbox}")  # exits 2
  
      store = Store(args.db)
      try:
```

### c086 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c087 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c088 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def key(reading):
>     # Station, time and quantity identify a reading in the world, so two exports
>     # whose windows overlap map the same reading to the same key.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c089 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """Import every station export in the inbox into the store, one file at a time."""
  import os
  from dataclasses import asdict, dataclass
  
```

### c090 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
              store.close()
  
      def utf16(self, name):
>         """An export from the station whose firmware switched it to UTF-16 (§3)."""
          with open(os.path.join(self.inbox, name), "w", encoding="utf-16") as f:
              f.write(rows("2026-01-15T06:00"))
  
```

### c091 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def summary_line(summary):
>     """'files=4 imported=2 ...', every Summary field in declaration order."""
      return " ".join(f"{field.name}={getattr(summary, field.name)}" for field in fields(summary))
  
  
```

### c092 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  from .store import Marker
  
  INBOX_DIR = "inbox"
> POISON_AFTER = 3  # failed runs; eighteen hours at Phase 3's six-hour interval
  
  
  def key(reading):
```

### c093 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
      def test_store_that_cannot_open_stops_the_run_with_1(self):
          write(self.inbox, GOOD, HEADER + ROW_0000)
>         result = self.module(temp_dir(self))  # a directory: sqlite cannot open it
          self.assertEqual((result.returncode, result.stdout), (1, ""))
          self.assertIn("OperationalError", result.stderr)
```

### c094 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(self.store.marker(EARLY), Marker("done", 0, "3 stored, 0 duplicates, 1 rejected"))
  
      def test_files_are_imported_in_name_order(self):
>         # Written late first, so directory order and name order are likely to differ.
          self.export(LATE, "2026-01-15T06:00,9.9,1012.0,4.0")
          self.export(EARLY, "2026-01-15T06:00,3.4,1012.0,4.0")
          runner.run(self.inbox, self.store)
```

### c095 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def inbox_files(inbox):
>     """The names of the *.csv files in the inbox, in name order."""
      return sorted(name for name in os.listdir(inbox)
                    if name.endswith(".csv") and os.path.isfile(os.path.join(inbox, name)))
  
```

### c096 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c097 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c098 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def inbox_files(inbox):
>     """The names of the *.csv files in the inbox, in name order."""
      return sorted(name for name in os.listdir(inbox)
                    if name.endswith(".csv") and os.path.isfile(os.path.join(inbox, name)))
  
```

### c099 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      stored: int = 0
      duplicates: int = 0
      rejected: int = 0
>     # (name, marker) for each file that failed or was poisoned this run, for the
>     # command line's stderr lines. Not a count, so not compared.
      problems: list = field(default_factory=list, compare=False)
  
  
```

### c100 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      self.assertEqual(self.marker(A), Marker("failed", 1, "unknown columns: humidity"))
  
  def test_partial_copy_that_fails_imports_on_the_next_run(self):
>     # copied up to the middle of the header, then completed before the next run
      write(self.inbox, A, "time,temp_c,pres")
      self.assertEqual(self.run_once(), Summary(files=1, failed=1))
      self.assertEqual(self.marker(A), Marker("failed", 1, "unknown columns: pres"))
```

### c101 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  OTHER = "ST031_202601150600.csv"
  
  EARLY_TEXT = HEADER + "2026-01-15T00:00,3.1,1012.4,4.2\n"
> # One reading row repeats EARLY's, one is a clock reset, one is new.
  LATER_TEXT = HEADER + ("2026-01-15T00:00,3.1,1012.4,4.2\n"
                         "--:--,3.0,1012.1,4.0\n"
                         "2026-01-15T06:00,2.5,1011.6,3.5\n")
```

### c102 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
              self.assertIsNone(store.marker(name))
  
      def test_files_are_imported_in_name_order(self):
>         # Written newest first; the older export must still be read first and win.
          self.export(B, HEADER + "2026-01-15T01:00,9.9,1012.1,4.1\n")
          self.export(A, HEADER + "2026-01-15T01:00,3.1,1012.1,4.1\n")
          self.run_once()
```

### c103 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  EARLY = "ST014_202601150600.csv"
  LATE = "ST014_202601151200.csv"
> # The two exports overlap at 01:00, which is row 2 of EARLY and row 1 of LATE.
  EARLY_TEXT = HEADER + "2026-01-15T00:00,3.1,1012.4,4.2\n2026-01-15T01:00,3.0,1012.1,3.9\n"
  LATE_TEXT = HEADER + "2026-01-15T01:00,3.0,1012.1,3.9\n2026-01-15T02:00,2.9,1011.9,3.8\n"
  GOOD_TEXT = HEADER + "2026-01-15T00:00,3.1,1012.4,4.2\n"
```

### c104 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      self.assertEqual(self.run_once(on_problem=report), Summary(files=2, skipped=1, poisoned=1))
      self.assertEqual((self.marker(C).state, self.marker(C).failures), ("poisoned", 3))
  
>     # poisoned: skipped without being opened, failures stop at POISON_AFTER, not reported again
      self.assertEqual(self.run_once(on_problem=report), Summary(files=2, skipped=1, poisoned=1))
      self.assertEqual((self.marker(C).state, self.marker(C).failures), ("poisoned", 3))
  
```

### c105 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          if store.add(key(reading), asdict(reading)):
              stored += 1
          else:
>             # first stored wins, even when the values differ
              duplicates += 1
      store.set_marker(name, "done", 0, f"{stored} stored, {duplicates} duplicates, {len(rejected)} rejected")
      store.commit()
```

### c106 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          parse.parse_file(path)
  
  def test_header_cut_short_is_an_unknown_column(self):
>     # a partial copy that stops inside the header line
      path = write(self.dir, "ST014_202601150600.csv", "time,temp_c,pre")
      with self.assertRaisesRegex(parse.FileError, "unknown columns: pre"):
          parse.parse_file(path)
```

### c107 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(store.marker(A), Marker("failed", 1, "unknown column: humidity"))
  
      def test_a_file_that_failed_once_imports_on_the_next_run(self):
>         self.export(A, "")  # the first instant of a copy
          self.assertEqual(self.run_once().failed, 1)
          self.export(A, HEADER + ROW[0])  # the copy has finished
          summary = self.run_once()
```

### c108 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """The command line: one import of the inbox, whose exit status says whether a person is needed."""
  import argparse
  import os
  import sys
```

### c109 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  class RunnerCase(unittest.TestCase):
>     """A real Store on a temporary file, and an empty inbox beside it."""
  
      def setUp(self):
          base = temp_dir(self)
```

### c110 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c111 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(store.marker(B), Marker("done", 0, "3 stored, 3 duplicates, 0 rejected"))
  
      def test_first_export_in_name_order_wins(self):
>         # B is written first, carrying a different 01:00 temperature; A sorts first.
          self.export(B, HEADER + "2026-01-15T01:00,3.5,1012.1,3.9\n")
          self.export(A, A_TEXT)
          summary = self.run_once()
```

### c112 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def exports(inbox):
>     """The names of the inbox's *.csv files, in name order."""
      return sorted(name for name in os.listdir(inbox)
                    if name.endswith(".csv") and os.path.isfile(os.path.join(inbox, name)))
  
```

### c113 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      readings, rejected = [], []
      for row, fields in enumerate(body, 1):
          if not fields:
>             continue  # a blank line holds no reading and is not a bad row
          if len(fields) != len(header):
              rejected.append(row)
              continue
```

### c114 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def summary_line(summary):
>     """The summary's fields as name=value, space-separated, in declaration order."""
      return " ".join(f"{field.name}={getattr(summary, field.name)}" for field in fields(summary))
  
  
```

### c115 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def fail(name, marker, detail, store, summary):
>     store.rollback()  # nothing of a failed file is kept
      failures = (0 if marker is None else marker.failures) + 1
      state = "poisoned" if failures >= POISON_AFTER else "failed"
      store.set_marker(name, state, failures, detail)
```

### c116 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          for number, (summary, marker) in enumerate(expected, 1):
              with self.subTest(run=number):
                  if number == 4:
>                     # Parseable now: the fourth run passes only if it never opens the file.
                      write(self.inbox, BROKEN, MORNING_TEXT)
                  got, problems = self.run_once()
                  self.assertEqual(got, summary)
```

### c117 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c118 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> # Two consecutive exports of one station. B's window overlaps A's by an hour:
> # the 01:00 reading is A's second row and B's first, as when a station drops an
> # empty row before exporting. Three readings per row.
  A = "ST014_202601150600.csv"
  B = "ST014_202601151200.csv"
  A_TEXT = HEADER + "2026-01-15T00:00,3.1,1012.4,4.2\n" + "2026-01-15T01:00,3.0,1012.1,3.9\n"
```

### c119 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      """
      station = station_of(path)
      try:
>         # utf-8-sig: a byte-order mark is not part of the first column's name
          with open(path, encoding="utf-8-sig") as f:
              text = f.read()
      except UnicodeDecodeError as e:
```

### c120 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          for _ in range(runner.POISON_AFTER):
              self.run_once()
          self.assertEqual(self.committed().marker(A).state, "poisoned")
>         # §10: a person clears a poisoned file by deleting its marker row by hand.
          db = sqlite3.connect(self.db)
          db.execute("DELETE FROM markers WHERE name = ?", (A,))
          db.commit()
```

### c121 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  @dataclass
  class Summary:
>     """What one run did. files == imported + skipped + failed + poisoned."""
  
      files: int = 0       # *.csv files in the inbox
      imported: int = 0    # read this run and marked done
```

### c122 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """The command line: python3 -m readings [--inbox DIR] [--db PATH]."""
  import argparse
  import dataclasses
  import os
```

### c123 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def key(reading):
>     """The store key of a reading: its station, time and quantity."""
      # A reading arrives in two overlapping exports, at a different row in each;
      # only station, time and quantity match across them.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
```

### c124 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          raise FileError(f"unknown column: {', '.join(unknown)}")
  
      readings, rejected = [], []
>     # row numbers are stable because a station never rewrites a file it has exported
      for row, fields in enumerate(body, 1):
          if len(fields) != len(header):
              rejected.append(row)
```

### c125 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      def test_store_error_keeps_nothing_of_the_file(self):
          write(self.inbox, MORNING, MORNING_TEXT)
          write(self.inbox, NOON, NOON_TEXT)
>         # MORNING's 9 adds, then NOON's 3 duplicates, 1 stored, and the 14th add fails.
          store = FailingStore(self.db, fail_on=14)
          self.addCleanup(store.close)
  
```

### c126 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          if store.add(key(reading), asdict(reading)):
              stored += 1
          else:
>             duplicates += 1  # first stored wins
      store.set_marker(name, DONE, 0,
                       f"{stored} stored, {duplicates} duplicates, {len(rejected)} rejected")
      store.commit()
```

### c127 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertTrue(os.path.exists(os.path.join(self.base, "readings.db")))
  
      def test_a_run_that_stops_exits_1(self):
>         result = self.module("--db", "inbox")  # a directory is no database
          self.assertEqual(result.returncode, 1)
          self.assertEqual(result.stdout, "")
          self.assertIn("OperationalError", result.stderr)
```

### c128 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  from .parse import FileError, parse_file
  
  INBOX_DIR = "inbox"
> POISON_AFTER = 3  # failed runs before a file is skipped for good
  
  
  @dataclass
```

### c129 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      def test_only_csv_files_are_work(self):
          self.export(A, A_TEXT)
          write(self.inbox, "README.txt", "not an export\n")
>         write(self.inbox, ".ST014_202601151200.csv", B_TEXT)  # a copy in flight, hidden
          os.mkdir(os.path.join(self.inbox, "old.csv"))
          summary = self.run_once()
          self.assertEqual(summary, Summary(files=1, imported=1, stored=6))
```

### c130 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def exit_status(summary):
>     """3 when a poisoned file is in the inbox, else 1 when a file failed this run, else 0."""
      if summary.poisoned:
          return 3
      if summary.failed:
```

### c131 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          write(self.inbox, MORNING, MORNING_TEXT)
          write(self.inbox, NOON, NOON_TEXT)
          runner.run(self.inbox, self.store)
>         # Unparseable now: the second run passes only if it never opens the file.
          write(self.inbox, MORNING, "garbage\n")
          reopened = Store(self.db)
          self.addCleanup(reopened.close)
```

### c132 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c133 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  try:
      stored, duplicates, rejected = import_file(os.path.join(inbox, name), name, store)
  except FileError as e:
>     store.rollback()  # nothing of this file is kept
      failures = (0 if marker is None else marker.failures) + 1
      state = "poisoned" if failures >= POISON_AFTER else "failed"
      store.set_marker(name, state, failures, str(e))
```

### c134 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """Import every export in the inbox into the store, one file at a time.
> 
> Runs unattended. Every file it reads ends the run with a marker saying what
> became of it, and the Summary says whether a person is needed.
> """
  import os
  from dataclasses import asdict, dataclass
  
```

### c135 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> # (name, Marker) for each file that failed or became poisoned this run
  problems: list = field(default_factory=list)
```

### c136 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c137 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      self.addCleanup(failing.close)
      with self.assertRaises(sqlite3.OperationalError):
          self.quiet_run(failing)
>     # Whatever run left uncommitted would land here.
      failing.commit()
      reopened = Store(self.db)
      self.addCleanup(reopened.close)
```

### c138 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  from .store import Store
  
  OK = 0
> RETRYING = 1   # a file failed and will be retried; also the interpreter's status for an uncaught error
> POISONED = 3   # a poisoned file is in the inbox: a person must clear its marker
  
  
  def summary_line(summary):
```

### c139 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> # What the station with new firmware sends: a good export, in UTF-16.
  UTF16 = A_TEXT.encode("utf-16")
  
  
```

### c140 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c141 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c142 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c143 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c144 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
                       Marker("done", 0, "3 stored, 0 duplicates, 0 rejected"))
  
  def test_store_error_keeps_nothing_of_the_file_and_propagates(self):
>     self.export(A, rows("2026-01-15T00:00"))                     # adds 1-3
>     self.export(B, rows("2026-01-15T06:00", "2026-01-15T07:00"))  # fails on its second add
      store = FailingStore(self.db, fail_on=5)
      self.addCleanup(store.close)
      with self.assertRaises(sqlite3.OperationalError):
```

### c145 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def key(reading):
>     """The store key of a reading: the same in every export that carries it."""
      # Not the row: the two exports that carry a reading carry it at different rows.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
```

### c146 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c147 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          return runner.run(self.inbox, self.store)
  
      def committed(self):
>         """The store as a second connection sees it: only what was committed."""
          store = Store(self.db)
          self.addCleanup(store.close)
          return store
```

### c148 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  class BreaksOnAdd(Store):
>     """A real Store whose nth add fails, as a full disk would."""
  
      def __init__(self, path, fail_on):
          super().__init__(path)
```

### c149 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def exports(inbox):
>     """Names of the inbox's *.csv files, in name order."""
      return sorted(entry.name for entry in os.scandir(inbox)
                    if entry.name.endswith(".csv") and entry.is_file())
  
```

### c150 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c151 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c152 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      self.assertEqual(store.count(), 3)  # LATE's readings, stored once on the first run
  
  def test_a_failed_file_is_retried_and_imports_once_complete(self):
>     self.export(EARLY, "time")  # a copy cut short inside the header
      first = self.run_once()
      self.assertEqual((first.failed, self.store.count()), (1, 0))
      self.assertEqual(self.store.marker(EARLY), Marker("failed", 1, "header has no delimiter"))
```

### c153 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def exports(inbox):
>     """(name, path) for each *.csv file in inbox, in name order."""
      found = []
      for name in sorted(os.listdir(inbox)):
          path = os.path.join(inbox, name)
```

### c154 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> # Numbered for a person looking for the row in the file; no key uses it.
```

### c155 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          with mock.patch.object(self.store, "add", side_effect=add):
              with self.assertRaises(sqlite3.OperationalError):
                  self.run_once()
>         self.assertEqual(self.store.count(), 6)  # rolled back on the run's own connection
          store = self.committed()
          self.assertEqual(store.count(), 6)  # A's, committed before B began
          self.assertIsNone(store.get("ST014|2026-01-15T02:00|temperature"))
```

### c156 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c157 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          return write(self.inbox, name, HEADER + "".join(row + "\n" for row in rows))
  
      def test_overlapping_exports_store_each_reading_once(self):
>         # 06:00 is row 2 in the early export and row 1 in the late one.
          self.export(EARLY, "2026-01-15T00:00,3.1,1012.4,4.2", "2026-01-15T06:00,3.4,1012.0,4.0")
          self.export(LATE, "2026-01-15T06:00,3.4,1012.0,4.0", "2026-01-15T12:00,5.0,1011.2,3.1")
          summary = runner.run(self.inbox, self.store)
```

### c158 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c159 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
              db.close()
  
      def test_overlapping_exports_store_each_reading_once(self):
>         # 01:00 is row 2 of A and row 1 of B: a row key would store it twice.
          self.export(A, rows("2026-01-15T00:00", "2026-01-15T01:00", "2026-01-15T02:00"))
          self.export(B, rows("2026-01-15T01:00", "2026-01-15T02:00", "2026-01-15T03:00"))
          self.assertEqual(self.run_once(), Summary(files=2, imported=2, stored=12, duplicates=6))
```

### c160 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def rows(*times):
>     """An export: one row per time, the same three values in each."""
      return HEADER + "".join(f"{time},3.1,1012.4,4.2\n" for time in times)
  
  
```

### c161 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c162 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  from . import runner
  from .store import Store
  
> # The summary line's fields, in the order Summary declares them.
  COUNTS = ("files", "imported", "skipped", "failed", "poisoned", "stored", "duplicates", "rejected")
  
  OK = 0              # nothing failed, and no poisoned file is in the inbox
```

### c163 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  class ModuleTest(unittest.TestCase):
>     """python3 -m readings, through a real interpreter: the exit status the timer sees."""
  
      def setUp(self):
          self.base = temp_dir(self)
```

### c164 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c165 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      parser.add_argument("--inbox", default=runner.INBOX_DIR, help="the inbox directory")
      parser.add_argument("--db", default=DEFAULT_DB, help="the reading store's SQLite file")
      args = parser.parse_args(argv)
>     # Checked before the store opens, because opening it creates the file.
      if not os.path.isdir(args.inbox):
          parser.error(f"no inbox at {args.inbox}")
  
```

### c166 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  def utf16_export(self, name):
>     # the firmware-updated station: every run will fail it
      with open(os.path.join(self.inbox, name), "wb") as f:
          f.write((HEADER + ROW_00).encode("utf-16"))
  
```

### c167 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual([m[0] for m in markers], [A])
          self.assertIsNone(self.marker(B))
  
>         # the next run picks up where this one stopped
          self.assertEqual(self.run_once(), Summary(files=2, imported=1, skipped=1, stored=6))
          self.assertEqual(len(dump(self.db)[0]), 9)
```

### c168 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c169 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """python3 -m readings: one import run over the inbox."""
  import sys
  
  from .cli import main
```

### c170 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.db = os.path.join(temp_dir(self), "readings.db")
  
      def main(self, argv=None):
>         """(status, stdout, stderr) of one cli.main call."""
          out, err = io.StringIO(), io.StringIO()
          with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
              status = cli.main(["--inbox", self.inbox, "--db", self.db] if argv is None else argv)
```

### c171 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  def key(reading):
      """The store key of a reading: its station, time and quantity."""
>     # A reading arrives in two overlapping exports, at a different row in each;
>     # only station, time and quantity match across them.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c172 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def exports(inbox):
>     """The names of the *.csv files in inbox, in name order.
> 
>     Hidden names are not matched, so a copy still in flight under one is left alone.
>     """
      return sorted(name for name in glob.glob("*.csv", root_dir=inbox)
                    if os.path.isfile(os.path.join(inbox, name)))
  
```

### c173 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """The command line: import the inbox once, and exit with a status a timer can act on."""
  import argparse
  import os
  from dataclasses import fields
```

### c174 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      def test_store_error_propagates(self):
          write(self.inbox, A, HEADER + row(0))
          with self.assertRaises(sqlite3.OperationalError):
>             self.main("--inbox", self.inbox, "--db", self.inbox)  # a directory is no database
  
  
  class ModuleTest(unittest.TestCase):
```

### c175 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> # Not the file's fault (import_file handles FileError): keep nothing
> # of this file and let the caller see why.
```

### c176 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> # One row of HEADER per hour: three readings each (temperature, pressure, wind).
  ROW = {hour: f"2026-01-15T{hour:02d}:00,{3.0 + hour / 10:.1f},1012.{hour},4.{hour}\n"
         for hour in range(24)}
```

### c177 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def key(reading):
>     # Station, time and quantity identify a reading in the world. Every reading
>     # arrives in two overlapping exports, at different rows, and this key is
>     # what lets the second copy match the first.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c178 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c179 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
                  self.run_once()
          self.assertEqual(self.store.count(), 6)  # rolled back on the run's own connection
          store = self.committed()
>         self.assertEqual(store.count(), 6)  # A's, committed before B began
          self.assertIsNone(store.get("ST014|2026-01-15T02:00|temperature"))
          self.assertEqual(store.marker(A).state, "done")
          self.assertIsNone(store.marker(B))
```

### c180 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def exports(inbox):
>     """The names of the *.csv files in inbox, in name order."""
      return sorted(name for name in os.listdir(inbox)
                    if name.endswith(".csv") and os.path.isfile(os.path.join(inbox, name)))
  
```

### c181 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c182 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      self.addCleanup(failing.close)
      with self.assertRaises(sqlite3.OperationalError):
          self.run_once(failing)
>     failing.commit()  # would land anything the run left uncommitted
      self.assertEqual(self.store.count(), 3)
      self.assertEqual(self.store.marker(FIRST), Marker("done", 0, "3 stored, 0 duplicates, 0 rejected"))
      self.assertIsNone(self.store.marker(SECOND))
```

### c183 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.addCleanup(failing.close)
          with self.assertRaises(sqlite3.OperationalError):
              runner.run(self.inbox, failing, errors=self.errors)
>         self.assertEqual(failing.count(), 9)   # rolled back on this connection too
          store = self.reopened()
          self.assertEqual(store.count(), 9)
          self.assertEqual(store.marker(A).state, "done")
```

### c184 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  def key(reading):
      """The store key of a reading: the same in every export that carries it."""
>     # Not the row: the two exports that carry a reading carry it at different rows.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c185 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c186 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertFalse(os.path.exists(self.db))
  
      def test_module_runs_with_defaults(self):
>         # Defaults are relative to the working directory: ./inbox and ./readings.db.
          write(self.inbox, EARLY, HEADER + "2026-01-15T00:00,3.1,1012.4,4.2\n")
          done = subprocess.run([sys.executable, "-m", "readings"], cwd=self.base,
                                env={**os.environ, "PYTHONPATH": ROOT},
```

### c187 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(runner.key(reading), "ST014|2026-01-15T00:00|temperature")
  
      def test_overlapping_exports_store_each_reading_once(self):
>         # Written in reverse name order: the run's order must come from the names.
          write(self.inbox, SECOND, HEADER + ROW_0100 + ROW_0200)
          write(self.inbox, FIRST, HEADER + ROW_0000 + ROW_0100)
          self.assertEqual(self.run_once(),
```

### c188 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c189 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c190 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c191 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def key(reading):
>     # Station, time and quantity identify a reading in the world; a row number
>     # only identifies it in one file, and overlapping exports differ in rows.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c192 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """Import every station export in the inbox into the store, with nobody watching.
> 
> A file's readings and its marker are committed together, so a run that stops
> part-way leaves the store consistent with the inbox as far as it got.
> """
  import os
  from dataclasses import asdict, dataclass
  
```

### c193 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  @dataclass
  class Reading:
      station: str
>     row: int  # the row's number in its file, for a person opening it; not part of any key
      time: str
      quantity: str
      value: float
```

### c194 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.db = os.path.join(base, "readings.db")
  
      def main(self, *extra):
>         """(status, stdout, stderr) of one cli.main run against this test's inbox and db."""
          out, err = io.StringIO(), io.StringIO()
          with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
              status = cli.main(["--inbox", self.inbox, "--db", self.db, *extra])
```

### c195 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c196 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c197 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
              duplicates += 1
      store.set_marker(name, "done", 0, f"{stored} stored, {duplicates} duplicates, {len(rejected)} rejected")
      store.commit()
>     # counted only once committed, so the summary never claims what the store lacks
      summary.imported += 1
      summary.stored += stored
      summary.duplicates += duplicates
```

### c198 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> # A partial copy parses a run later; a file still failing after three runs
> # (eighteen hours at a six-hour interval) will not, and needs a person.
  POISON_AFTER = 3
```

### c199 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
      self.assertEqual(sorted({r.row for r in readings}), [1, 3])
  
  def test_file_that_cannot_be_opened_fails_the_file(self):
>     # listed in the inbox, then gone (or unreadable) by the time it is opened
      missing = os.path.join(self.dir, NAME)
      with self.assertRaisesRegex(parse.FileError, "^cannot read: "):
          parse.parse_file(missing)
```

### c200 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def exports(inbox):
>     """The names of the *.csv files in inbox, in name order."""
      return sorted(name for name in os.listdir(inbox)
                    if name.endswith(".csv") and os.path.isfile(os.path.join(inbox, name)))
  
```

### c201 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          write_utf16(self.inbox, D)
  
          runs = [self.main() for _ in range(3)]
>         write(self.inbox, B, HEADER + row(5))  # a new export arrives before the fourth run
          runs.append(self.main())
  
          self.assertEqual([status for status, _, _ in runs], [1, 1, 3, 3])
```

### c202 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.db = os.path.join(base, "readings.db")
  
      def invoke(self, argv):
>         """(exit status, stdout, stderr) of cli.main(argv)."""
          out, err = io.StringIO(), io.StringIO()
          with redirect_stdout(out), redirect_stderr(err):
              try:
```

### c203 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c204 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c205 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c206 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """Import every export in the inbox into the store, one file at a time."""
  import dataclasses
  import os
  from dataclasses import dataclass
```

### c207 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual([name for name, _ in runner.exports(self.inbox)], [EARLY])
  
      def test_done_and_poisoned_files_are_not_opened(self):
>         # Both files would raise FileError if they were read.
          write(self.inbox, EARLY, "garbage\n")
          write(self.inbox, LATE, "garbage\n")
          self.store.set_marker(EARLY, "done", 0, "3 stored, 0 duplicates, 0 rejected")
```

### c208 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def status(summary):
>     # A poisoned file needs a person whatever else happened, so it outranks a failure.
      if summary.poisoned:
          return 3
      if summary.failed:
```

### c209 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  class FailingStore(Store):
>     """A real Store whose nth add raises, as a full disk would."""
  
      def __init__(self, path, fail_on):
          super().__init__(path)
```

### c210 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          raise FileError("first column is not time")
      unknown = [column for column in header[1:] if column not in units.COLUMNS]
      if unknown:
>         # A station sending a column nobody has mapped, not a file full of bad rows.
          raise FileError(f"unknown columns: {', '.join(unknown)}")
  
      readings, rejected = [], []
```

### c211 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """python3 -m readings: import the inbox once, and exit with cli.main's status."""
  import sys
  
  from .cli import main
```

### c212 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c213 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def dump(path):
>     """Both tables, read through a fresh connection: what the commits left behind."""
      db = sqlite3.connect(path)
      try:
          return (db.execute("SELECT key, body FROM readings ORDER BY key").fetchall(),
```

### c214 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """The command line: import the inbox once, and say by exit status whether a person is needed.
> 
>     python3 -m readings [--inbox DIR] [--db PATH]
> """
  import argparse
  import os
  import sys
```

### c215 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c216 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c217 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def write_utf16(directory, name):
>     """A good export as the station with the firmware update writes it: UTF-16 with a BOM."""
      return write_bytes(directory, name, b"\xff\xfe" + (HEADER + row(0)).encode("utf-16-le"))
```

### c218 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.db = os.path.join(self.base, "readings.db")
  
      def main(self, *argv):
>         """(status, stdout, stderr) of cli.main over this test's inbox and store."""
          argv = argv or ("--inbox", self.inbox, "--db", self.db)
          out, err = io.StringIO(), io.StringIO()
          with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
```

### c219 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(store.count(), 3)
  
      def test_a_store_that_cannot_be_opened_stops_the_run(self):
>         # A directory where the store file should be: sqlite3 cannot open it.
          result = self.python_m("--db", self.base)
          self.assertEqual(result.returncode, 1)
          self.assertEqual(result.stdout, "")
```

### c220 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  DEFAULT_DB = "readings.db"
  
> # the summary line's fields, in the order it prints them
  COUNTS = ("files", "imported", "skipped", "failed", "poisoned", "stored", "duplicates", "rejected")
  
  
```

### c221 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
      self.assertEqual(problems, [(C, "failed", 1), (C, "failed", 2), (C, "poisoned", 3)])
      readings, _ = dump(self.db)
>     self.assertEqual(len(readings), 3)  # only A's; nothing of C, ever
  
  def test_unknown_column_fails_the_file_and_stores_nothing_of_it(self):
      write(self.inbox, A, "time,temp_c,humidity\n2026-01-15T00:00,3.1,80\n")
```

### c222 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """The command line: one unattended run over the inbox, answered by exit status."""
  import argparse
  import os
  import sys
```

### c223 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(summary, runner.Summary(files=2, imported=2, stored=12, duplicates=6))
          store = self.reopened()
          self.assertEqual(store.count(), 12)
>         # First stored wins: the reading is A's, row 2.
          self.assertEqual(store.get("ST014|2026-01-15T01:00|temperature")["row"], 2)
          self.assertEqual(store.marker(A).detail, "9 stored, 0 duplicates, 0 rejected")
          self.assertEqual(store.marker(B).detail, "3 stored, 6 duplicates, 0 rejected")
```

### c224 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def key(reading):
>     # Each reading arrives in two exports, at different row numbers; station,
>     # time and quantity are what the two copies share.
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c225 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c226 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          if not os.path.isdir(args.inbox):
              parser.error(f"inbox not found: {args.inbox}")
      except SystemExit as e:
>         # argparse exits on a usage error; main returns the status instead.
          return e.code
      store = Store(args.db)
      try:
```

### c227 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
              rejected.append(row)
              continue
          values = [v for v in values if v is not None]
>         # float() accepts "nan" and "inf", but neither is a reading
          if not all(math.isfinite(value) for _, value in values):
              rejected.append(row)
              continue
```

### c228 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
> """python3 -m readings: import the inbox once, and say by exit status whether a person is needed."""
  import argparse
  import os
  import sys
```

### c229 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c230 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def key(reading):
>     """The store key: two exports carrying the same reading give it the same key."""
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c231 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          return summary
  
      def reopened(self):
>         """The store as another process would see it: committed work only."""
          store = Store(self.db)
          self.addCleanup(store.close)
          return store
```

### c232 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  def row(hour):
>     """One good row of HEADER at <hour>:00 on 2026-01-15, holding three readings."""
      return f"2026-01-15T{hour:02d}:00,3.{hour},1012.{hour},4.{hour}\n"
  
  
```

### c233 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

### c234 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def exit_status(summary):
>     """3 if a poisoned file is in the inbox, else 1 if a file failed this run, else 0."""
      if summary.poisoned:
          return 3
      if summary.failed:
```

### c235 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  INBOX_DIR = "inbox"
  
> # A file that has failed this many runs is poisoned and skipped from then on.
> # Eighteen hours at Phase 3's six-hour interval; no partial copy in the measured
> # fortnight took more than one retry.
  POISON_AFTER = 3
  
  DONE = "done"
```

### c236 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  DB_PATH = "readings.db"
  
> # The summary line's fields, in the order runner.Summary declares them.
  COUNTS = ("files", "imported", "skipped", "failed", "poisoned", "stored", "duplicates", "rejected")
  
  
```

### c237 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
                                ("poisoned", 3, 0, 1, [])])
      store = self.reopened()
      self.assertTrue(store.marker(EARLY).detail.startswith("not text: "))
>     self.assertEqual(store.count(), 3)  # LATE's readings, stored once on the first run
  
  def test_a_failed_file_is_retried_and_imports_once_complete(self):
      self.export(EARLY, "time")  # a copy cut short inside the header
```

### c238 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def run(inbox, store):
>     """Import every *.csv file in inbox into store, in name order; return a Summary.
> 
>     A file's readings and its marker are committed together.
>     """
      summary = Summary()
      for name in exports(inbox):
          summary.files += 1
```

### c239 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          raise FileError(f"unknown column: {', '.join(unknown)}")
  
      readings, rejected = [], []
>     # row numbers are stable because a station never rewrites a file it has exported
      for row, fields in enumerate(body, 1):
          if len(fields) != len(header):
              rejected.append(row)
```

### c240 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
  
  
  def key(reading):
>     """The reading's store key: the same in every export that carries it."""
      return f"{reading.station}|{reading.time}|{reading.quantity}"
  
  
```

### c241 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.assertEqual(store.marker(A), Marker("done", 0, "3 stored, 0 duplicates, 0 rejected"))
  
      def test_overlapping_exports_store_each_reading_once(self):
>         # A station that drops empty rows: 01:00 is row 2 in A and row 1 in B.
          self.export(A, HEADER + ROW[0] + ROW[1] + ROW[2])
          self.export(B, HEADER + ROW[1] + ROW[2] + ROW[3])
          summary = self.run_once()
```

### c242 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

```python
          self.db = os.path.join(directory, "readings.db")
  
      def main(self, *argv):
>         """(exit status, stdout, stderr) of one cli.main over the test inbox and store."""
          out, err = io.StringIO(), io.StringIO()
          with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
              status = cli.main(["--inbox", self.inbox, "--db", self.db, *argv])
```

### c243 — docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md

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

