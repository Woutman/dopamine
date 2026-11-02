"""Bands from the 2024 scoring model, kept for the backfill job."""

HOT_THRESHOLD = 0.75
WARM_THRESHOLD = 0.55


def legacy_band(total):
    if total >= HOT_THRESHOLD:
        return "hot"
    if total >= WARM_THRESHOLD:
        return "warm"
    return "cold"
