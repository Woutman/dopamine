from leadflow.api.auth import require_role
from leadflow.api.pagination import page
from leadflow.portal.feed import portal_feed


def list_leads(user, leads, excluded_contacts, number=1):
    require_role(user, "sales")
    return page(portal_feed(leads, excluded_contacts, user.get("locale", "nl")), number)
