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
