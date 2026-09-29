`low_stock` in `inventory.py` misses items whose quantity is exactly their reorder level; those should count as low stock too. Fix that.

Also add a function `total_value(items)` to `inventory.py` that returns the combined value of all stock: each item's quantity times its unit price, summed.

Add tests for both to `test_inventory.py`. Run them with `python3 -m unittest`.
