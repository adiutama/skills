# Review checklist

## Critical-risk gate (run first)

Before Pass 01, do a blocker sweep:

- **Auth on every entrypoint** — every read/write/delete path to protected data must enforce authn/authz; no CRUD asymmetry
- **Tenant / org data scope** — queries and mutations must be scoped to the caller's tenant/org; no cross-tenant leakage path
- **Fail-closed behavior** — auth/client-init/dependency failures must not bypass checks or silently continue with unsafe defaults
- **Destructive action safety** — delete/disable/toggle actions must validate target identity and handle partial failure without corrupting state
- **Secret / sensitive data exposure** — no tokens, credentials, internal errors, or sensitive fields leaked to logs, responses, or UI

## Pass 01

Review diff vs base. Focus on:

- **Correctness and logic errors** — wrong behavior, off-by-one, unhandled branches
- **Security / authz** — injection, missing authz checks, sensitive data exposure
- **API / contract breakage** — changed signatures, removed fields, broken callers
- **Operational behavior** — missing error handling, retry storms, unguarded limits
- **Accessibility** — icon-only buttons must have `aria-label`; interactive controls must not be hover-only (keyboard/touch users need `group-focus-within` or always-visible visibility); form controls should have programmatic label associations
- **Auth consistency** — check that every operation touching protected data (reads AND mutations) enforces the same auth check; look for CRUD asymmetry where mutations are guarded but reads are not (or vice versa)
- **Typed error contracts** — functions that declare a typed return shape such as `{ success: boolean; error?: string }` must wrap their entire body in try/catch so callers always receive the declared shape; a throwing auth or client-init call must not escape
- **Input normalization** — user-provided strings used for deduplication, comparison, or storage should be trimmed and case-normalized consistently before use
- **Error vs empty state** — when a data-fetching hook can fail, verify the render path exposes an error state distinct from the empty/loading state; `data ?? []` on a failed query should not silently render as "no results"
- **Maintainability / code smells** — duplicate logic, overly large functions/components, deep nesting, dead code, and hidden coupling that can mask defects
- **Tests** — missing tests for changed logic, tests that don't cover the happy path
- **Conventions** — inconsistencies with project style visible in linked guides

## Pass 02+

Reconcile prior findings first: fixed / partial / not done / regressed.
Do not re-report resolved findings unless the fix introduces a new issue.
Then review only newly touched code.
