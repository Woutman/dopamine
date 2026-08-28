**Documentation discipline (add-on to superpowers)**

This project has living documents — listed in `.dopamine/config` — that describe the present. **They change at one moment only: the sweep.** Superpowers' ledger already records what happened during execution; that record is the sweep's input, and it is the only journal you keep.

If you find yourself about to change a living document mid-execution, record it in the ledger instead and let the sweep place it.

At the end of any plan or ad-hoc unit of work, and before the workspace is cleaned up, invoke the `dopamine:sweep` skill.
