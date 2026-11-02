def digest(summary):
    bands = summary["bands"]
    lines = [f"{name}: {count}" for name, count in sorted(bands.items())]
    lines.append(f"withheld: {summary['withheld']}")
    lines.append(f"unresolved: {summary['unresolved']}")
    return "\n".join(lines)
