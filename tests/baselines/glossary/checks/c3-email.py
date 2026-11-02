from leadflow.util import chunk, normalise_email

assert normalise_email("  Jan@Example.NL \n") == "jan@example.nl"
assert chunk([1, 2], 2) == [[1, 2]]
