# Phase 2: unattended import from the inbox — design

> **Status.** Settled 2026-03-02.
>
> **Builds on** `docs/architecture.md` and Phase 1
> (`docs/superpowers/plans/2026-02-09-phase-1-port-and-store.md`), which ported the prototype into
> `readings/` and built the store. This phase decides what of the ported package survives, and turns
> it into a program that runs against the inbox with nobody watching.

## 1. The governing constraint

**The importer runs unattended.** Phase 3 puts it on a timer; from then on nobody reads its output
unless it asks. Every run must therefore end in one of two conditions, and say which:

- the store is consistent with the inbox as far as the run got, and nothing needs a person; or
- something needs a person, and the run's exit status says so.

Everything below follows from this. A behaviour that is fine when someone watches the notebook
(a stack trace, a log that grows without bound, a list of files typed by hand) is a defect here.

## 2. What the ported package is worth

Phase 1 ported the notebook-era script unchanged. Its leaf functions are sound and were checked
against real exports; its runner was a spike, written to be watched.

| Module | Verdict | Why |
|---|---|---|
| `dialect.py` | Keep as is | Right on every export in the measured fortnight (§3) |
| `units.py` | Keep as is | Right on every export, including the Halden pressure quirk |
| `parse.py` | Keep, with two changes | `Reading` loses its calibration fields (§4.1); an unknown column fails the file (§7) |
| `store.py` | Keep as is | Phase 1's; its contract is `docs/architecture.md` §3 |
| `calibrate.py` | Delete | §4.1 |
| `runner.py` | Rewrite | Keys, resume, work list and concurrency are all decided against it (§4.2–§4.5) |
| `report.py` | Delete | Its vocabulary is the runner's `Outcome` counter, which the summary (§6.2) replaces |

What the ported package is not: evidence that its runner's choices were considered. They were the
fastest thing that worked with someone watching.

## 3. What was measured

Over the fortnight of 9–22 February, with the prototype run by hand each morning against a copy of
the inbox:

- **4,480 files from 40 stations.** Every station exports every six hours, covering the last twelve,
  so every reading arrives in two files.
- **Row keys stored 1.93 copies of each reading on average.** Seven stations drop empty rows before
  exporting, so a reading's row number differs between the two files that carry it.
- **The progress log reached 210 MB**, one line per stored reading, 3.1 million lines. Loading it at
  start-up took 9 seconds and grows linearly.
- **212 inbox files were never in the manifest.** The notebook that writes the manifest was not run
  on three days.
- **The thread pool against the store**: in a trial with eight workers writing to one SQLite file,
  14% of runs failed with `database is locked`. One worker imports a day's 320 files in 41 seconds.
- **23 files failed to parse.** 19 were partial copies still being written, and parsed on the next
  run. 4 were from one station whose firmware update switched it to UTF-16; they will never parse.
- **Bad rows**: 61 rows in 13 files, nearly all a time field of `--:--` written during a clock reset.
- **The calibration service** was decommissioned in January. No notebook reads `calibrated_value`;
  the analysis group calibrates in the notebooks, against reference stations of its own choosing.

## 4. Decisions

### 4.1 Delete remote calibration, not disable it

`calibrate.py`, its constant, the two `Reading` fields it fills, the `Outcome` member only it
produces, the `CALIBRATE` flag and its branch in the runner, and its tests all go.

Keeping it behind the flag was considered: it is small and tested. Against: the service it calls no
longer exists (§3), so the flag guards code that cannot run; its fields sit on every reading the
store keeps, and the notebooks would have to learn to ignore them; and the tests that pin it test a
network contract nobody can check. If calibration returns it will be in the notebooks, where §3
says it already is.

### 4.2 Key readings by station, time and quantity, not by row

A reading's key is `f"{station}|{time}|{quantity}"`, with `time` as `parse_file` normalises it.

The row key was chosen for idempotence: importing one file twice maps to the same keys. That holds,
but the problem is two different files carrying the same reading (§3), where the row differs and
the key is the only thing that could match them. Station, time and quantity identify a reading in
the world; a row identifies it in one file.

When two files carry the same reading with different values, the first stored wins and the second
counts as a duplicate. §12 says why that is acceptable for now.

### 4.3 Markers in the store replace the progress log

Each inbox file gets one marker (`docs/architecture.md` §3), committed in the same transaction as
the file's readings. A file whose marker is `done` is not read again.

The progress log recorded readings, not files, and outside the store: a crash between a reading
reaching the sink and its line reaching the log left the two disagreeing, and its size grows with
every reading ever stored (§3). A marker per file is written with the file's readings or not at
all, and the number of markers grows with the number of files. The log file, its constant, and the
code that reads and writes it go.

