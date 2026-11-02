def require_role(user, role):
    if role not in user.get("roles", ()):
        raise PermissionError(f"{user.get('id')} lacks {role}")
