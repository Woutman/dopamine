"""The export job: copies records from the source to the store within a request budget."""

from dataclasses import dataclass

SOURCE_PAGE_SIZE = 100
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
        page = source.page(result.cursor, SOURCE_PAGE_SIZE)
        if not page:
            return result
        if store.requests >= MAX_REQUESTS:
            result.stopped_by_budget = True
            return result
        batch = []
        for record in page:
            if record["status"] == "draft":
                result.skipped += 1
            else:
                batch.append((record["id"], record))
        if batch:
            store.put_many(batch)
            result.exported += len(batch)
        result.cursor = page[-1]["id"]
