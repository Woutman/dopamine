"""The export job: copies records from the source to the store within a request budget."""

from dataclasses import dataclass

PAGE_SIZE = 100
MAX_REQUESTS = 500


@dataclass
class RunResult:
    exported: int = 0
    skipped: int = 0
    cursor: str = ""
    stopped_by_budget: bool = False


def run(source, store, cursor=""):
    """Export every record after `cursor`, stopping before the store would exceed MAX_REQUESTS.

    The result's cursor is the id of the last record dealt with, so the next run resumes after it.
    """
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
                # One put per record: the store has no batch write.
                store.put(record["id"], record)
                result.exported += 1
            result.cursor = record["id"]
