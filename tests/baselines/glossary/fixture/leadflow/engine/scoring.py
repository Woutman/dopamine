from leadflow.engine.bands import THRESHOLDS, LeadBand

BLOCKED_SECTORS = frozenset({"gambling", "tobacco", "defence"})


def score(lead):
    return round(0.6 * lead.fit + 0.4 * lead.intent, 2)


def _unresolved(lead):
    return lead.company_id is None


def assign_band(lead):
    if lead.sector in BLOCKED_SECTORS:
        return LeadBand.EXCLUDED
    total = score(lead)
    band = LeadBand.NURTURE
    for candidate in (LeadBand.HOT, LeadBand.WARM):
        if total >= THRESHOLDS[candidate]:
            band = candidate
            break
    if _unresolved(lead) and band in (LeadBand.HOT, LeadBand.WARM):
        return LeadBand.NURTURE
    return band
