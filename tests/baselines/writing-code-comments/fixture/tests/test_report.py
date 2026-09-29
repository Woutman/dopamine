import unittest

from exporter import report


class ReportTest(unittest.TestCase):
    def test_is_a_placeholder(self):
        self.assertTrue(report.STUB)
        with self.assertRaises(NotImplementedError):
            report.main([])


if __name__ == "__main__":
    unittest.main()
