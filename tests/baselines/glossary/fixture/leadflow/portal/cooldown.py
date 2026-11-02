from datetime import date, timedelta

from leadflow.config.portal import COOLDOWN_DAYS


def in_cooldown(lead, today=None):
    if lead.dismissed_on is None:
        return False
    today = today or date.today()
    return today - lead.dismissed_on < timedelta(days=COOLDOWN_DAYS)
