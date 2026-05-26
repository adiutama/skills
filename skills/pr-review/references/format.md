# Format

## Severity

| Label | Merge? | Examples |
|-------|--------|---------|
| **critical** | Blocks | Wrong behavior, security issue, broken contract, data loss |
| **warning** | Fix before or shortly after | Edge-case bugs, missing tests for new logic, meaningful consistency problems |
| **nit** | Optional | Naming, small structure, non-blocking style |

## Finding format

Number by severity letter: `C1, C2…` · `W1, W2…` · `N1, N2…`

Session file block:

    ### <ID> — short title

    | Field    | Value                    |
    |----------|--------------------------|
    | Severity | critical / warning / nit |
    | Location | `repo/path/to/file:LINE` |
    | Posted   | ❌                       |

    Brief explanation (2–4 sentences max).

    **Paste:**

    ```
    One-line summary.
    *Risk:* ... (critical only)
    *Suggestion:* ...
    ```

- **Location:** `repo/...` prefix with exact line number or `START-END` range.
- **Posted:** one of three values:
  - `❌` — not yet posted; will be included by `/pr-post`
  - `✅` — posted via `/pr-post`
  - `✅ dup` — already raised in an existing PR comment; `/pr-post` skips it

GitHub inline comment:
- **critical:** one-line summary, `*Risk:*`, `*Suggestion:*`
- **warning:** one line, optional `*Why:*`, `*Suggestion:*`
- **nit:** one line, optional `*Suggestion:*`

## Session file template

    # Code review - <branch>

    ## Meta

    | Field        | Value                                                    |
    |--------------|----------------------------------------------------------|
    | Pass         | `<pass>`                                                 |
    | Date         | <YYYY-MM-DD>                                             |
    | PR           | #<number>                                                |
    | Branch       | `<branch>`                                               |
    | Base         | `<base>`                                                 |
    | Head SHA     | `<head_sha>`                                             |
    | Scope        | <short note on packages/areas under review>              |
    | Context docs | <files used: format.md, checklist.md, AGENTS.md, …>     |
    | Stance       | <Approve / Approve with notes / Request Changes>         |

    ## Summary

    `N critical · N warning · N nit` — **Stance:** <stance> — <one-sentence reason>

    _(N already raised by existing comments — skipped)_ ← omit this line if N is 0

    ## Findings

    ---

    ## Tests

    - Ran: …
    - Gaps: …

    ## Out of scope

    - …

**Rules:**
- H1 must be `# Code review - <branch>` (real branch name, no file paths).
- Pass cell must match `pass` from `init.sh`.
- Keep only real findings; no placeholder text.
- Remove Tests or Out of scope if empty, or replace with `- None.`
- `N critical · N warning · N nit` counts only findings with `Posted: ❌`. Findings marked `Posted: ✅ dup` are excluded from the count and from the stance calculation.
- **Pass 01:** omit Prior pass and Reconciliation sections.
- **Pass 02+:** insert after Summary, before Findings:

      ## Prior pass

      - **Carried open:** …
      - **New this pass:** …
      - **Dropped / obsolete:** …

      ## Reconciliation

      For each open finding ID from the previous session: fixed / partial / not done / regressed (one line each).

## Output summary

Print after saving, then stop:

    Saved: <session_path>
    N critical · N warning · N nit  (N already raised — skipped)  ← omit parenthetical if 0

    Stance: <Approve / Approve with notes / Request Changes> — <one-sentence reason>

    Findings:
      C1 — <title>  repo/path/to/file:LINE
      W1 — <title>  repo/path/to/file:LINE

    Already raised by existing comments (skipped):  ← omit section if none
      W2 — <title>  repo/path/to/file:LINE

## Stance

| Stance | When |
|--------|------|
| Approve | No findings, or nits that are purely cosmetic |
| Approve with notes | Warnings present, none blocking merge |
| Request Changes | Any critical, or a warning severe enough to block merge |

Always include a one-sentence reason explaining the stance, especially when it may not be obvious from the finding count alone (e.g. all warnings but still blocking, or criticals that are narrow in scope).
