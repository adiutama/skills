# Code review output contract

This file defines the output rules for every review session. The workflow is in `SKILL.md`; this file covers what findings look like and how to write them.

## Your job

1. **Pass 1:** Review the diff vs base. Focus on: correctness, security/authz and data handling, API/contracts, operational behavior (errors, retries, limits), tests for changed behavior, consistency with linked guides.
2. **Pass 2+:** First reconcile prior findings against the current diff. Mark each as fixed, partial, not done, or regressed. Do not re-report resolved items unless the fix is wrong. Then scan only new or touched code for additional issues.

## Severity labels

Use exactly these three. Put the label first in every finding.

- **critical** - blocks merge: wrong behavior, security issue, broken contract, data loss risk
- **warning** - should fix before or shortly after merge: edge-case bugs, missing tests for new logic, meaningful consistency or maintainability problems
- **nit** - optional polish: naming, small structure, non-blocking style

## Session file rules

Follow the skeleton in `assets/template.md`. Do not leave instructional or placeholder-only content in the saved file.

### Title and meta

- H1 is `# Code review - <branch>` only (real git branch name). Do not put file paths in the title.
- Set the Pass meta cell to match the session file number (`01`, `02`, ...).

### Strip and tailor

- Remove the sample W1 finding from `template.md` when saving. Keep only real findings.
- Remove Tests or Out of scope sections if there is nothing meaningful, or use a single `- None.` line.
- Pass 01: do not include Prior pass or Reconciliation sections.

### Pass 02+ additions

After Summary, before Findings, insert:

```markdown
## Prior pass

- **Carried open:** ...
- **New this pass:** ...
- **Dropped / obsolete:** ...

## Reconciliation

For each open ID from the previous file: fixed / partial / not done / worse (one line each).
```

### Finding shape

Number findings C1, W1, N1, ... (letter = severity). Each finding:

```
### <ID> - short title

| Field    | Value                    |
|----------|--------------------------|
| Severity | critical / warning / nit |
| Location | `repo/path/to/file:LINE` |
| Posted   | ❌                       |

Brief explanation (2-4 sentences max).

**Paste:**

\```
One-line summary.
*Risk:* ... (critical only)
*Suggestion:* ...
\```
```

Location uses `repo/...` prefix with an exact line number or `START-END` range.
Posted is `❌` by default, `✅` once posted via `/pr-post`.

### GitHub comment shape (reference only)

**critical:** one-line summary, `*Risk:*`, `*Suggestion:*`
**warning:** one line, optional `*Why:*`, `*Suggestion:*`
**nit:** one line, optional `*Suggestion:*`

## Concision

Prefer short sentences. Every finding must include where (path + exact line number or range) and what to change, unless it is purely informational.
