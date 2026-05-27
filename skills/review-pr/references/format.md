# Format

## Severity

| Label | Merge impact | Examples |
|---|---|---|
| **critical** | Blocks | Wrong behavior, security issue, broken contract, data loss |
| **warning** | Fix before/soon after merge | Edge-case bugs, missing tests, meaningful consistency issues |
| **nit** | Optional | Naming, minor structure, non-blocking style |

## Finding format

IDs by severity: `C1, C2...` · `W1, W2...` · `N1, N2...`

Session block:

    ### <ID> — short title

    | Field    | Value                    |
    |----------|--------------------------|
    | Severity | critical / warning / nit |
    | Location | `repo/path/to/file:LINE` |
    | Posted   | ❌                       |

    Brief explanation (2-4 sentences).

    **Paste:**

    ```
    One-line summary.
    *Risk:* ... (critical only)
    *Suggestion:* ...
    ```

- `Location` must use `repo/...` plus exact line or `START-END`.
- `Posted` values:
  - `❌` not posted
  - `✅` posted via `/pr-post`
  - `✅ dup` already present in existing PR comments; `/pr-post` skips it

GitHub inline comment shape:
- **critical:** one-line summary, `*Risk:*`, `*Suggestion:*`
- **warning:** one line, optional `*Why:*`, `*Suggestion:*`
- **nit:** one line, optional `*Suggestion:*`

## Session file template

    # Code review - <branch>

    ## Meta

    | Field        | Value                                                |
    |--------------|------------------------------------------------------|
    | Pass         | `<pass>`                                             |
    | Date         | <YYYY-MM-DD>                                         |
    | PR           | #<number>                                            |
    | Branch       | `<branch>`                                           |
    | Base         | `<base>`                                             |
    | Head SHA     | `<head_sha>`                                         |
    | Scope        | <short note on packages/areas>                       |
    | Context docs | <files used: format.md, checklist.md, AGENTS.md, ...> |
    | Stance       | <Approve / Approve with notes / Request Changes>     |

    ## Summary

    `N critical · N warning · N nit` — **Stance:** <stance> — <one-sentence reason>

    _(N already raised by existing comments — skipped)_   ← omit if 0

    ## Findings

    ---

    ## Tests

    - Ran: …
    - Gaps: …

    ## Out of scope

    - …

**Rules:**
- H1 must be `# Code review - <branch>` (real branch name).
- Pass cell must match `pass` from init output.
- Keep only real findings; remove placeholders.
- Remove empty Tests/Out of scope, or use `- None.`
- Counts and stance include only findings with `Posted: ❌` (exclude `✅ dup`).
- Pass 01: do not include Prior pass/Reconciliation.
- Pass 02+: insert before Findings:

      ## Prior pass
      - **Carried open:** …
      - **New this pass:** …
      - **Dropped / obsolete:** …
      ## Reconciliation
      For each open ID from prior pass: fixed / partial / not done / regressed.

## Output summary

Print after saving:

    Saved: <session_path>
    N critical · N warning · N nit  (N already raised — skipped)  ← omit parenthetical if 0

    Stance: <Approve / Approve with notes / Request Changes> — <one-sentence reason>

    Findings:
      C1 — <title>  repo/path/to/file:LINE
      W1 — <title>  repo/path/to/file:LINE

    Already raised by existing comments (skipped):
      W2 — <title>  repo/path/to/file:LINE

Omit optional lines/sections when empty.

## Stance

| Stance | Use when |
|---|---|
| Approve | No findings, or cosmetic nits only |
| Approve with notes | Warnings present but not blocking |
| Request Changes | Any critical, or blocking warning |

Always include one-sentence stance rationale.
