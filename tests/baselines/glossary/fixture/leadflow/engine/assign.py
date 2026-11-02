from leadflow.config.sectors import BLOCKED_SECTORS
from leadflow.config.thresholds import HOT_MIN, WARM_MIN
from leadflow.engine.bands import LeadBand
from leadflow.engine.score import score
from leadflow.registry.match import is_resolved


def assign_band(lead):
    if lead.company.sector in BLOCKED_SECTORS:
        return LeadBand.EXCLUDED
    total = score(lead)
    if total >= HOT_MIN:
        band = LeadBand.HOT
    elif total >= WARM_MIN:
        band = LeadBand.WARM
    else:
        band = LeadBand.NURTURE
    if not is_resolved(lead.match) and band in (LeadBand.HOT, LeadBand.WARM):
        return LeadBand.NURTURE
    return band


def assign_all(leads):
    for lead in leads:
        lead.band = assign_band(lead)
    return leads
