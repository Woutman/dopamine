from datetime import date, timedelta

RETENTION_DAYS = 730


def expired(lead, today=None):
    today = today or date.today()
    return lead.enriched_on is not None and today - lead.enriched_on > timedelta(days=RETENTION_DAYS)
