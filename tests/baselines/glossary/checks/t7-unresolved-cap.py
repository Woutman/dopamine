from leadflow.engine.bands import LeadBand
from leadflow.engine.scoring import assign_band
from leadflow.models import Lead

def lead(fit, company_id=None, sector="retail"):
    return Lead(id="l", company_id=company_id, sector=sector, fit=fit, intent=fit)

assert assign_band(lead(0.9)) == LeadBand.WARM
assert assign_band(lead(0.65)) == LeadBand.WARM
assert assign_band(lead(0.2)) == LeadBand.NURTURE
assert assign_band(lead(0.9, company_id="c")) == LeadBand.HOT
assert assign_band(lead(0.9, sector="tobacco")) == LeadBand.EXCLUDED
