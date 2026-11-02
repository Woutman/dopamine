from leadflow.util import chunk

assert chunk([1, 2, 3, 4, 5], 2) == [[1, 2], [3, 4], [5]]
assert chunk([1, 2, 3, 4], 2) == [[1, 2], [3, 4]]
assert chunk([], 3) == []
