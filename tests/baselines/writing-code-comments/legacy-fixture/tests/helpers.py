import os
import tempfile

HEADER = "time,temp_c,pressure_hpa,wind_ms\n"


def write(directory, name, text):
    path = os.path.join(directory, name)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    return path


def temp_dir(case):
    handle = tempfile.TemporaryDirectory()
    case.addCleanup(handle.cleanup)
    return handle.name
