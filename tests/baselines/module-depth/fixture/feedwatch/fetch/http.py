"""HTTP for feeds."""

import urllib.request


class FetchError(Exception):
    pass


def download(url: str, timeout: float = 10) -> bytes:
    try:
        with urllib.request.urlopen(url, timeout=timeout) as response:
            return response.read()
    except OSError as exc:
        raise FetchError(f"{url}: {exc}") from exc
