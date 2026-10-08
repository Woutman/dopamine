import unittest

from readings import dialect


class SniffTest(unittest.TestCase):
    def test_comma_file(self):
        self.assertEqual(dialect.sniff("time,temp_c\n2026-01-15T00:00,3.1\n"), dialect.Dialect(",", "."))

    def test_semicolon_file_uses_decimal_comma(self):
        self.assertEqual(dialect.sniff("time;temp_c\n2026-01-15T00:00;3,1\n"), dialect.Dialect(";", ","))

    def test_decimal_commas_in_body_do_not_confuse_it(self):
        text = "time;temp_c;wind_ms\n2026-01-15T00:00;3,1;4,2\n"
        self.assertEqual(dialect.sniff(text).delimiter, ";")

    def test_header_without_delimiter(self):
        with self.assertRaises(ValueError):
            dialect.sniff("time temp\n")

    def test_rows(self):
        rows = dialect.rows("time;temp_c\n2026-01-15T00:00;3,1\n", dialect.Dialect(";", ","))
        self.assertEqual(rows, [["time", "temp_c"], ["2026-01-15T00:00", "3,1"]])
