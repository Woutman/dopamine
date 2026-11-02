from datetime import date, timedelta

from leadflow.config.enrichment import MAX_AGE_DAYS


def is_stale(lead, today=None):
    today = today or date.today()
    if lead.enriched_on is None:
        return True
    return today - lead.enriched_on > timedelta(days=MAX_AGE_DAYS)
