from datetime import date

from leadflow.enrichment.contacts import find_contact
from leadflow.enrichment.freshness import is_stale


def enrich(provider, lead, today=None):
    if not is_stale(lead, today):
        return lead
    lead.contact = find_contact(provider, lead.company)
    lead.enriched_on = today or date.today()
    return lead
