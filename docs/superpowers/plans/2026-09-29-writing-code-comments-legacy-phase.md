# Code-comment discipline — Phase 1c: a legacy-phase scenario — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run scenario L: plan and then execute a rulings-heavy phase against ported prototype code, five runs of each, judged blind. Then stop for review with the human.

**Architecture:** A second fixture, `legacy-fixture/`, sits beside the first. It holds a weather-station readings importer: a ported prototype package, its tests, a phase spec in "X, not Y" rulings, an architecture note and the earlier phase's plan. The tooling learns to set up from another fixture and to commit an overlay under a given message. It also learns to score only `.py` files, to read `--stale` from code rather than prose, to count `§` pointers as labels, and to check both legacy stages against the phase spec. Each L-plan run writes a plan. The matching L-exec run starts from that plan, committed, and executes it in one session.

**Tech Stack:** bash, git, markdown; Python 3 for the baseline tooling, the fixture and the test suite.

**Spec:** `docs/superpowers/specs/2026-09-29-writing-code-comments-legacy-phase-design.md`, which amends `docs/superpowers/specs/2026-09-29-writing-code-comments-rebaseline-design.md`.

**Relation to earlier plans.** Phase 1b (`docs/superpowers/plans/2026-09-29-writing-code-comments-rebaseline.md`) ran P, R and M. All three were clean, and its results stay in `…writing-code-comments.baseline/red2/`. The first plan's Phase 2 is still on hold, pending this RED.

## Global Constraints

- **Nothing is copied from the study's source project.** The legacy fixture's domain, code, spec and wording are newly written. Only its scale and shapes follow the study.
- **The fixture is generic.** It has no house style, and its `CLAUDE.md` says nothing about comments.
- **Comments inside a plan's python code blocks are comments** (rebaseline design §2). L-exec is scored on `.py` files only (legacy design §4).
- **Categories, exactly:** `why contract warning narration bloat restatement`. Bad = `narration`, `bloat`, `restatement`.
- **L shows a problem** when either arm, `L0p` or `L0x`, averages at least one bad comment per run (legacy design §5).
- **Scripts are invoked through their interpreter** (`bash setup-run`, `python3 accept`), never by bare path.
- **`bash tests/run-tests.sh` exits 0 at the end of every task.**
- **Baseline runs and judging are done by the main session**, not an implementer subagent.
- **Specs, executed plans and earlier results are not edited.**

## Review Focus

1. **An execution that edits its plan's code blocks.** executing-plans ticks checkboxes and may fix a plan. Expected: L-exec's scoring ignores Markdown (`--py-only`). *(Task 1, the L0x-1 case.)*
2. **Plan prose that quotes the stale comment in order to remove it.** Phase 1b's `--stale` counted that. Expected: only code is searched. *(Task 1, the prose case.)*
3. **A plan run too small for the scenario.** Expected: `accept … legacy-plan` refuses a plan of five tasks, and the size check runs one plan before four more are paid for. *(Task 1; Task 2 Step 3.)*
4. **An execution that passes its own tests but not the spec.** Examples: row keys kept, or retrying forever. Expected: `accept … legacy-code` checks the spec through the interfaces it fixes. The prototype checks were mutation-tested against eight such defects. *(Task 1, legacy-fixture cases.)*
5. **`accept` importing `readings.__main__`**, which runs the CLI. Expected: skipped when the package's modules are walked. *(Task 1, `LEGACY_CHECKS`.)*

---

## File Structure

**Created, under `tests/baselines/writing-code-comments/`:**

| Path | Responsibility |
|---|---|
| `legacy-fixture/` | The project L-plan and L-exec start from |
| `prompts/legacy-plan.md` | L-plan's prompt |
| `prompts/legacy-exec.md` | L-exec's prompt |

**Modified:**
- `setup-run`: gains `--fixture` and `--message`.
- `extract-comments`: gains `--py-only`; `--stale` reads code, not prose; `§` pointers count as labels.
- `accept`: gains `legacy-code` and `legacy-plan`.
- `tests/scripts/test-baseline-tooling.sh`.

**Run scratch:** `.dopamine/run/baseline/legacy/`, which is gitignored.

**Results:** `docs/superpowers/plans/2026-09-29-writing-code-comments.baseline/legacy/`.

---

### Task 1: The legacy fixture and its tooling

**Files:**
- Create: everything under `tests/baselines/writing-code-comments/legacy-fixture/`
- Modify: `tests/baselines/writing-code-comments/setup-run`, `extract-comments`, `accept`
- Test: `tests/scripts/test-baseline-tooling.sh`

**Interfaces:**
- Consumes: `tests/helpers.sh` (`assert_eq`, `assert_contains`, `assert_not_contains`, `assert_exit`, `finish`), unchanged.
- Produces:
  - `bash setup-run [--fixture DIR] [--message MSG] RUNS_DIR LABEL [OVERLAY_DIR]`
    - Prints the run's directory.
    - `--fixture` defaults to `fixture/`, and a missing fixture exits 2.
    - `--message` is the overlay commit's subject. It defaults to `Batch writes and the run report`, as before.
  - `python3 extract-comments RUNS_DIR OUT_DIR [--seed N] [--stale REGEX] [--py-only]`
    - `runs.tsv` columns are unchanged.
    - `--stale` now searches only code regions: a `.py` file, or a Markdown file's python blocks.
    - `--py-only` skips Markdown.
  - `python3 accept RUN_DIR legacy-code` and `python3 accept RUN_DIR legacy-plan PLAN_PATH`
    - Each prints `ok` or the first failed check, and exits 0 or 1.
    - `legacy-plan` wants at least six `### Task N` headings.

- [ ] **Step 1: Write the failing test**

In `tests/scripts/test-baseline-tooling.sh`, insert the block below immediately before the line `echo "-- score"`:

```bash
echo "-- the legacy fixture"
L="$B/legacy-fixture"
RC=0
(cd "$L" && python3 -m unittest -q >/dev/null 2>&1) || RC=$?
assert_eq "its own tests pass as shipped" 0 "$RC"
assert_contains "it carries the comment the spec makes false" \
    "$(cat "$L/readings/runner.py")" "Keyed by station and row"
assert_exit "accept refuses it: the phase is not done" 1 python3 "$B/accept" "$L" legacy-code
legacy=$(bash "$B/setup-run" --fixture "$L" "$T/legacy" L0p-1)
assert_eq "setup-run takes another fixture" "" "$(git -C "$legacy" status --porcelain)"
assert_eq "and tags it" "$(git -C "$legacy" rev-parse HEAD)" "$(git -C "$legacy" rev-parse baseline-base)"
assert_exit "a fixture that does not exist exits 2" 2 bash "$B/setup-run" --fixture "$T/none" "$T/legacy" L0p-9
mkdir -p "$T/overlay/docs"
echo "# a plan" > "$T/overlay/docs/p.md"
exec_run=$(bash "$B/setup-run" --fixture "$L" --message "plan: Phase 2" "$T/legacy" L0x-1 "$T/overlay")
assert_eq "an overlay is committed under the message given" "plan: Phase 2" \
    "$(git -C "$exec_run" log -1 --format=%s)"
tasks() { for n in $(seq "$1"); do printf '### Task %s: step\n\n```python\nx = %s\n```\n\n' "$n" "$n"; done; }
{ tasks 6; printf 'readings/calibrate.py INBOX_DIR POISON_AFTER set_marker Summary readings/cli.py\n'; } \
    > "$legacy/docs/p.md"
git -C "$legacy" add -A && git -C "$legacy" commit -qm plan
assert_exit "accept takes a committed legacy plan of six tasks" 0 python3 "$B/accept" "$legacy" legacy-plan docs/p.md
{ tasks 5; printf 'readings/calibrate.py INBOX_DIR POISON_AFTER set_marker Summary readings/cli.py\n'; } \
    > "$legacy/docs/p.md"
git -C "$legacy" add -A && git -C "$legacy" commit -qm plan
assert_exit "but not one of five: the fixture would be too small" 1 \
    python3 "$B/accept" "$legacy" legacy-plan docs/p.md
{ tasks 6; printf 'readings/calibrate.py INBOX_DIR POISON_AFTER set_marker Summary readings/cli.py\n'; } \
    > "$legacy/docs/p.md"
echo "x = 1" >> "$legacy/readings/units.py"
git -C "$legacy" add -A && git -C "$legacy" commit -qm plan
assert_exit "nor one whose run changed the package" 1 python3 "$B/accept" "$legacy" legacy-plan docs/p.md

# L0x-1: an execution that edits a plan's code block and adds a comment in the package.
printf '```python\n# plan comment, see spec §4.2\nx = 1\n```\n' >> "$exec_run/docs/p.md"
printf '\n# no longer keyed by row\n' >> "$exec_run/readings/runner.py"
python3 "$B/extract-comments" "$T/legacy" "$T/lout" --py-only --stale 'Keyed by station and row' >/dev/null 2>&1
assert_not_contains "--py-only leaves out a plan's code" "$(cat "$T/lout/comments.md")" "plan comment"
assert_contains "and keeps the package's" "$(cat "$T/lout/comments.md")" "no longer keyed by row"
assert_contains "--stale finds the comment left in the code" "$(cat "$T/lout/runs.tsv")" $'L0x-1\t6\t2\t1\t0\t1'
python3 "$B/extract-comments" "$T/legacy" "$T/lout2" >/dev/null 2>&1
assert_contains "a pointer to a spec section counts as a label" \
    "$(cat "$T/lout2/runs.tsv")" $'L0x-1\t6\t4\t2\t1\t-'
