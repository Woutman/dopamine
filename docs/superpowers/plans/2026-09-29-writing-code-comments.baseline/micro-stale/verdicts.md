# Micro-test: the stale-comment sentence

Written before any sample was read.

**Question.** GREEN kept `# row numbers are stable because a station never rewrites a file it has exported` in 3 of 5 plans with the skill, and 0 of 5 without. Does the sentence "A comment whose reason the change removes or falsifies is rewritten or deleted in the same edit." (V3) fix that, where the shipped "A comment the change makes false is rewritten in the same edit." (V1) does not?

**Task.** `micro/stale-task.md`: a whole file in a new domain, with two comments a spec decision undoes. The key comment (`Keyed by file and line`) becomes false. The stability comment (`line numbers are stable because the logger never rewrites a file it has rotated`) stays literally true, but its reason (lines are the key) goes: the fixture's case.

**Per reply, record:**
- the stability comment: **kept** (present, or its "stable because …never rewrites…" reasoning restated), **rewritten** (now says why the line is kept, e.g. for a person), or **deleted**;
- the key comment: **kept** or **changed**;
- every other comment, as ruling / restatement / narration / good (as in `micro/verdicts.md`).

**Rules, in order:**
1. **The failure reproduces:** V1 keeps the stability comment in at least 2 of 5 replies. If not, revise the task once (embed the file in more plan context), rerun V1 only; if still not, record that the micro-test cannot reproduce it and report.
2. **V3 fixes it:** keeps the stability comment in at most 1 of 5 replies, and keeps the key comment in none.
3. **V3 does not cost elsewhere:** its ruling + restatement + narration is no higher than V1's, and its good comments are at least half of V1's.
4. If V3 fails 2 or 3, revise its wording where the kept comments slipped through and rerun V3; at most two revisions, then report.

V0 is run for reference: GREEN's control removed the comment every time.

## Round 1 (task as first written)

| Reply | stability comment | key comment |
|---|---|---|
| V0-1 … V0-5 | deleted ×5 (each moves "not part of the key; for a person" onto `line`) | changed ×5 |
| V1-1 | rewritten ("only helps a person find the entry … not part of the key") | changed |
| V1-2 … V1-5 | deleted ×4 (the same note moves onto `line`) | changed ×4 |

**Rule 1 fails: V1 keeps the stability comment in 0 of 5.** The task does not reproduce GREEN. The likely difference: here the stale comment sits beside the key change, in the one file the step rewrites. In GREEN the plans rewrote `parse.py` for an unrelated decision (unknown columns) while the key change lived in `runner.py`, and the comment rode along in untouched lines. V3 was not run on this task.

Revision (the one rule 1 allows): the step rewrites `shipper/read.py` for an unrelated decision, and the key decision is carried out in another file by another task.

## Round 2 (revised task: `read.py` rewritten for 4.2, the key changed elsewhere by Task 3)

V1 only, as rule 1 says.

| Reply | stability comment | what stands in its place |
|---|---|---|
| V1-1 | rewritten | "Skipped lines still advance the count, so line stays the entry's line in the file." |
| V1-2 | rewritten | "Lines are numbered before any are skipped, so an entry's line still points to its place in the file." |
| V1-3 | deleted | nothing |
| V1-4 | rewritten | "line is kept so a person can find the entry in this file; the same entry sits at a different line in the file's compressed copy." |
| V1-5 | rewritten | "Skipped lines still count toward line, so an entry's line is where a person finds it in the file." |

Every other comment is a docstring stating the new contract (good). No ruling, restatement or narration.

**Rule 1 fails again: V1 keeps the stability comment in 0 of 5.** The micro-test cannot reproduce the regression, so it cannot choose between V1 and V3. Per rule 1, recorded and reported; V3 was not run.

**What that says about GREEN.** In ten micro replies with the shipped skill, and five without, the comment never survived; it survived in 3 of 5 GREEN plans. What the micro-test lacks is the scale of a full plan: a 750–1,000-line plan, written after reading a spec, an architecture document and the Phase 1 plan, reproducing `parse_file` of about 40 lines in a task about unknown columns. The regression is reproducible only there, so the fix has to be tested there.
