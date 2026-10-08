import unittest

from readings import parse
from tests.helpers import HEADER, temp_dir, write


class ParseFileTest(unittest.TestCase):
    def setUp(self):
        self.dir = temp_dir(self)

    def test_readings_per_field(self):
        path = write(self.dir, "ST014_202601150600.csv", HEADER + "2026-01-15T00:00,3.1,1012.4,4.2\n")
        readings, rejected = parse.parse_file(path)
        self.assertEqual([(r.station, r.row, r.quantity, r.value) for r in readings],
                         [("ST014", 1, "temperature", 3.1), ("ST014", 1, "pressure", 1012.4),
                          ("ST014", 1, "wind", 4.2)])
        self.assertEqual(rejected, [])

    def test_bad_rows_are_rejected_not_fatal(self):
        path = write(self.dir, "ST014_202601150600.csv",
                     HEADER + "yesterday,3.1,1012.4,4.2\n2026-01-15T01:00,3.0,1012.1\n"
                              "2026-01-15T02:00,2.9,1011.9,3.8\n")
        readings, rejected = parse.parse_file(path)
        self.assertEqual(rejected, [1, 2])
        self.assertEqual({r.row for r in readings}, {3})

    def test_empty_field_is_no_reading(self):
        path = write(self.dir, "ST014_202601150600.csv", HEADER + "2026-01-15T00:00,3.1,1012.4,\n")
        readings, _ = parse.parse_file(path)
        self.assertEqual([r.quantity for r in readings], ["temperature", "pressure"])

    def test_not_a_station_export(self):
        path = write(self.dir, "notes.csv", HEADER)
        with self.assertRaises(parse.FileError):
            parse.parse_file(path)

    def test_binary_file(self):
        path = write(self.dir, "ST014_202601150600.csv", "")
        with open(path, "wb") as f:
            f.write(b"\xff\xfe\x00\x81")
        with self.assertRaises(parse.FileError):
            parse.parse_file(path)

    def test_no_time_column(self):
        path = write(self.dir, "ST014_202601150600.csv", "temp_c,wind_ms\n3.1,4.2\n")
        with self.assertRaises(parse.FileError):
            parse.parse_file(path)
