from leadflow.engine.assign import assign_all


def run(repository):
    leads = repository.all_leads()
    repository.save_all(assign_all(leads))
    return len(leads)