mkdir -p "$T/prose"
prose=$(bash "$B/setup-run" "$T/prose" P0-1)
printf 'The comment saying the store has no batch write goes.\n' > "$prose/docs/p.md"
python3 "$B/extract-comments" "$T/prose" "$T/pout" --stale 'the store has no batch write' >/dev/null 2>&1
assert_contains "--stale does not read a plan's prose" "$(cat "$T/pout/runs.tsv")" $'P0-1\t1\t0\t0\t0\t0'
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/scripts/test-baseline-tooling.sh`
Expected: FAIL. `legacy-fixture` does not exist yet, so the legacy cases fail, starting with `its own tests pass as shipped`.

- [ ] **Step 3: Write the legacy fixture's package**

Every path below is under `tests/baselines/writing-code-comments/legacy-fixture/`. The comments are part of the stimulus: copy each file exactly, comments included.

`.gitignore`:

```text
__pycache__/
.superpowers/
```

`CLAUDE.md`:

````markdown
# Station readings

Imports the CSV files weather stations export into a reading store, for later analysis.

- Code: `readings/`. Tests: `tests/`, run with `python3 -m unittest`.
- How the pieces fit: `docs/architecture.md`.
- Design: `docs/superpowers/specs/`. Implementation plans: `docs/superpowers/plans/`.
````

`readings/__init__.py`:

```python
"""Readings from weather stations, imported from the CSV files they export."""
```

`readings/dialect.py`:

```python
"""Guess how a station's CSV export is written.

Stations are set up by whoever installed them, so the same columns arrive with a
comma or a semicolon between fields, and with a point or a comma as the decimal mark.
"""
import csv
from dataclasses import dataclass


@dataclass(frozen=True)
class Dialect:
    delimiter: str
    decimal: str


def sniff(text):
    """The dialect of an export, read from its header line.

    Raises ValueError when the header holds neither delimiter.
    """
    header = text.split("\n", 1)[0]
    # A semicolon file is a decimal-comma file: the comma is free to mark
    # decimals only because it is not separating fields.
    if header.count(";") > header.count(","):
        return Dialect(";", ",")
    if "," in header:
        return Dialect(",", ".")
    raise ValueError("header has no delimiter")


def rows(text, dialect):
    """The export's rows, header first, as lists of fields."""
    return list(csv.reader(text.splitlines(), delimiter=dialect.delimiter))
```

`readings/units.py`:

```python
"""Turn a field of a station export into a number in the unit the store keeps."""

# header -> (quantity, unit the column arrives in)
COLUMNS = {
    "temp_c": ("temperature", "C"),
    "temp_f": ("temperature", "F"),
    "pressure_hpa": ("pressure", "hPa"),
    "wind_ms": ("wind", "m/s"),
    "wind_kn": ("wind", "kn"),
}

KNOT = 0.514444  # m/s

# No station reports sea-level pressure above this; see parse_pressure.
PRESSURE_CEILING = 2000.0


def number(field, decimal):
    """The field as a float, or None when the station left it empty."""
    text = field.strip()
    if not text:
        return None
    if decimal == ",":
        text = text.replace(",", ".")
    return float(text)


def parse_pressure(value):
    # Halden loggers write pressure in tenths of a hectopascal and drop the
    # decimal mark, so 1013.2 hPa arrives as 10132. Real pressures never come
    # near the ceiling, so anything above it is one of those.
    if value > PRESSURE_CEILING:
        return value / 10
    return value


def convert(column, field, decimal):
    """(quantity, value in the store's unit) for one field, or None for an empty one.

    Raises KeyError for a column the store does not keep, ValueError for a field
    that is not a number.
    """
    quantity, unit = COLUMNS[column]
    value = number(field, decimal)
    if value is None:
        return None
    if unit == "F":
        value = (value - 32) * 5 / 9
    elif unit == "kn":
        value = value * KNOT
    elif quantity == "pressure":
        value = parse_pressure(value)
    return quantity, round(value, 2)
```

`readings/parse.py`:

```python
"""Read one station export into readings."""
import os
import re
from dataclasses import dataclass
from datetime import datetime

from . import dialect, units

FILE_NAME = re.compile(r"^(?P<station>[A-Z]{2,3}\d{2,3})_\d{12}\.csv$")


@dataclass
class Reading:
    station: str
    row: int
    time: str
    quantity: str
    value: float
    calibrated_value: float = None
    calibration_version: str = None


class FileError(ValueError):
    """The file as a whole cannot be read."""


def station_of(path):
    match = FILE_NAME.match(os.path.basename(path))
    if not match:
        raise FileError(f"not a station export: {os.path.basename(path)}")
    return match.group("station")


def parse_file(path):
    """(readings, rejected row numbers) for one export.

    Raises FileError when the file has no station name, is not text, or has no
    time column.
    """
    station = station_of(path)
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except UnicodeDecodeError as e:
        raise FileError(f"not text: {e}") from None
    try:
        found = dialect.sniff(text)
    except ValueError as e:
        raise FileError(str(e)) from None
    header, *body = dialect.rows(text, found)
    if not header or header[0] != "time":
        raise FileError("first column is not time")

    readings, rejected = [], []
    # row numbers are stable because a station never rewrites a file it has exported
    for row, fields in enumerate(body, 1):
        if len(fields) != len(header):
            rejected.append(row)
            continue
        try:
            time = datetime.fromisoformat(fields[0]).isoformat(timespec="minutes")
            values = [units.convert(c, f, found.decimal) for c, f in zip(header[1:], fields[1:])]
        except (KeyError, ValueError):
            rejected.append(row)
            continue
        for converted in values:
            if converted is not None:
                readings.append(Reading(station, row, time, *converted))
    return readings, rejected
```

`readings/calibrate.py`:

```python
"""Remote calibration: per-sensor offsets from the calibration service.

The service fits an offset for each station and quantity against the reference
stations nearby. Applying it fills a reading's calibrated_value.
"""
import json
import urllib.request

CALIBRATION_MODEL = "drift-offsets-v3"
SERVICE_URL = "https://calibration.invalid/v1/offsets"
TIMEOUT = 10  # seconds


class CalibrationError(RuntimeError):
    pass


def fetch_offsets(station, opener=urllib.request.urlopen):
    """{quantity: offset} for a station, under CALIBRATION_MODEL."""
    url = f"{SERVICE_URL}?station={station}&model={CALIBRATION_MODEL}"
    try:
        with opener(url, timeout=TIMEOUT) as response:
            body = json.load(response)
    except OSError as e:
        raise CalibrationError(f"calibration service: {e}") from None
    # the service answers 200 with an empty body while a model is refitting
    if not body.get("offsets"):
        raise CalibrationError(f"no offsets for {station}")
    return body["offsets"]


def apply(readings, offsets):
    for reading in readings:
        # add the offset
        reading.calibrated_value = round(reading.value + offsets.get(reading.quantity, 0.0), 2)
        reading.calibration_version = CALIBRATION_MODEL
```

`readings/runner.py`:

```python
"""Import every export the manifest lists.

Spike: run by hand on the notebook host, after the notebook has written the manifest.
"""
import os
import threading
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict
from enum import Enum

from . import calibrate
from .parse import FileError, parse_file

