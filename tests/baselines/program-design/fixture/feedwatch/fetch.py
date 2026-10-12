"""Downloads a feed's XML. What the bytes mean is parse's business."""

import urllib.request


class FetchError(Exception):
    """A feed could not be downloaded."""


def fetch(url, timeout=10):
    try:
        with urllib.request.urlopen(url, timeout=timeout) as response:
            return response.read()
    except OSError as exc:
        raise FetchError(f"{url}: {exc}") from exc
