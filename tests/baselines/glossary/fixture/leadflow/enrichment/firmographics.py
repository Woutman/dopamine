def employees_band(count):
    if count is None:
        return "unknown"
    if count < 10:
        return "micro"
    if count < 50:
        return "small"
    if count < 250:
        return "medium"
    return "large"
