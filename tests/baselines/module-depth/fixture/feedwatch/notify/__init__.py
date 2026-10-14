"""Telling the user about entries, on a channel they choose."""

from feedwatch.notify.channels import CHANNELS
from feedwatch.notify.formats import FORMATS
from feedwatch.types import Entry

__all__ = ["CHANNELS", "FORMATS", "send"]


def send(entries: list[Entry], *, channel: str, fmt: str) -> None:
    CHANNELS[channel](FORMATS[fmt](entries))
