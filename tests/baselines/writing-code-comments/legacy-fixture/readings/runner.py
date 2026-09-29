"""Import every export the manifest lists.

Spike: run by hand on the notebook host, after the notebook has written the manifest.
"""
import os
import threading
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict
from enum import Enum

from . import calibrate
from .parse import FileError, parse_file

DROP_DIR = "drop"
MANIFEST = "manifest.txt"
PROGRESS_LOG = "progress.log"
WORKERS = 8  # eight keeps the notebook host busy without swapping
CALIBRATE = False  # off until the calibration service is back


class Outcome(Enum):
    STORED = "stored"
    DUPLICATE = "duplicate"
    REJECTED = "rejected"
    FAILED = "failed"
    CALIBRATION_FAILED = "calibration_failed"


def key(reading):
    # Keyed by station and row: importing the same file again maps its rows to
    # the same keys, so nothing is stored twice.
    return f"{reading.station}:{reading.row}:{reading.quantity}"


def load_progress(path):
    if not os.path.exists(path):
        return set()
    with open(path, encoding="utf-8") as f:
        return {line.strip() for line in f if line.strip()}


def import_file(path, sink, done, log, lock):
    counts = Counter()
    try:
        readings, rejected = parse_file(path)
    except FileError:
        counts[Outcome.FAILED] += 1
        return counts
    counts[Outcome.REJECTED] += len(rejected)
    if CALIBRATE:
        try:
            calibrate.apply(readings, calibrate.fetch_offsets(readings[0].station))
        except calibrate.CalibrationError:
            counts[Outcome.CALIBRATION_FAILED] += 1
    for reading in readings:
        k = key(reading)
        with lock:
            if k in done or k in sink:
                counts[Outcome.DUPLICATE] += 1
                continue
            sink[k] = asdict(reading)
            # One line per stored reading, so a crash loses at most the
            # reading being written.
            log.write(k + "\n")
            log.flush()
            done.add(k)
        counts[Outcome.STORED] += 1
    return counts


def run(base, sink):
    """Import the files listed in base/MANIFEST from base/DROP_DIR into sink.

    Returns a Counter of Outcomes.
    """
    with open(os.path.join(base, MANIFEST), encoding="utf-8") as f:
        names = [line.strip() for line in f if line.strip()]
    done = load_progress(os.path.join(base, PROGRESS_LOG))
    lock = threading.Lock()
    total = Counter()
    with open(os.path.join(base, PROGRESS_LOG), "a", encoding="utf-8") as log, \
            ThreadPoolExecutor(WORKERS) as pool:
        futures = [pool.submit(import_file, os.path.join(base, DROP_DIR, name), sink, done, log, lock)
                   for name in names]
        # collect the results
        for future in futures:
            total.update(future.result())
    return total
