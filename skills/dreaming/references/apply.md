# Revert, correct, apply

Input: a run id (`2026-11-05`, `deep-2026-11-08`) and what to do with its proposals (`<data>/logs/<RUN>.json`). Every write goes through the journal, so each step is safe to repeat. Recover the journal first (SKILL.md rules). Save the JSON (`.tmp` + `mv`) after each proposal.

- **Revert** ("revert dream <RUN> #n"): **run script** `memory.py undo --op <proposal's op> --reason "<user's reason or 'reverted by the user'>"`. An add is forgotten, an update restored to the memory as it was, a forget re-added (new id). Mark the proposal `reverted`. A proposal with no `op` (logged before the journal existed): write the inverse yourself with `memory.py write --op <RUN>:<n>:revert:<name>`: add → forget; update → update back to the previous version (**memory read** history); forget → add from the log's full text.
- **Correct** ("#n is wrong because …"): decide the fix from the reason. Should never have existed → revert as above. Partly wrong → **update** the memory: **run script** `memory.py write --op <RUN>:<n>:fix:<name> [--project <id>] -- update …` (a second fix of the same proposal: `fix2`, …). Mark it `corrected` with the new version.
- **Apply** (`propose` mode: "apply dream <RUN>, accept 1,3; reject 2 (too specific)", or "accept all"): run accepted proposals as in [nightly.md](nightly.md) §7 steps 2–3; mark rejected ones `rejected`.

For every revert, correction and rejection, append to `<data>/logs/<RUN>-rejected.md`, if not already there: `- #<n> <name>: <summary> — <reverted | corrected | rejected>: <user's reason or "none given">`. Every future run reads these and doesn't repeat the mistake.

Never pin, never edit a pinned memory, never store secrets.

Reply with one line per proposal touched: number, name, outcome, memory id.
