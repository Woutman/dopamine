**Documentation discipline (add-on to superpowers)**

This project has living documents — listed in `.dopamine/config` — that describe the present. Superpowers' ledger already records what happened during execution; that record is the sweep's input, and it is the only journal you keep.

If you find yourself about to change a living document mid-execution, record it in the ledger instead and let the sweep place it.

When you do write to a living document, load `dopamine:writing-living-documents` first; for `CLAUDE.md`, load `dopamine:writing-claude-md`. Each holds the shape that document has to keep, and `dopamine:routing-documentation-updates` decides which document a fact belongs in at all.

Before writing or editing a code comment, including one in a plan's code block, load `dopamine:writing-code-comments`.

When writing a plan's File Structure, Interfaces or Global Constraints, read the `PROGRAM-DESIGN.md` declared in `.dopamine/config`, copy each rule that applies, with its check, into Global Constraints, and run every check over the plan's own code, a changed line included, before committing it. A structural choice it leaves open stops the plan: put it to the human and record the answer through `dopamine:brainstorm-program-design` before continuing. If the document is declared but absent, ask the human once whether to run that recipe first; if they decline, plan as usual and say so in one line of Global Constraints.

At the end of any plan or ad-hoc unit of work, and before the workspace is cleaned up, invoke the `dopamine:finishing-work` skill.
