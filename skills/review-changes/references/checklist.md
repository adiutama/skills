# Review checklist

## Review standard

Apply a strict pre-push standard:

- **Default posture:** skeptical, curious, and ambitious.
- Any finding means **Not ready**.
- Severity sets fix order only (`critical` first), not push eligibility.
- Use `nit` sparingly; if reported, fix before push unless explicitly deferred.
- Be ambitious: do not stop at surface checks; hunt hidden coupling and second-order risks.

## Determinism and coverage contract

- Lock scope before analysis and keep it stable during the pass.
- Deterministic order: files lexicographic, lenses fixed order below.
- Review by `file x lens` matrix; never skip silently.
- Mark non-applicable lens as `n/a`.
- If full coverage is not possible, list unreviewed scope with reason and next-run target.
- If a later pass finds an issue inside previously covered scope, reconcile as `missed in prior pass`.

## Scope declaration (before findings)

Define and sort these sets:

- **Primary scope:** files in combined diff.
- **Adjacent scope:** direct callers/callees and shared contracts/types/schemas/config/docs affected by changes.
- **Out of scope:** intentionally excluded areas.

## Review lenses and matrix

Use this order:

1. Correctness and logic
2. Security and authz
3. Contracts and API compatibility
4. Operational behavior
5. System cohesion
6. Beauty and clarity
7. Tests and verification
8. Conventions and docs alignment

For each in-scope file, apply every lens (or `n/a`) and record confidence (`high`, `medium`, `low`).

## Critical-risk gate (run first)

Before Pass 01, sweep for blockers. Any failure is `critical`:

- **Auth on every entrypoint** — no CRUD auth asymmetry.
- **Tenant/org data scope** — no cross-tenant leakage.
- **Fail-closed behavior** — failures cannot bypass safeguards.
- **Destructive action safety** — verify targets and handle partial failure safely.
- **Sensitive data exposure** — no secrets/internal sensitive fields leaked.

## Pass 01

Review combined diff (committed vs base + optional uncommitted), then adjacent scope.

Focus on:

- Correctness and branch handling
- Security/authz and sensitive data handling
- API/contract compatibility
- Operational safety (errors, retries, limits)
- Accessibility
- Auth consistency across reads and mutations
- Typed error contracts (declared return shape must not leak throws)
- Input normalization
- Error vs empty-state rendering
- Maintainability/code smells (duplication, deep nesting, dead code, hidden coupling, leaky abstractions, spaghetti-code flow)
- System cohesion (domain language, boundaries, invariants)
- Beauty and clarity (naming, control flow simplicity, composability)
- Tests for changed behavior
- Conventions from loaded docs

## Pass 02+

Reconcile prior findings first: `fixed / partial / not done / regressed / missed in prior pass`.

Do not re-report resolved items unless the fix introduces a new issue. Then scan only new/touched code.
