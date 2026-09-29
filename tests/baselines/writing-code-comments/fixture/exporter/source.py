"""An in-memory stand-in for the source system the exporter reads from."""


class Source:
    def __init__(self, records):
        self._records = sorted(records, key=lambda record: record["id"])

    def page(self, after, size):
        """Up to `size` records whose id sorts after `after`, in id order; "" starts at the beginning."""
        return [record for record in self._records if record["id"] > after][:size]
