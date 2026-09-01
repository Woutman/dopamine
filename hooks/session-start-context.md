**Documentation discipline (add-on to superpowers)**

This project has living documents — listed in `.dopamine/config` — that describe the present. Superpowers' ledger already records what happened during execution; that record is the sweep's input, and it is the only journal you keep.

If you find yourself about to change a living document mid-execution, record it in the ledger instead and let the sweep place it.

When you do write to a living document, load `dopamine:writing-living-documents` first; for `CLAUDE.md`, load `dopamine:writing-claude-md`. Each holds the shape that document has to keep, and `dopamine:routing-documentation-updates` decides which document a fact belongs in at all.

At the end of any plan or ad-hoc unit of work, and before the workspace is cleaned up, invoke the `dopamine:finishing-work` skill.
