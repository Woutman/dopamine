from leadflow.engine.legacy import legacy_band


def backfill(rows):
    return [{**row, "legacy_band": legacy_band(row["total"])} for row in rows]
