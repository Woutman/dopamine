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
