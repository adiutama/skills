# Format

**Default posture:** skeptical, curious, and ambitious.

## Severity

| Label | When |
|-------|------|
| **critical** | Blocks push: wrong behavior, security issue, broken contract, data-loss risk |
| **warning** | Must fix before push: edge-case bug, missing tests for changed behavior, meaningful consistency/maintainability issue |
| **nit** | Minor issue; still expected to be fixed unless explicitly deferred |

## Finding format

Number by severity: `C1, C2...` · `W1, W2...` · `N1, N2...`

    ### <ID> - short title

    | Field    | Value                                                                              |
    |----------|------------------------------------------------------------------------------------|
    | Severity | critical / warning / nit                                                           |
    | Tags     | 1-3 from taxonomy                                                                  |
    | Location | `path/to/file:LINE` or `path/to/file:START-END`                                   |
    | Lens     | correctness / security / contract / operations / cohesion / clarity / tests / docs |
    | Fixed    | ❌                                                                                 |

    Brief explanation (2-4 sentences max).
    Impact: one sentence at system level.

    **Suggestion:**

    One concrete action item.

Rules:
- Include exact location and explicit action.
- `Fixed` is `❌` by default; mark `✅` when addressed.
- Taxonomy is fixed: `code-smell`, `tech-debt`, `spaghetti-code`, `tight-coupling`, `leaky-abstraction`, `api-inconsistency`, `cohesion-gap`, `clarity-debt`, `test-debt`.

## Session file template

    # Review changes - <branch>

    ## Meta

    | Field               | Value                                                |
    |---------------------|------------------------------------------------------|
    | Pass                | `<NN>`                                               |
    | Date                | `<YYYY-MM-DD>`                                       |
    | Branch              | `<branch>`                                           |
    | Base                | `<base>`                                             |
    | Head SHA            | `<head_sha>`                                         |
    | Scope               | `<short note on changed areas/files>`                |
    | Context docs        | `<files used: format.md, checklist.md, ...>`         |
    | Stance              | `<Ready / Not ready>`                                |
    | Coverage confidence | `<High / Medium / Low>`                              |

    ## Summary

    `N critical · N warning · N nit` — **Stance:** <stance>
    - **Posture:** skeptical, curious, and ambitious.

    ## Scope coverage

    - **Primary scope reviewed:** `...`
    - **Adjacent scope reviewed:** `...`
    - **Out of scope:** `...` (or `None`)
    - **Lens coverage:** `path/to/file` -> correctness=high, security=high, contract=medium, operations=high, cohesion=medium, clarity=high, tests=medium, docs=n/a

    ## Coverage notes

    - Partial/shallow areas and why.
    - Confidence limits and missing context.
    - Exact next-run target if not fully covered.

    ## Findings

    ---

    ## Tests

    - Ran: ...
    - Gaps: ...

    ## Out of scope

    - ...

Rules:
- H1 must be `# Review changes - <branch>`.
- Pass value must match file number (`01`, `02`, ...).
- Keep only real findings (no placeholders).
- Remove empty sections or replace with `- None.`.
- Pass 01: omit Prior pass and Reconciliation.
- Pass 02+: include, after Coverage notes and before Findings:

      ## Prior pass

      - **Carried open:** ...
      - **Fixed this pass:** ...
      - **Dropped / obsolete:** ...

      ## Reconciliation

      For each open ID from previous session: fixed / partial / not done / worse / missed in prior pass (one line each).

## Output summary

Print after saving, then stop:

    Saved: ~/.agents/artifacts/<owner>/<repo>/<slug>/review-changes/<NN>.md
    N critical · N warning · N nit

    Stance: <Ready / Not ready> — <one-sentence reason>
    Coverage confidence: <High / Medium / Low>
    Reviewed scope: <short list>
    Unreviewed scope: <short list or None>
    Next suggested scope: <exact files/lenses for next run, or None>

    Findings:
      C1 — <title>  path/to/file:LINE
      W1 — <title>  path/to/file:LINE
      N1 — <title>  path/to/file:LINE

## Stance

| Stance | When |
|--------|------|
| Ready | `0 critical · 0 warning · 0 nit` |
| Not ready | Any finding exists |

Always include one sentence explaining the stance.
