# Review checklist

## Pass 01

Review the combined diff (committed vs base + uncommitted). Focus on:

- **Correctness and logic errors** — wrong behavior, off-by-one, unhandled branches
- **Security / authz** — injection, missing authz checks, sensitive data exposure
- **API / contract breakage** — changed signatures, removed fields, broken callers
- **Operational behavior** — missing error handling, retry storms, unguarded limits
- **Tests** — missing tests for changed logic, tests that don't cover the happy path
- **Conventions** — inconsistencies with project style visible in the loaded docs

## Pass 02+

Reconcile prior findings against the current working tree first — mark each as fixed / partial / not done / regressed. Do not re-report resolved items unless the fix introduced a new problem. Then scan only new or touched code for additional issues.
