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

## 5 — Cross-skill exit

> Loop until `/review-workspace` clean and tests pass.

Each `done` → run review-workspace + `npm test` before accepting.

## 6 — Stall

Same blocker iters 4–5 → `blocked`; user unsticks; `resume` later.

## 7 — Vague until

> /loop-until auth is solid.

Do not start; ask for concrete until-clause or human gate.

## 8 — PR feedback (prefer built-in workflow)

> /address-pr-feedback 42

Built-in: fetch → triage IDs → address → refresh until clear. Session at `.../address-pr-feedback/pr-42/`.

For `/loop-until` instead: exit `/address-pr-feedback 42 --fetch-only` empty; parent triages each iteration.

## 9 — Pre-commit blast radius

> /check-blast-radius feature --quick

Before `/commit-changes`: glue + direct rings only. Full pass omits `--quick`.
