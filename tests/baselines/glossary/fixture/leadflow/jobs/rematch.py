from leadflow.registry.lookup import lookup
from leadflow.registry.match import is_resolved


def run(client, repository):
    unresolved = [lead for lead in repository.all_leads() if not is_resolved(lead.match)]
    for lead in unresolved:
        lead.match = lookup(client, lead.company)
    repository.save_all(unresolved)
    return len(unresolved)
