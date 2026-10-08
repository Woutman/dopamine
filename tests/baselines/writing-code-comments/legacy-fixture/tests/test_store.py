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