### 4.4 The inbox is the work list, not a manifest

A run imports every `*.csv` file in the inbox, in name order. Anything else in the inbox is ignored.

The manifest was written by a notebook, by hand, and missed 212 files in a fortnight (§3). The inbox
holds every export by construction (`docs/architecture.md` §2); markers already say which files are
done, so a second list of what to do has nothing left to add. Name order makes a run's log
reproducible and imports each station's exports oldest first.

### 4.5 One file at a time, not a thread pool

The runner imports files sequentially, in one process, through one `Store`.

The pool made sense for the notebook's dictionary sink. The store is one SQLite file with one
writer; eight workers against it failed one run in seven (§3), and a day's files take 41 seconds
on one. The pool, its lock and `WORKERS` go.

### 4.6 A bad row is rejected, not a reason to fail the file

A row that does not parse (§7) is counted as rejected and the rest of the file is imported.

Failing the file was considered, so that a person looks at every bad row. Against: nearly every bad
row in the fortnight was a clock reset (§3), a person can do nothing about it, and failing the
whole file would drop the good rows around it until the file is poisoned. The count of rejected rows
goes in the file's marker, where a person can find it.

### 4.7 A file that fails three runs is poisoned, not retried forever

A file that fails is retried on the next run. When a file has failed `POISON_AFTER = 3` runs, its
marker's state becomes `poisoned`, and later runs skip it.

Most failures are partial copies that parse a run later (§3), so the first failure must not need a
person. Retrying forever was the prototype's behaviour; the UTF-16 files would fail every six hours
indefinitely, and nobody would hear about them. Three runs is eighteen hours at Phase 3's
interval: a partial copy never took more than one retry in the fortnight.

### 4.8 The exit status says whether a person is needed, not how much went wrong

Four statuses (§8). A run with a poisoned file in the inbox exits 3, whatever else happened.

Phase 3's timer can only act on the exit status, and it has one decision to make: alert someone or
not. A count of failures would make it choose a threshold, and that choice belongs here, where the
failure taxonomy (§7) is.

## 5. Layout

After this phase:

| Path | Holds |
|---|---|
| `readings/dialect.py`, `readings/units.py` | Unchanged |
| `readings/parse.py` | `Reading(station, row, time, quantity, value)`; `parse_file`; `FileError` |
| `readings/store.py` | Unchanged |
| `readings/runner.py` | `INBOX_DIR`, `POISON_AFTER`, `key`, `Summary`, `run` |
| `readings/cli.py` | `main(argv) -> int` |
| `readings/__main__.py` | Calls `cli.main` and exits with its status |

`readings/calibrate.py`, `readings/report.py`, `tests/test_calibrate.py` and `tests/test_report.py`
are deleted. `tests/test_runner.py` is rewritten against the new runner.

The directory is the **inbox** everywhere, as in `docs/architecture.md`. The prototype's `DROP_DIR`
becomes `INBOX_DIR = "inbox"`, the command line's default.

`Reading` keeps `row`: a rejected row is reported by number, and a person opening the file needs it.
It is no longer part of any key.

## 6. The run loop

### 6.1 One run

`run(inbox, store) -> Summary` does, for each `*.csv` in `inbox` in name order:

1. Read the file's marker. `done`: count it `skipped`, go on. `poisoned`: count it `poisoned`, go on.
   Neither is opened.
2. `parse_file(path)`. On `FileError`:
   - roll back, so nothing of this file is kept;
   - set the marker to `failed`, with failures one more than before and the error as its detail;
   - if that makes failures reach `POISON_AFTER`, the state is `poisoned` instead;
   - commit, count the file `failed` or `poisoned`, go on.
3. Add each reading under `key(reading)`, as `dataclasses.asdict(reading)`. `add` returning `False`
   counts a duplicate; `True` counts it stored.
4. Set the marker to `done`, failures 0, with the detail `"<n> stored, <n> duplicates, <n> rejected"`.
5. Commit. The readings and the marker land together or not at all.

An exception that is not a `FileError` is not the file's fault (the store cannot be written, the
disk is full). The run rolls back and lets it propagate. The interpreter exits 1, which §8 treats
as a failed run: the next run retries it.

### 6.2 The summary

```python
@dataclass
class Summary:
    files: int = 0       # *.csv files in the inbox
    imported: int = 0    # read this run and marked done
    skipped: int = 0     # already done, not opened
    failed: int = 0      # failed this run, will be retried
    poisoned: int = 0    # poisoned, this run or before
    stored: int = 0
    duplicates: int = 0
    rejected: int = 0
```

