"""Turn a field of a station export into a number in the unit the store keeps."""

# header -> (quantity, unit the column arrives in)
COLUMNS = {
    "temp_c": ("temperature", "C"),
    "temp_f": ("temperature", "F"),
    "pressure_hpa": ("pressure", "hPa"),
    "wind_ms": ("wind", "m/s"),
    "wind_kn": ("wind", "kn"),
}

KNOT = 0.514444  # m/s

# No station reports sea-level pressure above this; see parse_pressure.
PRESSURE_CEILING = 2000.0


def number(field, decimal):
    """The field as a float, or None when the station left it empty."""
    text = field.strip()
    if not text:
        return None
    if decimal == ",":
        text = text.replace(",", ".")
    return float(text)


def parse_pressure(value):
    # Halden loggers write pressure in tenths of a hectopascal and drop the
    # decimal mark, so 1013.2 hPa arrives as 10132. Real pressures never come
    # near the ceiling, so anything above it is one of those.
    if value > PRESSURE_CEILING:
        return value / 10
    return value


def convert(column, field, decimal):
    """(quantity, value in the store's unit) for one field, or None for an empty one.

    Raises KeyError for a column the store does not keep, ValueError for a field
    that is not a number.
    """
    quantity, unit = COLUMNS[column]
    value = number(field, decimal)
    if value is None:
        return None
    if unit == "F":
        value = (value - 32) * 5 / 9
    elif unit == "kn":
        value = value * KNOT
    elif quantity == "pressure":
        value = parse_pressure(value)
    return quantity, round(value, 2)
