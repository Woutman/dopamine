import contextlib
import io
import json
import os
import tempfile
import unittest

from exporter import report


class ReportTest(unittest.TestCase):
    def run_report(self, records, *args):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "records.json")
            with open(path, "w", encoding="utf-8") as f:
                json.dump(records, f)
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                status = report.main([path, *args])
        return status, out.getvalue()

    def test_prints_the_report_line(self):
        status, out = self.run_report([{"id": "a", "status": "live"}, {"id": "b", "status": "draft"}])
        self.assertEqual(status, 0)
        self.assertEqual(out, "exported=1 skipped=1 requests=1 stopped_by_budget=no cursor=b\n")


if __name__ == "__main__":
    unittest.main()
