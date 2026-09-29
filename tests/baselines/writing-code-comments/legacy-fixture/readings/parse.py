"""Read one station export into readings."""
import os
import re
from dataclasses import dataclass
from datetime import datetime

from . import dialect, units

FILE_NAME = re.compile(r"^(?P<station>[A-Z]{2,3}\d{2,3})_\d{12}\.csv$")


@dataclass
class Reading:
    station: str
    row: int
    time: str
    quantity: str
    value: float
    calibrated_value: float = None
    calibration_version: str = None


class FileError(ValueError):
    """The file as a whole cannot be read."""


def station_of(path):
    match = FILE_NAME.match(os.path.basename(path))
    if not match:
        raise FileError(f"not a station export: {os.path.basename(path)}")
    return match.group("station")


def parse_file(path):
    """(readings, rejected row numbers) for one export.

    Raises FileError when the file has no station name, is not text, or has no
    time column.
    """
    station = station_of(path)
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except UnicodeDecodeError as e:
        raise FileError(f"not text: {e}") from None
    try:
        found = dialect.sniff(text)
    except ValueError as e:
        raise FileError(str(e)) from None
    header, *body = dialect.rows(text, found)
    if not header or header[0] != "time":
        raise FileError("first column is not time")

    readings, rejected = [], []
    # row numbers are stable because a station never rewrites a file it has exported
    for row, fields in enumerate(body, 1):
        if len(fields) != len(header):
            rejected.append(row)
            continue
        try:
            time = datetime.fromisoformat(fields[0]).isoformat(timespec="minutes")
            values = [units.convert(c, f, found.decimal) for c, f in zip(header[1:], fields[1:])]
        except (KeyError, ValueError):
            rejected.append(row)
            continue
        for converted in values:
            if converted is not None:
                readings.append(Reading(station, row, time, *converted))
    return readings, rejected
