from datetime import date, timedelta


def days_ago(n, today=None):
    return (today or date.today()) - timedelta(days=n)
