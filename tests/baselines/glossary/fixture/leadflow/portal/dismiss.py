from datetime import date


def dismiss(lead, today=None):
    lead.dismissed_on = today or date.today()
    return lead
