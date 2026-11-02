from leadflow.crm.mapping import STAGE_FOR_STATUS


def stage_counts(crm_rows):
    counts = {}
    for row in crm_rows:
        stage = STAGE_FOR_STATUS.get(row["status"], "shown")
        counts[stage] = counts.get(stage, 0) + 1
    return counts
