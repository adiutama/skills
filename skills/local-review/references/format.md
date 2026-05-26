# Format

## Severity

| Label | When |
|-------|------|
| **critical** | Blocks push: wrong behavior, security issue, broken contract, data loss risk |
| **warning** | Should fix before pushing: edge-case bugs, missing tests for new logic, meaningful consistency or maintainability problems |
| **nit** | Optional polish: naming, small structure, non-blocking style |

## Finding format

Number by severity letter: `C1, C2…` · `W1, W2…` · `N1, N2…`

    ### <ID> — short title

    | Field    | Value                    |
    |----------|--------------------------|
    | Severity | critical / warning / nit |
    | Location | `path/to/file:LINE`      |
    | Fixed    | ❌                       |

    Brief explanation (2–4 sentences max).

    **Suggestion:**

    One concrete action item.

- **Location:** exact line number or `START-END` range. No repo prefix needed — local paths are sufficient.
- **Fixed:** `❌` by default. Mark `✅` once addressed; the next pass reconciles automatically.
- Every finding must include where (path + exact line) and what to change.

## Session file template

    # Local review - <branch>

    ## Meta

    | Field        | Value                                                    |
    |--------------|----------------------------------------------------------|
    | Pass         | `<NN>`                                                   |
    | Date         | <YYYY-MM-DD>                                             |
    | Branch       | `<branch>`                                               |
    | Base         | `<base>`                                                 |
    | Head SHA     | `<head_sha>`                                             |
    | Scope        | <short note on areas/files changed>                      |
    | Context docs | <files used: format.md, checklist.md, AGENTS.md, …>     |
    | Stance       | <Ready / Ready with notes / Not ready>                   |

    ## Summary

    `N critical · N warning · N nit` — **Stance:** <stance>

    ## Findings

    ---

    ## Tests

    - Ran: …
    - Gaps: …

    ## Out of scope

    - …

**Rules:**
- H1 must be `# Local review - <branch>` (real branch name, no file paths).
- Pass cell must match the session file number (`01`, `02`, …).
- Keep only real findings; no placeholder text.
- Remove Tests or Out of scope if empty, or replace with `- None.`
- **Pass 01:** omit Prior pass and Reconciliation sections.
- **Pass 02+:** insert after Summary, before Findings:

      ## Prior pass

      - **Carried open:** …
      - **Fixed this pass:** …
      - **Dropped / obsolete:** …

      ## Reconciliation

      For each open finding ID from the previous session: fixed / partial / not done / worse (one line each).

## Output summary

Print after saving, then stop:

    Saved: reviews/local/<slug>/<NN>.md
    N critical · N warning · N nit

    Stance: <Ready / Ready with notes / Not ready> — <one-sentence reason>

    Findings:
      C1 — <title>  path/to/file:LINE
      W1 — <title>  path/to/file:LINE
      N1 — <title>  path/to/file:LINE

## Stance

| Stance | When |
|--------|------|
| Ready | No findings, or only nits that are truly cosmetic |
| Ready with notes | Warnings present, none blocking push |
| Not ready | Any critical, or a warning severe enough to block push |

Always include a one-sentence reason explaining the stance, especially when it may not be obvious from the finding count alone.
