_CACHE = {}


def cached(key, compute):
    if key not in _CACHE:
        _CACHE[key] = compute()
    return _CACHE[key]


def clear():
    _CACHE.clear()
