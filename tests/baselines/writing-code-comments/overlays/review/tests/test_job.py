import unittest
from unittest import mock

from exporter import job
from exporter.source import Source
from exporter.store import Store


def record(id, status="live"):
    return {"id": id, "status": status}


class RunTest(unittest.TestCase):
    def test_exports_live_records_and_skips_drafts(self):
        """Drafts are counted as skipped and never written."""
        store = Store()
        result = job.run(Source([record("a"), record("b", "draft"), record("c")]), store)
        self.assertEqual(sorted(store.records), ["a", "c"])
        self.assertEqual((result.exported, result.skipped), (2, 1))

    def test_resumes_after_the_cursor(self):
        store = Store()
        job.run(Source([record("a"), record("b"), record("c")]), store, cursor="a")
        self.assertEqual(sorted(store.records), ["b", "c"])

    def test_writes_a_page_in_one_request(self):
        store = Store()
        job.run(Source([record("a"), record("b"), record("c")]), store)
        self.assertEqual(store.requests, 1)

    def test_stops_at_the_request_budget(self):
        """The run stops before the request that would exceed the budget, and says so."""
        store = Store()
        with mock.patch.object(job, "SOURCE_PAGE_SIZE", 2), mock.patch.object(job, "MAX_REQUESTS", 1):
            result = job.run(Source([record("a"), record("b"), record("c")]), store)
        self.assertTrue(result.stopped_by_budget)
        self.assertEqual((sorted(store.records), result.cursor), (["a", "b"], "b"))


if __name__ == "__main__":
    unittest.main()
