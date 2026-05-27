# Code review output contract

Defines output rules for each review session. Workflow lives in `SKILL.md`.

## Your job

1. **Pass 1:** Review diff vs base for correctness, security/authz + data handling, API/contracts, operational behavior, tests, and consistency with linked guides.
2. **Pass 2+:** Reconcile prior findings first (fixed / partial / not done / regressed). Do not re-report resolved findings unless the fix is wrong. Then scan only new/touched code.

## Severity labels

- **critical** - blocks merge: wrong behavior, security issue, broken contract, data loss risk
- **warning** - should be fixed before/soon after merge
- **nit** - optional polish

## Session file rules

Use `assets/template.md` as the base. Remove placeholders/instructions before saving.

### Title and meta

- H1 must be `# Code review - <branch>` (real branch).
- Pass must match session number (`01`, `02`, ...).

### Strip and tailor

- Remove sample finding blocks.
- Remove Tests/Out of scope if empty, or set to `- None.`
- Pass 01: no Prior pass/Reconciliation sections.

### Pass 02+ additions

Insert after Summary and before Findings:

```markdown
## Prior pass
- **Carried open:** ...
- **New this pass:** ...
- **Dropped / obsolete:** ...

## Reconciliation
For each open ID from previous file: fixed / partial / not done / worse.
```

### Finding shape

Use IDs `C1, W1, N1...` by severity.

```
### <ID> - short title

| Field    | Value                    |
|----------|--------------------------|
| Severity | critical / warning / nit |
| Location | `repo/path/to/file:LINE` |
| Posted   | ❌                       |

Brief explanation (2-4 sentences max).

**Paste:**
```
One-line summary.
*Risk:* ... (critical only)
*Suggestion:* ...
```
```

- `Location`: `repo/...` + exact line or `START-END`.
- `Posted`: `❌` default, `✅` once posted via `/pr-post`.

### GitHub comment shape (reference)

- **critical:** summary + `*Risk:*` + `*Suggestion:*`
- **warning:** summary, optional `*Why:*`, `*Suggestion:*`
- **nit:** summary, optional `*Suggestion:*`

## Concision

Keep findings short and actionable. Every finding includes location and suggested change unless purely informational.
