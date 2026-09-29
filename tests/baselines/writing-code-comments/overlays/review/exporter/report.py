"""Command-line entrypoint: runs one export and prints its report."""

import json
import sys

from exporter.job import run
from exporter.source import Source
from exporter.store import Store


def format_report(result, requests):
    """The report line: exported, skipped, requests, stopped_by_budget and cursor, as key=value."""
    stopped = "yes" if result.stopped_by_budget else "no"
    return (f"exported={result.exported} skipped={result.skipped} requests={requests} "
            f"stopped_by_budget={stopped} cursor={result.cursor}")


def main(argv=None):
    """Run one export over the records in the JSON file argv[0], after cursor argv[1] if given.

    Prints the report line and returns the exit status.
    """
    argv = sys.argv[1:] if argv is None else argv
    if not 1 <= len(argv) <= 2:
        print("usage: python3 -m exporter.report RECORDS_JSON [CURSOR]", file=sys.stderr)
        return 2
    with open(argv[0], encoding="utf-8") as f:
        records = json.load(f)
    store = Store()
    result = run(Source(records), store, argv[1] if len(argv) == 2 else "")
    print(format_report(result, store.requests))
    return 1 if result.stopped_by_budget else 0


if __name__ == "__main__":
    sys.exit(main())
