from leadflow.engine.bands import LeadBand

_ORDER = {LeadBand.HOT: 0, LeadBand.WARM: 1, LeadBand.NURTURE: 2, LeadBand.EXCLUDED: 3}


def priority(lead):
    recency = -(lead.enriched_on.toordinal() if lead.enriched_on else 0)
    return (_ORDER[lead.band], recency)
