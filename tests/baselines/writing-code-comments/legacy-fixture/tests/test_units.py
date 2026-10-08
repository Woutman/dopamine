import unittest

from readings import units


class ConvertTest(unittest.TestCase):
    def test_celsius_unchanged(self):
        self.assertEqual(units.convert("temp_c", "3.1", "."), ("temperature", 3.1))

    def test_fahrenheit(self):
        self.assertEqual(units.convert("temp_f", "50", "."), ("temperature", 10.0))

    def test_knots(self):
        self.assertEqual(units.convert("wind_kn", "10", "."), ("wind", 5.14))

    def test_decimal_comma(self):
        self.assertEqual(units.convert("pressure_hpa", "1013,2", ","), ("pressure", 1013.2))

    def test_halden_pressure_in_tenths(self):
        self.assertEqual(units.convert("pressure_hpa", "10132", ","), ("pressure", 1013.2))

    def test_empty_field(self):
        self.assertIsNone(units.convert("wind_ms", " ", "."))

    def test_unknown_column(self):
        with self.assertRaises(KeyError):
            units.convert("humidity", "80", ".")

    def test_not_a_number(self):
        with self.assertRaises(ValueError):
            units.convert("temp_c", "n/a", ".")
