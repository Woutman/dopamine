import importlib
import pkgutil
import unittest

import leadflow


class Imports(unittest.TestCase):
    def test_every_module_imports(self):
        for module in pkgutil.walk_packages(leadflow.__path__, "leadflow."):
            importlib.import_module(module.name)
