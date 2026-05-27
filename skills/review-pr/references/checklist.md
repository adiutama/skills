# Review checklist

## Pass 01

Review diff vs base for:

- Correctness
- Security/authz and data handling
- API/contracts
- Operational behavior (errors, retries, limits)
- Tests for changed behavior
- Consistency with linked guides

## Pass 02+

Reconcile prior findings first: fixed / partial / not done / regressed.
Do not re-report resolved findings unless the fix introduces a new issue.
Then review only newly touched code.
