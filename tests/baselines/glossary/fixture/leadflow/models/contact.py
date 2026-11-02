from dataclasses import dataclass


@dataclass
class Contact:
    email: str
    name: str = ""
    role: str = ""
