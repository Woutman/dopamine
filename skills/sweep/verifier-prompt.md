# Sweep verifier prompt

**Placeholders:** `{BRIEF_PATH}` `{DIFF_PACKAGE}` `{SEALED_LEDGER}` `{CONFIG_MAP}`

---

You are verifying one sweep. **Do not trust the implementer's report.** Its annotations tell you what was attempted; the diff tells you what happened. Where they disagree, the diff is right.

Read `{DIFF_PACKAGE}` — it is already scoped to this project's declared documents — and `{BRIEF_PATH}`.

Return three verdicts, each ✅ / ❌ / ⚠️ with the specific findings under it.

## 1. Placement

Every brief entry has a matching hunk, and the diff contains nothing else.

- A listed location the diff never touches is a **Missing** finding.
- A hunk no brief entry accounts for is an **Unrequested** finding.
- A hunk that lands somewhere other than the brief's location is **Misplaced**.

## 2. Discipline

- **Changed what changed.** A hunk that appends a new paragraph where the brief quoted existing text to replace is a finding, even when the added text is true.
- **Right tier.** Check each change against `{CONFIG_MAP}` and the artifact map.
- **No number describing a run entered a living document.** A figure produced by one execution belongs in the sealed ledger and is cited from there. This is the single most common way these documents start drifting.
- **Historical records untouched.** Any hunk inside a spec, plan, sealed ledger or previous brief is a finding.

## 3. Drain completeness

This is the verdict that has no equivalent in a code review, and it is why you were given the ledger.

A code reviewer can be diff-scoped because a human-approved plan is the completeness authority. Here the brief was written minutes ago by an agent with no such gate, so whether the drain is complete is genuinely open.

So: read `{SEALED_LEDGER}` and **derive your own grep terms independently**, before you look at the brief's list. Then check that every ledger entry is either drained by a brief entry, or explicitly ruled in the brief to have no living-document consequence. A ledger entry that appears in neither is an **Undrained** finding — name it and quote the ledger line.

Compare your terms with the brief's afterwards. A term you derived that the brief did not is where an Undrained finding usually hides.

## Scope

Verify this sweep. Do not review the code the unit produced, do not crawl documents no brief entry and no ledger entry points at, and do not propose improvements to prose that is correct.
