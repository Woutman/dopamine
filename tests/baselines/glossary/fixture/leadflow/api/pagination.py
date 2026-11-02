from leadflow.config.portal import PAGE_SIZE


def page(items, number):
    start = (number - 1) * PAGE_SIZE
    return {"items": items[start:start + PAGE_SIZE], "page": number, "total": len(items)}