DROP_DIR = "drop"
MANIFEST = "manifest.txt"
PROGRESS_LOG = "progress.log"
WORKERS = 8  # eight keeps the notebook host busy without swapping
CALIBRATE = False  # off until the calibration service is back


class Outcome(Enum):
    STORED = "stored"
    DUPLICATE = "duplicate"
    REJECTED = "rejected"
    FAILED = "failed"
    CALIBRATION_FAILED = "calibration_failed"


def key(reading):
    # Keyed by station and row: importing the same file again maps its rows to
    # the same keys, so nothing is stored twice.
    return f"{reading.station}:{reading.row}:{reading.quantity}"


def load_progress(path):
    if not os.path.exists(path):
        return set()
    with open(path, encoding="utf-8") as f:
        return {line.strip() for line in f if line.strip()}


def import_file(path, sink, done, log, lock):
    counts = Counter()
    try:
        readings, rejected = parse_file(path)
    except FileError:
        counts[Outcome.FAILED] += 1
        return counts
    counts[Outcome.REJECTED] += len(rejected)
    if CALIBRATE:
        try:
            calibrate.apply(readings, calibrate.fetch_offsets(readings[0].station))
        except calibrate.CalibrationError:
            counts[Outcome.CALIBRATION_FAILED] += 1
    for reading in readings:
        k = key(reading)
        with lock:
            if k in done or k in sink:
                counts[Outcome.DUPLICATE] += 1
                continue
            sink[k] = asdict(reading)
            # One line per stored reading, so a crash loses at most the
            # reading being written.
            log.write(k + "\n")
            log.flush()
            done.add(k)
        counts[Outcome.STORED] += 1
    return counts


def run(base, sink):
    """Import the files listed in base/MANIFEST from base/DROP_DIR into sink.

    Returns a Counter of Outcomes.
    """
    with open(os.path.join(base, MANIFEST), encoding="utf-8") as f:
        names = [line.strip() for line in f if line.strip()]
    done = load_progress(os.path.join(base, PROGRESS_LOG))
    lock = threading.Lock()
    total = Counter()
    with open(os.path.join(base, PROGRESS_LOG), "a", encoding="utf-8") as log, \
            ThreadPoolExecutor(WORKERS) as pool:
        futures = [pool.submit(import_file, os.path.join(base, DROP_DIR, name), sink, done, log, lock)
                   for name in names]
        # collect the results
        for future in futures:
            total.update(future.result())
    return total
```

`readings/report.py`:

```python
"""A one-line account of a runner.run, for the notebook's log cell."""
from .runner import Outcome

ORDER = (Outcome.STORED, Outcome.DUPLICATE, Outcome.REJECTED, Outcome.FAILED,
         Outcome.CALIBRATION_FAILED)


def format_counts(counts):
    """'stored=12 duplicate=0 ...', every Outcome present, in ORDER."""
    return " ".join(f"{outcome.value}={counts.get(outcome, 0)}" for outcome in ORDER)


def worth_a_look(counts):
    # anything but stored and duplicate means someone should open the files
    return any(counts.get(o, 0) for o in ORDER if o not in (Outcome.STORED, Outcome.DUPLICATE))
```

`readings/store.py`:

```python
"""The reading store: readings under their keys, and a marker for each inbox file.

Nothing is written until commit(), so a caller can make a file's readings and its
marker land together.
"""
import json
import sqlite3
from dataclasses import dataclass

SCHEMA = """
CREATE TABLE IF NOT EXISTS readings (key TEXT PRIMARY KEY, body TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS markers (
    name TEXT PRIMARY KEY,
    state TEXT NOT NULL,
    failures INTEGER NOT NULL,
    detail TEXT NOT NULL
);
"""


@dataclass(frozen=True)
class Marker:
    state: str
    failures: int
    detail: str


class Store:
    def __init__(self, path):
        self._db = sqlite3.connect(path)
        self._db.executescript(SCHEMA)

    def add(self, key, reading):
        """Store a reading, a JSON-serialisable dict, under key.

        Returns False, storing nothing, when the key is already present.
        """
        cursor = self._db.execute("INSERT OR IGNORE INTO readings (key, body) VALUES (?, ?)",
                                  (key, json.dumps(reading, sort_keys=True)))
        return cursor.rowcount == 1

    def get(self, key):
        row = self._db.execute("SELECT body FROM readings WHERE key = ?", (key,)).fetchone()
        return None if row is None else json.loads(row[0])

    def count(self):
        return self._db.execute("SELECT COUNT(*) FROM readings").fetchone()[0]

    def marker(self, name):
        row = self._db.execute("SELECT state, failures, detail FROM markers WHERE name = ?",
                               (name,)).fetchone()
        return None if row is None else Marker(*row)

    def set_marker(self, name, state, failures=0, detail=""):
        self._db.execute("INSERT OR REPLACE INTO markers (name, state, failures, detail) "
                         "VALUES (?, ?, ?, ?)", (name, state, failures, detail))

    def commit(self):
        self._db.commit()

    def rollback(self):
        self._db.rollback()

    def close(self):
        self._db.close()
```

- [ ] **Step 4: Write the legacy fixture's tests**

`tests/__init__.py` is empty.

`tests/helpers.py`:

```python
import os
import tempfile

HEADER = "time,temp_c,pressure_hpa,wind_ms\n"


def write(directory, name, text):
    path = os.path.join(directory, name)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    return path


def temp_dir(case):
    handle = tempfile.TemporaryDirectory()
    case.addCleanup(handle.cleanup)
    return handle.name
```

`tests/test_dialect.py`:

```python
import unittest

from readings import dialect


class SniffTest(unittest.TestCase):
    def test_comma_file(self):
        self.assertEqual(dialect.sniff("time,temp_c\n2026-01-15T00:00,3.1\n"), dialect.Dialect(",", "."))

    def test_semicolon_file_uses_decimal_comma(self):
        self.assertEqual(dialect.sniff("time;temp_c\n2026-01-15T00:00;3,1\n"), dialect.Dialect(";", ","))

    def test_decimal_commas_in_body_do_not_confuse_it(self):
        text = "time;temp_c;wind_ms\n2026-01-15T00:00;3,1;4,2\n"
        self.assertEqual(dialect.sniff(text).delimiter, ";")

    def test_header_without_delimiter(self):
        with self.assertRaises(ValueError):
            dialect.sniff("time temp\n")

    def test_rows(self):
        rows = dialect.rows("time;temp_c\n2026-01-15T00:00;3,1\n", dialect.Dialect(";", ","))
        self.assertEqual(rows, [["time", "temp_c"], ["2026-01-15T00:00", "3,1"]])
```

`tests/test_units.py`:

```python
import unittest

from readings import units


class ConvertTest(unittest.TestCase):
    def test_celsius_unchanged(self):
        self.assertEqual(units.convert("temp_c", "3.1", "."), ("temperature", 3.1))

    def test_fahrenheit(self):
        self.assertEqual(units.convert("temp_f", "50", "."), ("temperature", 10.0))

    def test_knots(self):
        self.assertEqual(units.convert("wind_kn", "10", "."), ("wind", 5.14))

    def test_decimal_comma(self):
        self.assertEqual(units.convert("pressure_hpa", "1013,2", ","), ("pressure", 1013.2))

    def test_halden_pressure_in_tenths(self):
        self.assertEqual(units.convert("pressure_hpa", "10132", ","), ("pressure", 1013.2))

    def test_empty_field(self):
        self.assertIsNone(units.convert("wind_ms", " ", "."))

    def test_unknown_column(self):
        with self.assertRaises(KeyError):
            units.convert("humidity", "80", ".")

    def test_not_a_number(self):
        with self.assertRaises(ValueError):
            units.convert("temp_c", "n/a", ".")
```

`tests/test_parse.py`:

```python
import unittest

from readings import parse
from tests.helpers import HEADER, temp_dir, write


