from leadflow.enrichment.freshness import is_stale
from leadflow.enrichment.pipeline import enrich


def run(provider, repository, today=None):
    stale = [lead for lead in repository.all_leads() if is_stale(lead, today)]
    for lead in stale:
        enrich(provider, lead, today)
    repository.save_all(stale)
    return len(stale)
