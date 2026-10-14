"""Where a message goes."""

import os
from datetime import datetime
from email.message import EmailMessage
from pathlib import Path


def desktop(message: str) -> None:
    print(message)


def email(message: str) -> None:
    outbox = Path(os.environ.get("FEEDWATCH_HOME", ".feedwatch")) / "outbox"
    outbox.mkdir(parents=True, exist_ok=True)
    mail = EmailMessage()
    mail["Subject"] = "feedwatch"
    mail.set_content(message)
    (outbox / f"{datetime.now():%Y%m%d-%H%M%S-%f}.eml").write_bytes(bytes(mail))


CHANNELS = {"desktop": desktop, "email": email}