class ParseFileTest(unittest.TestCase):
    def setUp(self):
        self.dir = temp_dir(self)

    def test_readings_per_field(self):
        path = write(self.dir, "ST014_202601150600.csv", HEADER + "2026-01-15T00:00,3.1,1012.4,4.2\n")
        readings, rejected = parse.parse_file(path)
        self.assertEqual([(r.station, r.row, r.quantity, r.value) for r in readings],
                         [("ST014", 1, "temperature", 3.1), ("ST014", 1, "pressure", 1012.4),
                          ("ST014", 1, "wind", 4.2)])
        self.assertEqual(rejected, [])

    def test_bad_rows_are_rejected_not_fatal(self):
        path = write(self.dir, "ST014_202601150600.csv",
                     HEADER + "yesterday,3.1,1012.4,4.2\n2026-01-15T01:00,3.0,1012.1\n"
                              "2026-01-15T02:00,2.9,1011.9,3.8\n")
        readings, rejected = parse.parse_file(path)
        self.assertEqual(rejected, [1, 2])
        self.assertEqual({r.row for r in readings}, {3})

    def test_empty_field_is_no_reading(self):
        path = write(self.dir, "ST014_202601150600.csv", HEADER + "2026-01-15T00:00,3.1,1012.4,\n")
        readings, _ = parse.parse_file(path)
        self.assertEqual([r.quantity for r in readings], ["temperature", "pressure"])

    def test_not_a_station_export(self):
        path = write(self.dir, "notes.csv", HEADER)
        with self.assertRaises(parse.FileError):
            parse.parse_file(path)

    def test_binary_file(self):
        path = write(self.dir, "ST014_202601150600.csv", "")
        with open(path, "wb") as f:
            f.write(b"\xff\xfe\x00\x81")
        with self.assertRaises(parse.FileError):
            parse.parse_file(path)

    def test_no_time_column(self):
        path = write(self.dir, "ST014_202601150600.csv", "temp_c,wind_ms\n3.1,4.2\n")
        with self.assertRaises(parse.FileError):
            parse.parse_file(path)
```

`tests/test_calibrate.py`:

```python
import io
import json
import unittest

from readings import calibrate
from readings.parse import Reading


def answering(body):
    def opener(url, timeout):
        return io.BytesIO(json.dumps(body).encode())
    return opener


class CalibrateTest(unittest.TestCase):
    def test_offsets_are_applied(self):
        readings = [Reading("ST014", 1, "2026-01-15T00:00", "temperature", 3.1)]
        offsets = calibrate.fetch_offsets("ST014", answering({"offsets": {"temperature": -0.4}}))
        calibrate.apply(readings, offsets)
        self.assertEqual(readings[0].calibrated_value, 2.7)
        self.assertEqual(readings[0].calibration_version, calibrate.CALIBRATION_MODEL)

    def test_refitting_service_is_an_error(self):
        with self.assertRaises(calibrate.CalibrationError):
            calibrate.fetch_offsets("ST014", answering({}))

    def test_unreachable_service_is_an_error(self):
        def down(url, timeout):
            raise OSError("connection refused")
        with self.assertRaises(calibrate.CalibrationError):
            calibrate.fetch_offsets("ST014", down)
```

`tests/test_runner.py`:

```python
import os
import unittest
from unittest import mock

from readings import runner
from readings.runner import Outcome
from tests.helpers import HEADER, temp_dir, write


class RunnerTest(unittest.TestCase):
    def setUp(self):
        self.base = temp_dir(self)
        os.mkdir(os.path.join(self.base, runner.DROP_DIR))

    def drop(self, name, text):
        write(os.path.join(self.base, runner.DROP_DIR), name, text)
        with open(os.path.join(self.base, runner.MANIFEST), "a", encoding="utf-8") as f:
            f.write(name + "\n")

    def test_imports_listed_files(self):
        self.drop("ST014_202601150600.csv", HEADER + "2026-01-15T00:00,3.1,1012.4,4.2\n")
        sink = {}
        counts = runner.run(self.base, sink)
        self.assertEqual(counts[Outcome.STORED], 3)
        self.assertIn("ST014:1:temperature", sink)

    def test_second_run_resumes_from_progress_log(self):
        self.drop("ST014_202601150600.csv", HEADER + "2026-01-15T00:00,3.1,1012.4,4.2\n")
        runner.run(self.base, {})
        counts = runner.run(self.base, {})
        self.assertEqual(counts[Outcome.STORED], 0)
        self.assertEqual(counts[Outcome.DUPLICATE], 3)

    def test_unreadable_file_is_counted(self):
        self.drop("ST014_202601150600.csv", "garbage\n")
        self.assertEqual(runner.run(self.base, {})[Outcome.FAILED], 1)

    def test_rejected_rows_are_counted(self):
        self.drop("ST014_202601150600.csv", HEADER + "yesterday,3.1,1012.4,4.2\n")
        self.assertEqual(runner.run(self.base, {})[Outcome.REJECTED], 1)

    def test_calibration_failure_still_stores(self):
        self.drop("ST014_202601150600.csv", HEADER + "2026-01-15T00:00,3.1,1012.4,4.2\n")
        with mock.patch.object(runner, "CALIBRATE", True), \
                mock.patch.object(runner.calibrate, "fetch_offsets",
                                  side_effect=runner.calibrate.CalibrationError("down")):
            counts = runner.run(self.base, {})
        self.assertEqual(counts[Outcome.CALIBRATION_FAILED], 1)
        self.assertEqual(counts[Outcome.STORED], 3)
```

`tests/test_report.py`:

```python
import unittest
from collections import Counter

from readings import report
from readings.runner import Outcome


class ReportTest(unittest.TestCase):
    def test_every_outcome_in_order(self):
        self.assertEqual(report.format_counts(Counter({Outcome.STORED: 3})),
                         "stored=3 duplicate=0 rejected=0 failed=0 calibration_failed=0")

    def test_duplicates_alone_are_fine(self):
        self.assertFalse(report.worth_a_look(Counter({Outcome.STORED: 3, Outcome.DUPLICATE: 2})))

    def test_a_failure_is_worth_a_look(self):
        self.assertTrue(report.worth_a_look(Counter({Outcome.FAILED: 1})))
```

`tests/test_store.py`:

```python
import os
import unittest

from readings.store import Marker, Store
from tests.helpers import temp_dir


class StoreTest(unittest.TestCase):
    def setUp(self):
        self.path = os.path.join(temp_dir(self), "readings.db")
        self.store = Store(self.path)
        self.addCleanup(self.store.close)

    def test_add_refuses_a_present_key(self):
        self.assertTrue(self.store.add("k", {"value": 1}))
        self.assertFalse(self.store.add("k", {"value": 2}))
        self.assertEqual(self.store.get("k"), {"value": 1})

    def test_nothing_lands_before_commit(self):
        self.store.add("k", {"value": 1})
        self.store.set_marker("a.csv", "done")
        self.store.rollback()
        self.assertEqual(self.store.count(), 0)
        self.assertIsNone(self.store.marker("a.csv"))

    def test_committed_work_survives_reopening(self):
        self.store.add("k", {"value": 1})
        self.store.set_marker("a.csv", "failed", failures=2, detail="not text")
        self.store.commit()
        reopened = Store(self.path)
        self.addCleanup(reopened.close)
        self.assertEqual(reopened.count(), 1)
        self.assertEqual(reopened.marker("a.csv"), Marker("failed", 2, "not text"))

    def test_set_marker_replaces(self):
        self.store.set_marker("a.csv", "failed", failures=1)
        self.store.set_marker("a.csv", "done")
        self.assertEqual(self.store.marker("a.csv"), Marker("done", 0, ""))
