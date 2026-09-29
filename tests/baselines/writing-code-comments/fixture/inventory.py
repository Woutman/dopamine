"""Stock tracking for a small warehouse."""

from dataclasses import dataclass


@dataclass
class Item:
    sku: str
    name: str
    quantity: int
    reorder_level: int
    unit_price: float


def parse_line(line):
    """Parse one line of the supplier's CSV export into an Item."""
    sku, name, quantity, reorder_level, unit_price = line.strip().split(",")
    return Item(sku, name, int(quantity), int(reorder_level), float(unit_price))


def load(path):
    """Read every item from a supplier export file."""
    with open(path, encoding="utf-8") as f:
        # The export always starts with a header row.
        next(f)
        return [parse_line(line) for line in f if line.strip()]


def by_sku(items):
    return {item.sku: item for item in items}


def low_stock(items):
    """Items that should be reordered."""
    return [item for item in items if item.quantity < item.reorder_level]


def restock_order(items, target_multiple=2):
    """Quantity to order per SKU so each low item reaches target_multiple times its reorder level."""
    return {
        item.sku: item.reorder_level * target_multiple - item.quantity
        for item in low_stock(items)
    }


def apply_delivery(items, delivery):
    """Add delivered quantities, keyed by SKU, to the matching items in place."""
    index = by_sku(items)
    for sku, quantity in delivery.items():
        # Deliveries can include SKUs we don't stock yet; those are skipped
        # until someone adds the item by hand.
        if sku in index:
            index[sku].quantity += quantity
