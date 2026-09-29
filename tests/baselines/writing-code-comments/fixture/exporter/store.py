"""An in-memory stand-in for the record store the exporter writes to."""

MAX_BATCH = 25


class StoreError(Exception):
    pass


class Store:
    def __init__(self):
        self.records = {}
        self.requests = 0

    def put(self, key, record):
        """Write one record, in one request."""
        self.requests += 1
        self.records[key] = record

    def put_many(self, records):
        """Write up to MAX_BATCH (key, record) pairs in one request.

        Raises StoreError for a larger batch, and writes nothing.
        """
        if len(records) > MAX_BATCH:
            raise StoreError(f"batch of {len(records)} exceeds {MAX_BATCH}")
        self.requests += 1
        for key, record in records:
            self.records[key] = record
