def funnel(counts):
    stages = ["scored", "shown", "contacted", "qualified"]
    return [(stage, counts.get(stage, 0)) for stage in stages]
