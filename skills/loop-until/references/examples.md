# Examples

## 1 — Objective until

> /loop-until lint is clean in `src/` — no public API changes, max 8.

Init → confirm → loop → verify lint on each `done`.

## 2 — Human gate

> Improve README until I say ship it. One section per pass.

Mode `human-gate`; stop after each iteration.

## 3 — Resume (new chat)

Prior chat blocked at iter 3. User: `resume` → `resolve-resume.sh` → confirm **yes** → iter 4.

`resume eslint` matches slug when multiple sessions exist.

## 4 — Recon then fix

> Until auth tests pass — map auth first, then fix. Max 6.

Iter 0 `explore` recon → merge → iters 1–6 fixes.

## 5 — Composite verify

> Loop until workspace review session shows 0 unresolved findings and `npm test` exits 0.

Each `done` → read saved session artifact + run `npm test` before accepting.

## 6 — Stall

Same blocker iters 4–5 → `blocked`; user unsticks; `resume` later.

## 7 — Vague until

> /loop-until auth is solid.

Do not start; ask for concrete until-clause or human gate.

## 8 — PR feedback fetch-only exit

> Loop until PR #42 has zero pending review threads.

Exit verify: run fetch-only list command for that PR; parent checks JSON `total_count == 0` each iteration.

## 9 — Pre-commit blast radius

> Loop until latest blast-radius session verdict is `safe to commit`.

Verify by reading saved session under `.../scan-blast-radius/`; use `--quick` when user scoped to glue + direct rings only.