`files == imported + skipped + failed + poisoned` after every run.

### 6.3 The summary line

`cli.main` prints one line to stdout, the fields in the order above:

```
files=4 imported=2 skipped=1 failed=1 poisoned=0 stored=30 duplicates=6 rejected=1
```

Nothing else goes to stdout. A file that failed or was poisoned this run gets one line on stderr,
`<name>: <state> (<failures>): <detail>`, for whoever reads the timer's log.

## 7. Failure taxonomy

| Unit | Condition | Effect |
|---|---|---|
| Field | Empty | No reading for that field; not a rejection |
| Row | Wrong number of fields; time not ISO 8601; a field not a number | Row rejected and counted; the file imports |
| File | Name not a station export; not UTF-8; header without a delimiter; first column not `time`; a column `units.COLUMNS` does not know | `FileError`; the file fails; nothing of it is kept |
| File, third time | Failed `POISON_AFTER` runs | Marker `poisoned`; skipped from then on |
| Run | Anything not a `FileError` | Rolled back; the exception propagates |

The unknown column moves from row to file. The prototype rejected every row of such a file one by
one, as `KeyError`s, which looked like a file full of bad data rather than a station sending a
column nobody has mapped. `parse_file` checks the header against `units.COLUMNS` before reading
any row.

## 8. Exit status

| Status | Meaning | Needs a person |
|---|---|---|
| 0 | Nothing failed, and no poisoned file is in the inbox | No |
| 1 | A file failed this run and will be retried; or the run stopped (§6.1) | Not yet |
| 2 | Usage error (argparse's own) | Whoever set up the timer |
| 3 | A poisoned file is in the inbox | Yes |

3 takes precedence over 1. A poisoned file keeps the status at 3 on every run until a person
clears its marker (§10).

## 9. Command line

```
python3 -m readings [--inbox DIR] [--db PATH]
```

`--inbox` defaults to `INBOX_DIR`, `--db` to `readings.db`. An inbox that does not exist is a usage
error, exit 2.

## 10. Not this phase

- **The timer and alerting.** Phase 3.
- **Clearing a poisoned file.** By hand for now: delete its row from the store's `markers` table.
  A command for it waits until Phase 3 shows how often it is needed.
- **Deleting or moving files out of the inbox.** The inbox keeps every export (`docs/architecture.md`
  §2).
- **Conflicting duplicates.** Recorded as duplicates; §12.
- **Changes to the store.** Its contract stands.

## 11. Testing

**What counts as evidence:**

- Tests of `run` against a real `Store` on a temporary file and real exports in a temporary inbox.
  The transaction is what §4.3 and §6.1 rest on; a fake store cannot fail halfway.
- Tests of `cli.main(argv)` that check the exit status and the exact summary line.
- A test that re-runs over the same inbox and checks both the counts and the store.

**The cases:**

- two exports of one station whose windows overlap, with rows in different positions: each reading
  stored once, the rest duplicates;
- a second run: every file skipped, nothing stored, the store unchanged;
- a bad row in an otherwise good file: rejected, the rest stored, the file done;
- an unreadable file over four runs: failed, failed, poisoned, poisoned; failures stop at 3; exit
  statuses 1, 1, 3, 3;
- a file with an unknown column: failed, nothing of it stored;
- a store error halfway through a file: nothing of that file stored, no marker, the exception
  propagates;
- a missing inbox: exit 2.

**What is not evidence:**

- The prototype's tests. They pin the prototype, which this phase is changing.
- A passing run over an inbox where every file is good. The design is about the ones that are not.
- The summary line alone. Every test that checks counts checks the store too.

## 12. Risks, in the order they will bite

1. **A partial copy that parses.** A file copied halfway can end on a row boundary. It imports as
   `done`, and the complete copy, arriving under the same name, is skipped. The missing rows
   arrive again in the station's next export, twelve hours of overlap (§3), so this loses readings
   only when two consecutive exports are both cut short. Watch the rejected counts in markers for
   files that end early.
2. **First stored wins.** A station that re-sends a corrected value has the correction counted as a
   duplicate. The fortnight had none that we could find, but we only looked at duplicates with
   equal values.
3. **Eighteen hours to poison.** At Phase 3's interval a permanently broken file is retried for
   eighteen hours before anyone hears. Lowering `POISON_AFTER` trades that for alerts on partial
   copies.
4. **The inbox grows without bound.** Listing it and reading one marker per file is fast at a
   year's 115,000 files; a later phase archives old exports.
