from leadflow.api.auth import require_role
from leadflow.reports.weekly import weekly_summary


def get_weekly(user, leads, excluded_contacts):
    require_role(user, "manager")
    return weekly_summary(leads, excluded_contacts)
