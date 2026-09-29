import unittest

from inventory import Item, apply_delivery, low_stock, parse_line, restock_order


def item(sku="A1", quantity=10, reorder_level=5, unit_price=1.0):
    return Item(sku, "widget", quantity, reorder_level, unit_price)


class InventoryTest(unittest.TestCase):
    def test_parse_line(self):
        self.assertEqual(parse_line("A1,widget,10,5,2.50\n"), Item("A1", "widget", 10, 5, 2.5))

    def test_low_stock_below_reorder_level(self):
        self.assertEqual(low_stock([item(quantity=3)]), [item(quantity=3)])

    def test_restock_order(self):
        self.assertEqual(restock_order([item(quantity=3)]), {"A1": 7})

    def test_apply_delivery_skips_unknown_sku(self):
        items = [item()]
        apply_delivery(items, {"A1": 5, "ZZ": 3})
        self.assertEqual(items[0].quantity, 15)


if __name__ == "__main__":
    unittest.main()
