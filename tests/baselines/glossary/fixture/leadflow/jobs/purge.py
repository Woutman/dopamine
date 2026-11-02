from leadflow.privacy.retention import expired


def run(repository, today=None):
    gone = [lead for lead in repository.all_leads() if expired(lead, today)]
    repository.delete_all(gone)
    return len(gone)
