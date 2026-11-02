from leadflow.engine.legacy import backfill_band


def backfill(rows):
    return [{**row, "backfill_band": backfill_band(row["total"])} for row in rows]
