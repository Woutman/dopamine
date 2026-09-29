import io
import json
import unittest

from readings import calibrate
from readings.parse import Reading


def answering(body):
    def opener(url, timeout):
        return io.BytesIO(json.dumps(body).encode())
    return opener


class CalibrateTest(unittest.TestCase):
    def test_offsets_are_applied(self):
        readings = [Reading("ST014", 1, "2026-01-15T00:00", "temperature", 3.1)]
        offsets = calibrate.fetch_offsets("ST014", answering({"offsets": {"temperature": -0.4}}))
        calibrate.apply(readings, offsets)
        self.assertEqual(readings[0].calibrated_value, 2.7)
        self.assertEqual(readings[0].calibration_version, calibrate.CALIBRATION_MODEL)

    def test_refitting_service_is_an_error(self):
        with self.assertRaises(calibrate.CalibrationError):
            calibrate.fetch_offsets("ST014", answering({}))

    def test_unreachable_service_is_an_error(self):
        def down(url, timeout):
            raise OSError("connection refused")
        with self.assertRaises(calibrate.CalibrationError):
            calibrate.fetch_offsets("ST014", down)
