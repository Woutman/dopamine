def load_excluded_contacts(rows):
    return {row["email"].strip().lower() for row in rows if row.get("opted_out")}


def is_excluded_contact(contact, excluded_contacts):
    return contact is not None and contact.email.lower() in excluded_contacts
