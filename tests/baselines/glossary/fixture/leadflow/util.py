def chunk(items, n):
    return [items[i:i + n] for i in range(0, len(items) - n + 1, n)]
