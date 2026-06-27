# Examples

## 1 — Objective exit

> Fix ESLint in `src/` until `npm run lint` is clean. No public API changes. Max 8.

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

## 5 — Cross-skill exit

> Loop until `/review-changes` clean and tests pass.

Each `done` → run review-changes + `npm test` before accepting.

## 6 — Stall

Same blocker iters 4–5 → `blocked`; user unsticks; `resume` later.

## 7 — Vague exit

> Iterate on auth until solid.

Do not start; ask for objective exit or human gate.
