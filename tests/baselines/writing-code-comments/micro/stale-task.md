{GUIDANCE}You are writing an implementation plan with superpowers:writing-plans, for a log-shipping agent. Two files matter here. `shipper/spool.py` currently reads:

```python
"""The spool: entries waiting to be shipped, keyed so a re-read file is not shipped twice."""


def spool_key(entry):
    # Keyed by file and line: shipping the same file again maps its lines to the same keys.
    return f"{entry.file}:{entry.line}"
```

and `shipper/read.py` currently reads:

```python
"""Read rotated log files into entries."""
from dataclasses import dataclass


@dataclass
class Entry:
    file: str
    line: int
    host: str
    ts: str
    seq: int
    text: str


class ReadError(Exception):
    """The file cannot be read as a log at all."""


def read_entries(path, host):
    """Every entry in the log file at path, in file order."""
    try:
        with open(path, encoding="utf-8") as f:
            lines = f.readlines()
    except UnicodeDecodeError as e:
        raise ReadError(f"not text: {e}") from None
    entries = []
    # line numbers are stable because the logger never rewrites a file it has rotated
    for line, raw in enumerate(lines, 1):
        ts, seq, text = raw.rstrip("\n").split(" ", 2)
        entries.append(Entry(path, line, host, ts, int(seq), text))
    return entries
```

The spec's decisions section reads:

<spec>
### 4.1 Key spooled entries by host, timestamp and sequence number, not by file and line

The logger ships a rotated file, and later ships its compressed copy as well; the same entry sits at different line numbers in the two. Host, timestamp and sequence number are the same in both. An entry keeps its line number so a person can find it in the file.

### 4.2 Skip a line that is not an entry, and count it

A blank line, or a line without a numeric sequence number, is skipped and counted, not a reason to fail the file. `read_entries` returns the entries and the count of skipped lines.
</spec>

The plan's Task 3 carries out 4.1 in `shipper/spool.py`. You are writing Task 2, which carries out 4.2. Write the code block for Task 2's implementation step: the whole of `shipper/read.py` after the change, as it would appear in the plan.

Reply with the python code block only.
