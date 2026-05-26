# Review checklist

## Pass 01

Review the diff vs base. Focus on:

- Correctness
- Security/authz and data handling
- API/contracts
- Operational behavior (errors, retries, limits)
- Tests for changed behavior
- Consistency with linked guides

## Pass 02+

Reconcile prior findings first — mark each as fixed / partial / not done / regressed.
Do not re-report resolved items unless the fix introduced a new problem.
Then scan only new or touched code for additional issues.
