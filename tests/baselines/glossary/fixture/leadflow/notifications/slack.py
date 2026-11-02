from leadflow.engine.bands import LeadBand


def hot_alert(lead):
    if lead.band is not LeadBand.HOT:
        return None
    return f":fire: {lead.company.name} ({lead.company.city}) is hot"