```

Run: `cd tests/baselines/writing-code-comments/legacy-fixture && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -q`
Expected: `Ran 34 tests`, `OK`.

- [ ] **Step 5: Write the legacy fixture's documents**

`docs/architecture.md`:

````markdown
# Architecture

## 1. What this is

About forty weather stations, run by three different owners, export their readings as CSV files.
The files are copied into one directory, the **inbox**. This project imports them into a reading
store that the analysis notebooks read from.

## 2. The pieces

| Piece | Where | What it does |
|---|---|---|
| Stations | in the field | Export a CSV every six hours, covering the last twelve |
| Inbox | a directory on the import host | Holds every export, as delivered; nothing here deletes from it |
| Importer | `readings/` | Reads exports from the inbox into the store |
| Store | `readings/store.py`, one SQLite file | Readings under their keys, and one marker per inbox file |
| Analysis | notebooks, not in this repository | Reads the store |

## 3. The store's contract

- A reading is stored under a key the importer chooses. Adding a key that is present stores nothing
  and says so.
- A marker records what the importer last concluded about one inbox file: a state, a count of
  failures, and a detail line for a person.
- Nothing is written until the importer commits, so a file's readings and its marker can land
  together.
- The notebooks read readings only. Markers are the importer's own.

## 4. Phases

1. **Phase 1, done.** Port the notebook-era prototype into `readings/`, with tests, and build the
   store. Plan: `docs/superpowers/plans/2026-02-09-phase-1-port-and-store.md`.
2. **Phase 2, now.** Make the importer a program that can run unattended against the inbox. Spec:
   `docs/superpowers/specs/2026-03-02-phase-2-inbox-import-design.md`.
3. **Phase 3, later.** Run it on a timer, and alert a person when it needs one.
````

`docs/superpowers/plans/2026-02-09-phase-1-port-and-store.md`:

````markdown
# Phase 1: port the prototype and build the store — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The notebook-era import script, ported into a tested package, and the store Phase 2 will
import into.

**Architecture:** The prototype is ported as it is, module by module, with tests that pin what it
does today. Nothing is redesigned here: Phase 2 decides what survives. The store is new.

**Tech Stack:** Python 3 standard library, unittest, SQLite.

**Spec:** `docs/architecture.md` §2–§4.

**Status:** done. All tasks complete.

---

### Task 1: Port the prototype

**Files:**
- Create: `readings/dialect.py`, `readings/units.py`, `readings/parse.py`, `readings/calibrate.py`,
  `readings/runner.py`, `readings/report.py`
- Test: `tests/test_dialect.py`, `tests/test_units.py`, `tests/test_parse.py`,
  `tests/test_calibrate.py`, `tests/test_runner.py`, `tests/test_report.py`

- [x] **Step 1:** Copy each function out of the notebook's import cell into its module, unchanged
  apart from imports.
- [x] **Step 2:** Write tests that pin today's behaviour, including the Halden pressure quirk and
  the calibration path behind `CALIBRATE`.
- [x] **Step 3:** Run `python3 -m unittest`; expect OK. Commit.

### Task 2: The reading store

**Files:**
- Create: `readings/store.py`
- Test: `tests/test_store.py`

- [x] **Step 1: Write the failing tests** for a refused duplicate key, rollback, reopening, and
  marker replacement.
- [x] **Step 2: Implement `Store`**

```python
class Store:
    def __init__(self, path):
        self._db = sqlite3.connect(path)
        self._db.executescript(SCHEMA)

    def add(self, key, reading):
        cursor = self._db.execute("INSERT OR IGNORE INTO readings (key, body) VALUES (?, ?)",
                                  (key, json.dumps(reading, sort_keys=True)))
        return cursor.rowcount == 1
```

- [x] **Step 3:** `get`, `count`, `marker`, `set_marker`, `commit`, `rollback`, `close`, as in the
  tests.
- [x] **Step 4:** Run `python3 -m unittest`; expect OK. Commit.

---

**Not in this plan:** anything that decides what the ported runner becomes. That is Phase 2.
````

`docs/superpowers/specs/2026-03-02-phase-2-inbox-import-design.md`:

````markdown
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
````

- [ ] **Step 6: Replace `setup-run`**

```bash
#!/usr/bin/env bash
# Set up one baseline run: a fresh repository holding a fixture, its starting
# point tagged baseline-base so extract-comments finds what the run added even
# after the run commits its own work. An overlay is committed on top of the
# fixture and becomes the starting point: the review scenario starts from a
# finished, flawed implementation, and a legacy execution from its own plan.
#
# Usage: setup-run [--fixture DIR] [--message MSG] RUNS_DIR LABEL [OVERLAY_DIR]
#        (prints the run's directory; the fixture defaults to fixture/, the
#        overlay's commit message to the review overlay's)
set -euo pipefail

USAGE="usage: setup-run [--fixture DIR] [--message MSG] RUNS_DIR LABEL [OVERLAY_DIR]"
HERE="$(cd "$(dirname "$0")" && pwd)"
fixture="$HERE/fixture"
message="Batch writes and the run report"
while [ $# -gt 0 ]; do
    case "$1" in
        --fixture) [ $# -ge 2 ] || { echo "$USAGE" >&2; exit 2; }; fixture="$2"; shift 2 ;;
        --message) [ $# -ge 2 ] || { echo "$USAGE" >&2; exit 2; }; message="$2"; shift 2 ;;
        *) break ;;
    esac
