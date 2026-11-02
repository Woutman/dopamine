from dataclasses import dataclass


@dataclass
class Company:
    name: str
    city: str
    sector: str
    kvk: str | None = None
