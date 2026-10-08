"""Remote calibration: per-sensor offsets from the calibration service.

The service fits an offset for each station and quantity against the reference
stations nearby. Applying it fills a reading's calibrated_value.
"""
import json
import urllib.request

CALIBRATION_MODEL = "drift-offsets-v3"
SERVICE_URL = "https://calibration.invalid/v1/offsets"
TIMEOUT = 10  # seconds


class CalibrationError(RuntimeError):
    pass


def fetch_offsets(station, opener=urllib.request.urlopen):
    """{quantity: offset} for a station, under CALIBRATION_MODEL."""
    url = f"{SERVICE_URL}?station={station}&model={CALIBRATION_MODEL}"
    try:
        with opener(url, timeout=TIMEOUT) as response:
            body = json.load(response)
    except OSError as e:
        raise CalibrationError(f"calibration service: {e}") from None
    # the service answers 200 with an empty body while a model is refitting
    if not body.get("offsets"):
        raise CalibrationError(f"no offsets for {station}")
    return body["offsets"]


def apply(readings, offsets):
    for reading in readings:
        # add the offset
        reading.calibrated_value = round(reading.value + offsets.get(reading.quantity, 0.0), 2)
        reading.calibration_version = CALIBRATION_MODEL
