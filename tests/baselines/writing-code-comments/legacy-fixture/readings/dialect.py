"""Guess how a station's CSV export is written.

Stations are set up by whoever installed them, so the same columns arrive with a
comma or a semicolon between fields, and with a point or a comma as the decimal mark.
"""
import csv
from dataclasses import dataclass


@dataclass(frozen=True)
class Dialect:
    delimiter: str
    decimal: str


def sniff(text):
    """The dialect of an export, read from its header line.

    Raises ValueError when the header holds neither delimiter.
    """
    header = text.split("\n", 1)[0]
    # A semicolon file is a decimal-comma file: the comma is free to mark
    # decimals only because it is not separating fields.
    if header.count(";") > header.count(","):
        return Dialect(";", ",")
    if "," in header:
        return Dialect(",", ".")
    raise ValueError("header has no delimiter")


def rows(text, dialect):
    """The export's rows, header first, as lists of fields."""
    return list(csv.reader(text.splitlines(), delimiter=dialect.delimiter))
