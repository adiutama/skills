---
name: pr-review
description: Review a GitHub PR and save a persistent session file under reviews/. Use when reviewing a pull request, evaluating code changes, or checking a PR before merging. Does not post anything - use /pr-post to publish findings.
compatibility: Requires gh CLI authenticated to GitHub.
metadata:
  argument-hint: "<pr-url or pr-number>"
allowed-tools: Bash(gh:*) Read Write
---

You are invoked as `/pr-review <pr-url or pr-number>`.

## 1. Parse the PR identity

Accept any of these forms:
- Full URL: `https://github.com/owner/repo/pull/123`
- Short number with implicit repo: `123` (default repo: `SystemEarth/systemearth`)

Extract `OWNER`, `REPO`, and `PR_NUMBER`. If the argument is missing or unparseable, ask once: "Please provide a PR URL or number." and stop.

## 2. Fetch PR metadata and diff

Run in parallel:
- `gh pr view <PR_NUMBER> --repo <OWNER>/<REPO> --json title,headRefName,headRefOid,baseRefName,body`
- `gh pr diff <PR_NUMBER> --repo <OWNER>/<REPO>`

From the view output extract:
- `BRANCH` - the head branch name (e.g. `feat/fix-deactivate`)
- `HEAD_SHA` - the head commit OID
- `BASE` - the base branch (usually `main`)

If the diff is too large, save it to a temp file and read it in chunks.

## 3. Determine session file path

Derive a slug from `BRANCH` by replacing `/` and non-alphanumeric characters with `-` (e.g. `feat/fix-deactivate` becomes `feat-fix-deactivate`).

Session dir: `reviews/branches/<slug>/`

Pick the next pass number:
- If no files exist: `01.md` (pass 01)
- If `01.md` exists: `02.md` (pass 02), and so on

Set `SESSION_PATH = reviews/branches/<slug>/<NN>.md` and `PASS = NN`.

## 4. Load context files

Read in full:
- `references/output-contract.md` - severity labels, output shape, GitHub paste format
- `assets/template.md` - session file skeleton

For pass 02+, also read the previous session file (`<NN-1>.md`) to reconcile prior findings.

## 5. Locate the repo and load relevant docs

The skill already knows `REPO` (the GitHub repository name) from step 1. Use it as a hint when multiple candidates exist.

Find the codebase root by checking in this order — stop at the first match:

1. **Workspace root** - does a `.git` directory exist here?
2. **Immediate children** - does any direct subdirectory contain a `.git`? Prefer one whose name matches `REPO`.
3. **Sibling directories** - does any directory next to the workspace contain a `.git`? Prefer one whose name matches `REPO`.
4. **Parent directory** - does the parent contain a `.git`? (last resort)

Once found, read whichever of these exist at that root:
- `AGENTS.md` or `CLAUDE.md` - project overview and conventions
- `README.md` - if neither is present
- Any guide files under `docs/` that match areas touched by the diff (e.g. backend guide if Python files changed, frontend guide if JS/TS changed)

Skip silently if a file does not exist. Do not error if none are found — the diff alone is sufficient.

## 6. Write the review

Follow `assets/template.md` as the skeleton and all rules in `references/output-contract.md`. Key rules:

- **H1:** `# Code review - <branch>` (real branch name only, no file paths)
- **Pass:** set to `NN` in the Meta table
- **Severity:** use exactly `critical`, `warning`, or `nit`
- **Finding IDs:** `C1, C2...` for critical · `W1, W2...` for warning · `N1, N2...` for nit
- **Location:** `repo/path/to/file:LINE` with exact line number
- **Posted:** `❌` for every finding initially
- **Pass 01:** no Prior pass or Reconciliation sections
- **Pass 02+:** add Prior pass summary and Reconciliation before Findings
- Remove unused template placeholders and empty sections

Each finding shape:
```
### <ID> - short title

| Field    | Value                          |
|----------|--------------------------------|
| Severity | critical / warning / nit       |
| Location | `repo/path/to/file:LINE`       |
| Posted   | ❌                             |

Brief explanation (2-4 sentences max).

**Paste:**

\```
One-line summary.
*Risk:* ... (critical only)
*Suggestion:* ...
\```
```

Save the completed session file to `SESSION_PATH`.

## 7. Show summary

After saving, output:

```
Saved: reviews/branches/<slug>/<NN>.md
N critical · N warning · N nit

Stance: <Approve / Approve with notes / Request Changes>

Findings:
  C1 - <title>  repo/path/to/file:LINE
  W1 - <title>  repo/path/to/file:LINE
  N1 - <title>  repo/path/to/file:LINE
```

**Stance rules:**
- `Approve` - no findings, or only nits that are truly cosmetic
- `Approve with notes` - warnings or nits worth sharing but none that must be fixed before merge
- `Request Changes` - any critical finding, or a warning severe enough to warrant a fix before merge

Store the stance in the session file Meta table as `Stance`.

Then stop. To publish findings to GitHub, run `/pr-post`.