done
[ $# -eq 2 ] || [ $# -eq 3 ] || { echo "$USAGE" >&2; exit 2; }
[ -d "$fixture" ] || { echo "no fixture at $fixture" >&2; exit 2; }
run="$1/$2"
[ ! -e "$run" ] || { echo "$run already exists" >&2; exit 1; }

commit() {
    git -C "$run" add -A
    git -C "$run" -c user.name=baseline -c user.email=baseline@localhost commit -qm "$1"
}

mkdir -p "$run"
cp -R "$fixture/." "$run/"
find "$run" -name __pycache__ -prune -exec rm -rf {} +
git -C "$run" init -q
commit fixture
if [ $# -eq 3 ]; then
    cp -R "$3/." "$run/"
    commit "$message"
fi
git -C "$run" tag baseline-base
cd "$run" && pwd
```

- [ ] **Step 7: Replace `extract-comments`**

The changes, all small:
- `--py-only`;
- `--stale` is searched per code region, after dedent, instead of over the whole file;
- `§\s*\d+` joins `LABEL`;
- the docstring and `USAGE` describe all three.

The whole file:

```python
#!/usr/bin/env python3
"""Pool the comments added across baseline runs into one blinded list.

Usage: extract-comments RUNS_DIR OUT_DIR [--seed N] [--stale REGEX] [--py-only]

Each subdirectory of RUNS_DIR holding a .git is one run, set up by setup-run.
A comment counts as added when any of its lines is added relative to the tag
baseline-base, so work the run committed and files it created both count.
Comments in a Markdown file's python code blocks count too: a plan's code is
the code that ships.
With --py-only, only .py files are read: an execution's plan edits are not its code.

Writes to OUT_DIR:
  comments.md   every added comment with surrounding code, shuffled, no run label
  key.tsv       id, run, file, first line, last line, kind
  runs.tsv      per run: lines added, added code lines, added comment lines,
                comments carrying a process label, and whether --stale matched
                the code of a file the run changed ("-" without --stale); a
                plan's prose is not its code
  verdicts.tsv  one row per id with an empty category, for the judge
  diffs/        each run's full diff, so a later judge can re-read the raw output
"""
import ast
import io
import os
import random
import re
import subprocess
import sys
import textwrap
import tokenize

CONTEXT = 3
USAGE = "usage: extract-comments RUNS_DIR OUT_DIR [--seed N] [--stale REGEX] [--py-only]"
FENCE = re.compile(r"^\s*(`{3,})\s*(\S*)\s*$")
LABEL = re.compile(r"\b(?:Task|Phase|Step|Critical|Important|Minor|Ruling|Finding|[Rr]ound)\s*#?\d+"
                   r"|§\s*\d+|Review Focus|review round|fix round")


def git(run, *args):
    return subprocess.run(["git", "-C", run, *args], check=True,
                          capture_output=True, text=True).stdout


def added_lines(patch):
    added, current, line = {}, None, 0
    for text in patch.splitlines():
        if text.startswith("+++ "):
            path = text[4:]
            current = None if path == "/dev/null" else path[2:]
            continue
        hunk = re.match(r"@@ -\S+ \+(\d+)", text)
        if hunk:
            line = int(hunk.group(1))
            continue
        if current and text.startswith("+"):
            added.setdefault(current, set()).add(line)
            line += 1
    return added


def fallback_units(source):
    # Code that does not parse, often a plan's partial snippet, is read line by line:
    # runs of '#' lines, inline '#' comments, and triple-quoted spans.
    units, opened = [], None
    for n, text in enumerate(source.splitlines(), 1):
        stripped = text.strip()
        if opened is not None:
            if '"""' in text:
                units.append((opened, n, "unparsed"))
                opened = None
        elif stripped.startswith(('"""', 'r"""')):
            if stripped.count('"""') >= 2:
                units.append((n, n, "unparsed"))
            else:
                opened = n
        elif stripped.startswith("#") and units and units[-1][1] == n - 1 \
                and source.splitlines()[n - 2].strip().startswith("#"):
            units[-1] = (units[-1][0], n, "unparsed")
        elif "#" in text:
            units.append((n, n, "unparsed"))
    return units


def comment_units(source):
    try:
        tokens = list(tokenize.generate_tokens(io.StringIO(source).readline))
        tree = ast.parse(source)
    except (SyntaxError, tokenize.TokenError):
        return fallback_units(source)
    units = []
    # Adjacent comment lines are read as one comment, so they are judged as one.
    for n in (t.start[0] for t in tokens if t.type == tokenize.COMMENT):
        if units and units[-1][1] == n - 1:
            units[-1] = (units[-1][0], n, "comment")
        else:
            units.append((n, n, "comment"))
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
            first = node.body[0] if node.body else None
            if (isinstance(first, ast.Expr) and isinstance(first.value, ast.Constant)
                    and isinstance(first.value.value, str)):
                units.append((first.lineno, first.end_lineno, "docstring"))
    return sorted(units)


def python_blocks(text):
    """(first line, lines) of each python code block in a Markdown text; first is 1-based."""
    blocks, fence, python, start, body = [], None, False, 0, []
    for n, line in enumerate(text.splitlines(), 1):
        match = FENCE.match(line)
        if fence is None:
            if match and match.group(2):
                fence, python, start, body = match.group(1), match.group(2) in ("python", "py"), n + 1, []
            elif match:
                fence, python, start, body = match.group(1), False, n + 1, []
        elif match and not match.group(2) and len(match.group(1)) >= len(fence):
            if python:
                blocks.append((start, body))
            fence = None
        else:
            body.append(line)
    return blocks


def code_regions(name, source):
    """(offset, lines) pairs: the whole file for Python, each python code block for Markdown."""
    if name.endswith(".py"):
        return [(0, source.splitlines())]
    if name.endswith(".md"):
        return [(start - 1, body) for start, body in python_blocks(source)]
    return []


def main():
    args = sys.argv[1:]
    py_only = "--py-only" in args
    args = [arg for arg in args if arg != "--py-only"]
    options = {"--seed": None, "--stale": None}
    for flag in options:
        if flag in args:
            at = args.index(flag)
            options[flag] = args[at + 1]
            del args[at:at + 2]
    if len(args) != 2:
        print(USAGE, file=sys.stderr)
        return 2
    runs_dir, out = args
    seed = None if options["--seed"] is None else int(options["--seed"])
    stale = None if options["--stale"] is None else re.compile(options["--stale"])
    os.makedirs(os.path.join(out, "diffs"), exist_ok=True)

    entries, runs = [], []
    for label in sorted(os.listdir(runs_dir)):
        run = os.path.join(runs_dir, label)
        if not os.path.isdir(os.path.join(run, ".git")):
            continue
        git(run, "add", "-A")
        with open(os.path.join(out, "diffs", label + ".diff"), "w", encoding="utf-8") as f:
            f.write(git(run, "diff", "--cached", "--no-color", "baseline-base", "--"))
        added = added_lines(git(run, "diff", "--cached", "--no-color", "-U0", "baseline-base", "--"))
        code = comment = labelled = 0
        stale_hit = False
        for name, numbers in sorted(added.items()):
            path = os.path.join(run, name)
            if not os.path.isfile(path) or not name.endswith(".py" if py_only else (".py", ".md")):
                continue
            with open(path, encoding="utf-8") as f:
                source = f.read()
            for offset, lines in code_regions(name, source):
                block = textwrap.dedent("\n".join(lines))
                stale_hit = stale_hit or bool(stale and stale.search(block))
                shown_lines = block.splitlines()
                code += len(numbers & set(range(offset + 1, offset + len(lines) + 1)))
                for first, last, kind in comment_units(block):
                    span = set(range(offset + first, offset + last + 1))
                    if numbers.isdisjoint(span):
                        continue
                    comment += len(numbers & span)
                    text = "\n".join(shown_lines[first - 1:last])
                    labelled += bool(LABEL.search(text))
                    lo, hi = max(1, first - CONTEXT), min(len(shown_lines), last + CONTEXT)
                    shown = [("> " if first <= n <= last else "  ") + shown_lines[n - 1]
                             for n in range(lo, hi + 1)]
                    entries.append((label, name, offset + first, offset + last, kind, "\n".join(shown)))
        runs.append((label, sum(len(lines) for lines in added.values()), code, comment, labelled,
                     "-" if stale is None else int(stale_hit)))

    random.Random(seed).shuffle(entries)
    with open(os.path.join(out, "comments.md"), "w", encoding="utf-8") as md, \
            open(os.path.join(out, "key.tsv"), "w", encoding="utf-8") as key, \
            open(os.path.join(out, "verdicts.tsv"), "w", encoding="utf-8") as verdicts:
        key.write("id\trun\tfile\tfirst\tlast\tkind\n")
        verdicts.write("id\tcategory\n")
        for n, (label, name, first, last, kind, shown) in enumerate(entries, 1):
            cid = f"c{n:03d}"
            md.write(f"### {cid} — {name}\n\n```python\n{shown}\n```\n\n")
            key.write(f"{cid}\t{label}\t{name}\t{first}\t{last}\t{kind}\n")
            verdicts.write(f"{cid}\t\n")
    with open(os.path.join(out, "runs.tsv"), "w", encoding="utf-8") as f:
        f.write("run\tadded\tcode\tcomment\tlabels\tstale\n")
        for row in runs:
            f.write("\t".join(str(value) for value in row) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 8: Replace `accept`**

The changes:
- `LEGACY_CHECKS`;
- `check_code` takes the checks to run and sets `PYTHONPATH` to the run, because the legacy checks change directory;
- `check_plan` takes the code paths, the names to find and a minimum task count;
- two new modes.

The whole file:

```python
#!/usr/bin/env python3
"""Check that one baseline run did its task, so a run that did not is replaced before judging.

Usage: accept RUN_DIR code
       accept RUN_DIR plan PLAN_PATH
       accept RUN_DIR legacy-code
       accept RUN_DIR legacy-plan PLAN_PATH

`code` runs the run's own tests, then checks batch writes, the budget, the cursor and the report
against the fixture's spec. `plan` checks that the plan is committed, has code for both features, and that the
run changed no code: a plan run that implemented it would be scored as a plan.

The legacy modes do the same for the legacy fixture. `legacy-code` checks its phase spec through the
interfaces the spec fixes: the calibration feature and its dependents gone, the new key, resume from
markers, the poison cap and the exit statuses. `legacy-plan` also wants at least six tasks: fewer
means the fixture is too small to test what it was built for.
Prints "ok", or the first check that failed, and exits 0 or 1.
"""
import os
import re
import subprocess
import sys

CHECKS = r'''
import contextlib, io, json, os, re, tempfile
from unittest import mock
from exporter import job, report
from exporter.source import Source
from exporter.store import Store

assert hasattr(job, "SOURCE_PAGE_SIZE") and not hasattr(job, "PAGE_SIZE"), "page size constant not renamed"
assert not getattr(report, "STUB", False), "report is still a stub"
records = [{"id": f"r{n:03d}", "status": "draft" if n % 10 == 0 else "live"} for n in range(230)]
store = Store()
result = job.run(Source(records), store)
assert (result.exported, result.skipped) == (207, 23), "wrong counts over 230 records"
assert len(store.records) == 207, "not every live record was written"
assert store.requests <= 10, f"{store.requests} requests for 230 records: not batched"
store = Store()
with mock.patch.object(job, "MAX_REQUESTS", 3):
    first = job.run(Source(records), store)
assert first.stopped_by_budget and store.requests <= 3, "budget exceeded or not reported"
second = Store()
job.run(Source(records), second, first.cursor)
assert not set(store.records) & set(second.records), "a resumed run repeated records"
assert len(store.records) + len(second.records) == 207, "a resumed run lost records"
path = os.path.join(tempfile.mkdtemp(), "records.json")
with open(path, "w", encoding="utf-8") as f:
    json.dump(records, f)
out = io.StringIO()
with contextlib.redirect_stdout(out):
    status = report.main([path])
assert status == 0, "report exit status"
assert re.fullmatch(r"exported=207 skipped=23 requests=(9|10) stopped_by_budget=no cursor=r229\n", out.getvalue()), "report line"
with mock.patch.object(job, "MAX_REQUESTS", 1), contextlib.redirect_stdout(io.StringIO()):
    assert report.main([path]) == 0, "a run stopped at the budget must exit 0"
'''


LEGACY_CHECKS = r"""
import ast, contextlib, importlib, importlib.util, io, os, pkgutil, re, tempfile
import readings
from readings import cli, parse, runner
from readings.store import Store

assert importlib.util.find_spec("readings.calibrate") is None, "readings/calibrate.py not deleted"
assert importlib.util.find_spec("readings.report") is None, "readings/report.py not deleted"
assert not os.path.exists("tests/test_calibrate.py"), "tests/test_calibrate.py not deleted"
fields = tuple(parse.Reading.__dataclass_fields__)
assert fields == ("station", "row", "time", "quantity", "value"), f"Reading has fields {fields}"
for info in pkgutil.iter_modules(readings.__path__):
    if info.name == "__main__":
        continue
    module = importlib.import_module("readings." + info.name)
    names = [n for n in vars(module) if "calibrat" in n.lower()]
    names += [m for m in getattr(getattr(module, "Outcome", None), "__members__", {})
              if "CALIBRAT" in m]
    assert not names, f"readings.{info.name} still has {names}"
    with open(module.__file__, encoding="utf-8") as f:
        tree = ast.parse(f.read())
    imported = {a.name.split(".")[0] for n in ast.walk(tree) if isinstance(n, ast.Import) for a in n.names}
    imported |= {(n.module or "").split(".")[0] for n in ast.walk(tree) if isinstance(n, ast.ImportFrom)}
    assert not imported & {"threading", "concurrent"}, f"readings.{info.name} still runs threads"
for gone in ("DROP_DIR", "MANIFEST", "PROGRESS_LOG", "WORKERS", "CALIBRATE"):
    assert not hasattr(runner, gone), f"runner.{gone} still defined"
assert runner.INBOX_DIR == "inbox", "INBOX_DIR is not 'inbox'"
assert runner.POISON_AFTER == 3, "POISON_AFTER is not 3"

work = tempfile.mkdtemp()
os.chdir(work)
inbox = os.path.join(work, "in")
os.mkdir(inbox)
db = os.path.join(work, "readings.db")
H = "time,temp_c,pressure_hpa,wind_ms\n"
def export(name, text, mode="w"):
    with open(os.path.join(inbox, name), mode) as f:
        f.write(text)
def hours(first, last):
    return "".join(f"2026-03-01T{h:02d}:00,{h / 10 + 3:.1f},{1010 + h:.1f},{h / 10 + 2:.1f}\n"
                   for h in range(first, last + 1))
export("ST014_202603010600.csv", H + hours(0, 5))
export("ST014_202603011200.csv", H + hours(3, 8))
export("HAL02_202603010600.csv",
       "time;temp_c;pressure_hpa;wind_ms\n2026-03-01T00:00;3,1;10124;4,2\n--:--;3,0;10121;4,0\n"
       "2026-03-01T02:00;2,9;10119;\n")
export("ST099_202603010600.csv", b"\xff\xfe\x00\x81garbage", "wb")
export("notes.txt", "not an export\n")

def call(*argv):
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        try:
            status = cli.main(list(argv))
        except SystemExit as e:
            status = e.code
    return status, out.getvalue(), err.getvalue()
def line(**n):
    order = ("files", "imported", "skipped", "failed", "poisoned", "stored", "duplicates", "rejected")
    return " ".join(f"{k}={n.get(k, 0)}" for k in order) + "\n"
def store():
    s = Store(db)
    return s, s.count(), s.marker("ST099_202603010600.csv")

status, out, err = call("--inbox", inbox, "--db", db)
assert status == 1, f"first run exited {status}, not 1 for a failed file"
assert out == line(files=4, imported=3, failed=1, stored=32, duplicates=9, rejected=1), "first run: " + out
assert re.search(r"^ST099_202603010600\.csv: failed \(1\): ", err, re.M), "no stderr line for the failed file"
s, count, marker = store()
assert count == 32, f"{count} readings stored, not 32: overlapping exports keyed wrongly"
assert s.get("HAL02|2026-03-01T00:00|pressure")["value"] == 1012.4, "key is not station|time|quantity"
assert s.marker("ST014_202603010600.csv").state == "done", "no done marker"
assert (marker.state, marker.failures) == ("failed", 1), f"failed file marker {marker}"
s.close()
status, out, _ = call("--inbox", inbox, "--db", db)
assert (status, out) == (1, line(files=4, skipped=3, failed=1)), "second run: " + out
status, out, _ = call("--inbox", inbox, "--db", db)
assert (status, out) == (3, line(files=4, skipped=3, poisoned=1)), f"third run exited {status}: " + out
status, out, _ = call("--inbox", inbox, "--db", db)
assert (status, out) == (3, line(files=4, skipped=3, poisoned=1)), f"fourth run exited {status}: " + out
s, count, marker = store()
assert count == 32, "later runs changed the store"
assert (marker.state, marker.failures) == ("poisoned", 3), f"poisoned file marker {marker}"
s.close()
assert sorted(os.listdir(work)) == ["in", "readings.db"], f"the run left {sorted(os.listdir(work))}"
assert len(os.listdir(inbox)) == 5, "the run changed the inbox"

other = os.path.join(work, "other")
os.mkdir(other)
with open(os.path.join(other, "ST015_202603010600.csv"), "w") as f:
    f.write("time,temp_c,humidity\n2026-03-01T00:00,3.1,80\n")
status, out, _ = call("--inbox", other, "--db", os.path.join(work, "other.db"))
assert (status, out) == (1, line(files=1, failed=1)), "an unknown column does not fail the file: " + out
status, _, _ = call("--inbox", os.path.join(work, "missing"), "--db", db)
assert status == 2, f"a missing inbox exited {status}, not 2"
"""


def check_code(run, checks=CHECKS):
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1", NO_COLOR="1", PYTHON_COLORS="0",
               PYTHONPATH=os.path.abspath(run))
    tests = subprocess.run([sys.executable, "-m", "unittest", "-q"], cwd=run, env=env,
                           capture_output=True, text=True)
    if tests.returncode != 0:
        return "the run's own tests fail"
    checks = subprocess.run([sys.executable, "-c", checks], cwd=run, env=env,
                            capture_output=True, text=True)
    if checks.returncode != 0:
        lines = checks.stderr.strip().splitlines()
        return lines[-1] if lines else "checks failed"
    return None


def check_plan(run, plan, code=("exporter", "tests"), needed=("put_many", "SOURCE_PAGE_SIZE", "stopped_by_budget"),
               tasks=0):
    tracked = subprocess.run(["git", "-C", run, "ls-files", "--error-unmatch", plan],
                             capture_output=True, text=True)
    if tracked.returncode != 0:
        return f"{plan} is not committed"
    changed = subprocess.run(["git", "-C", run, "diff", "--quiet", "baseline-base", "--", *code])
    if changed.returncode != 0:
        return "the plan run changed code"
    with open(os.path.join(run, plan), encoding="utf-8") as f:
        text = f.read()
    if len(re.findall(r"^\s*```+py(thon)?\s*$", text, re.M)) < 2:
        return "the plan has fewer than two python code blocks"
    found = len(re.findall(r"^#{2,4} Task \d+", text, re.M))
    if found < tasks:
        return f"the plan has {found} tasks, fewer than {tasks}"
    for name in needed:
        if name not in text:
            return f"the plan never mentions {name}"
    return None


def main():
    args = sys.argv[1:]
    if len(args) == 2 and args[1] == "code":
        problem = check_code(args[0])
    elif len(args) == 3 and args[1] == "plan":
        problem = check_plan(args[0], args[2])
    elif len(args) == 2 and args[1] == "legacy-code":
        problem = check_code(args[0], LEGACY_CHECKS)
    elif len(args) == 3 and args[1] == "legacy-plan":
        problem = check_plan(args[0], args[2], code=("readings", "tests"), tasks=6,
                             needed=("readings/calibrate.py", "INBOX_DIR", "POISON_AFTER", "set_marker",
                                     "Summary", "readings/cli.py"))
    else:
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        return 2
    print(problem or "ok")
    return 1 if problem else 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 9: Run the test to verify it passes**

Run: `bash tests/scripts/test-baseline-tooling.sh`
Expected: 57 `[PASS]`, then `OK`.

- [ ] **Step 10: Run the full suite**

Run: `bash tests/run-tests.sh`
Expected: `all 11 test file(s) passed`.

- [ ] **Step 11: Commit**

```bash
git add -A tests/baselines/writing-code-comments tests/scripts/test-baseline-tooling.sh
git commit -m "test: a legacy-phase fixture for the code-comment baseline"
```

---

### Task 2: L — a size check, ten runs judged blind, and stop

**Main session only.** It dispatches subagents and judges their output.

**Files:**
- Create: `tests/baselines/writing-code-comments/prompts/legacy-plan.md`, `prompts/legacy-exec.md`
- Create: `docs/superpowers/plans/2026-09-29-writing-code-comments.baseline/legacy/` (results)

**Interfaces:**
- Consumes: `setup-run --fixture/--message`, `accept … legacy-plan/legacy-code`, and `extract-comments --py-only/--stale` from Task 1, plus `score`, unchanged.

**Paths used below:**
- `B=tests/baselines/writing-code-comments`
- `R=.dopamine/run/baseline/legacy`
- `PLAN=docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md`, the path inside a run
- `SP=~/.claude/plugins/cache/claude-plugins-official/superpowers/6.4.1/skills`
- `{WRITING_PLANS}` = the absolute path of `$SP/writing-plans/SKILL.md`
- `{EXECUTING_PLANS}` = the absolute path of `$SP/executing-plans/SKILL.md`
- `{LOADED_SKILL}` is empty at RED.

- [ ] **Step 1: Write L-plan's prompt**

`prompts/legacy-plan.md`:

````markdown
You are working in the git repository at {RUN_DIR}.

Write the implementation plan for Phase 2. Its spec is `docs/superpowers/specs/2026-03-02-phase-2-inbox-import-design.md`. `docs/architecture.md` says how the pieces fit, and `docs/superpowers/plans/2026-02-09-phase-1-port-and-store.md` is the plan Phase 1 was built from.

Use the superpowers:writing-plans skill: it is at {WRITING_PLANS}; read it and follow it. Save the plan to `docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md` and commit it. Write the plan only: do not implement it, and end at the handoff rather than asking which execution approach to use.

Your final message is one line: `DONE`, or `BLOCKED: <reason>`.
{LOADED_SKILL}
````

- [ ] **Step 2: Write L-exec's prompt**

`prompts/legacy-exec.md`:

````markdown
You are working in the git repository at {RUN_DIR}.

Execute the plan at `docs/superpowers/plans/2026-03-04-phase-2-inbox-import.md`: every task, yourself, in this session. Use the superpowers:executing-plans skill: it is at {EXECUTING_PLANS}; read it and follow it, with the skills it requires. You have consent to work on the current branch without a worktree. Skip the skill's final review and everything after it: stop once the last task's ledger line is written.

Your final message is one line: `DONE`, or `BLOCKED: <reason>`.
{LOADED_SKILL}
````

- [ ] **Step 3: The size check: one plan run**

```bash
mkdir -p "$R/dispatched-prompts"
bash "$B/setup-run" --fixture "$B/legacy-fixture" "$R/plans" L0p-1
```

1. Dispatch one `general-purpose` Agent with no model override. Its prompt is `legacy-plan.md` with the slots filled. Save the filled prompt as `$R/dispatched-prompts/L0p-1.md`.
2. Run `python3 "$B/accept" "$R/plans/L0p-1" legacy-plan "$PLAN"`.
   - If it prints `the plan has N tasks, fewer than 6`, **stop.** The fixture is too small (legacy design §3). Record it in the ledger and report it to the human. Do not run the rest.
   - If it fails any other way, replace the run with the next label, as in Step 5.
3. Do not read the plan.

- [ ] **Step 4: Four more plan runs**

```bash
for n in 2 3 4 5; do bash "$B/setup-run" --fixture "$B/legacy-fixture" "$R/plans" "L0p-$n"; done
```

Dispatch four `general-purpose` Agent calls in one message, with no model override. Fill each prompt as in Step 3 and save it the same way.

- [ ] **Step 5: Check every plan run**

```bash
for r in "$R"/plans/*; do printf '%s %s\n' "$(basename "$r")" "$(python3 "$B/accept" "$r" legacy-plan "$PLAN")"; done
```

Expected: `ok` for every run.
- A run that is not `ok` is replaced: set up the next label (`L0p-6`), dispatch it the same way, and move the failed run to `$R/failed/`.
- Record each replacement and its reason in the ledger.
- The five accepted plan runs, in label order, are numbered 1–5 for Step 6.

- [ ] **Step 6: Five executions, each from its own plan**

For accepted plan run *k*, with its label written `<Pk>`:

```bash
mkdir -p "$R/overlays/L0x-$k/docs/superpowers/plans"
cp "$R/plans/<Pk>/$PLAN" "$R/overlays/L0x-$k/$PLAN"
bash "$B/setup-run" --fixture "$B/legacy-fixture" --message "plan: Phase 2, unattended import from the inbox" \
    "$R/execs" "L0x-$k" "$R/overlays/L0x-$k"
```

Record which plan run each execution came from in the ledger (`L0x-k ← <Pk>`).

Dispatch five `general-purpose` Agent calls in one message, with no model override. Each prompt is `legacy-exec.md` with `{RUN_DIR}`, `{EXECUTING_PLANS}` and an empty `{LOADED_SKILL}`, saved as `$R/dispatched-prompts/L0x-$k.md`.

- [ ] **Step 7: Check every execution**

```bash
for r in "$R"/execs/*; do printf '%s %s\n' "$(basename "$r")" "$(python3 "$B/accept" "$r" legacy-code)"; done
```

Expected: `ok` for every run.
- A run that is not `ok` is replaced once from the same plan, as `L0x-6` and upward, and the failed run moves to `$R/failed/`.
- If the replacement fails too, the plan is unexecutable:
  1. Record that in the ledger.
  2. Keep its L0p run.
  3. Set up and accept one more plan run, and execute that run's plan in its place.
- Record every replacement and its reason in the ledger.

- [ ] **Step 8: Extract**

```bash
STALE='Keyed by station and row|row numbers are stable'
python3 "$B/extract-comments" "$R/plans" "$R/out/plan" --stale "$STALE"
python3 "$B/extract-comments" "$R/execs" "$R/out/exec" --py-only --stale "$STALE"
```

- [ ] **Step 9: Judge, blind**

Open only `$R/out/plan/comments.md` and `$R/out/exec/comments.md`. **Do not open any `key.tsv`, `runs.tsv` or `diffs/`, or any run's plan, until every row of both `verdicts.tsv` files is filled.** Agents' final messages are one line, so there is nothing else to read.

For each entry, write one category:

| Category | The comment |
|---|---|
| `why` | Gives a reason, constraint or cause the code does not show |
| `contract` | Describes a public interface in the language's doc-comment format |
| `warning` | Tells a reader what breaks if they change something |
| `narration` | Refers to the change or the process that produced it: an earlier state ("now", "no longer", "renamed from", "was"), a task, phase or plan step, a review finding, round or ruling, or the absence of something removed |
| `bloat` | A why, contract or warning that argues rather than states: more than one reason where one carries it, a rejected alternative, enumerated defences, or more lines than the code it documents |
| `restatement` | Says what the adjacent code visibly does |

Tie-breaks, in order: anything narrating is `narration`; otherwise anything bloated is `bloat`. A bare pointer to a spec section is not narration by itself (legacy design §5). An entry copied from the fixture unchanged is never extracted, because it is not an added line.

- [ ] **Step 10: Score and record**

```bash
for stage in plan exec; do
  python3 "$B/score" "$R/out/$stage" > "$R/out/$stage/score.md"
  cat "$R/out/$stage/score.md"
done
D=docs/superpowers/plans/2026-09-29-writing-code-comments.baseline/legacy
mkdir -p "$D"
cp -R "$R/out/plan" "$R/out/exec" "$R/dispatched-prompts" "$D/"
```

Expected: one row per stage, `L0p` for plan and `L0x` for exec, and no `no change:` line.

- [ ] **Step 11: Commit and stop for review**

The gate is applied at the review, not here: L shows a problem when either arm averages at least one bad comment per run. Whatever the tables show, commit and **stop.**

```bash
git add tests/baselines/writing-code-comments/prompts docs/superpowers/plans/2026-09-29-writing-code-comments.baseline/legacy
git commit -m "test: RED baseline, legacy phase, for code-comment discipline"
```

- [ ] **Step 12: Report the findings to the human**

- Both `score.md` tables, and whether the gate is met, per arm.
- Every bad comment, quoted with its arm, grouped by category.
- Comments copied from a plan into its execution. The diffs show them once the verdicts are in. Report how many there were, and whether the plan's verdict and the code's agree.
- Plan sizes: lines, tasks and python blocks per plan.
- The comment share, labelled counts and stale-kept counts, and what they add to the verdicts.
- Hard-to-categorise comments and how they were resolved.
- Anything the runs did that the categories did not anticipate.

The rewrite of the first plan's Phase 2 is drafted with the human from these findings, together with Phase 1b's.
