from datetime import date, timedelta

from leadflow.config.thresholds import DORMANT_DAYS
from leadflow.engine.bands import LeadBand


def is_dormant(lead, today=None):
    if lead.band is not LeadBand.NURTURE or lead.last_contacted is None:
        return False
    today = today or date.today()
    return today - lead.last_contacted >= timedelta(days=DORMANT_DAYS)
