---
name: local-review
description: Review local git changes before pushing. Catches problems early so the PR process is smoother. Saves a persistent session file under reviews/local/. Use when you want pre-push feedback on uncommitted or unpushed changes.
compatibility: Requires a git repository.
metadata:
  argument-hint: "[base-ref]"
allowed-tools: Bash(git:*) Read Write
---

You are invoked as `/local-review [base-ref]`.

## 1. Parse args and gather git state

`BASE` = first argument, defaulting to `main`.

Run in parallel:
- `git rev-parse --abbrev-ref HEAD` → `BRANCH`
- `git rev-parse HEAD` → `HEAD_SHA`
- `git diff <BASE>...HEAD` → committed diff vs base
- `git diff HEAD` → uncommitted changes (staged + unstaged combined)
- `git status --short` → file list summary

Combine the committed diff and uncommitted changes into a single review surface. If `BRANCH` equals `BASE`, review only uncommitted changes.

If the combined diff is empty, report "Nothing to review — no changes vs `<BASE>` and no uncommitted modifications." and stop.

## 2. Determine session file path

Derive a slug from `BRANCH` by replacing `/` and non-alphanumeric characters with `-` (e.g. `feat/add-login` → `feat-add-login`).

Session dir: `reviews/local/<slug>/`

Pick the next pass number:
- If no files exist: `01.md` (pass 01)
- If `01.md` exists: `02.md` (pass 02), and so on

Set `SESSION_PATH = reviews/local/<slug>/<NN>.md` and `PASS = NN`.

## 3. Load context files

Read in full:
- `references/output-contract.md` — severity labels, finding shape, stance rules
- `assets/template.md` — session file skeleton

For pass 02+, also read the previous session file (`<NN-1>.md`) to reconcile prior findings.

## 4. Locate the repo root and load relevant docs

Find the codebase root by checking in this order — stop at the first match:

1. **Workspace root** — does a `.git` directory exist here?
2. **Immediate children** — does any direct subdirectory contain a `.git`?
3. **Sibling directories** — does any directory next to the workspace contain a `.git`?
4. **Parent directory** — does the parent contain a `.git`? (last resort)

Once found, read whichever of these exist at that root:
- `AGENTS.md` or `CLAUDE.md` — project overview and conventions
- `README.md` — if neither is present
- Any guide files under `docs/` that match areas touched by the diff (e.g. backend guide if Python files changed, frontend guide if JS/TS changed)

Skip silently if a file does not exist. Do not error if none are found — the diff alone is sufficient.

## 5. Write the review

Follow `assets/template.md` as the skeleton and all rules in `references/output-contract.md`. Key rules:

- **H1:** `# Local review - <branch>` (real branch name only)
- **Pass:** set to `NN` in the Meta table
- **Severity:** use exactly `critical`, `warning`, or `nit`
- **Finding IDs:** `C1, C2...` for critical · `W1, W2...` for warning · `N1, N2...` for nit
- **Location:** `path/to/file:LINE` with exact line number (no repo prefix needed for local)
- **Fixed:** `❌` for every finding initially
- **Pass 01:** no Prior pass or Reconciliation sections
- **Pass 02+:** add Prior pass summary and Reconciliation before Findings
- Remove unused template placeholders and empty sections

Focus areas — catch what would draw PR review comments:
1. **Correctness and logic errors** — wrong behavior, off-by-one, unhandled branches
2. **Security / authz** — injection, missing authz checks, sensitive data exposure
3. **API / contract breakage** — changed signatures, removed fields, broken callers
4. **Operational behavior** — missing error handling, retry storms, unguarded limits
5. **Tests** — missing tests for changed logic, tests that don't cover the happy path
6. **Conventions** — inconsistencies with project style visible in the loaded docs

Each finding shape:
```
### <ID> - short title

| Field    | Value                          |
|----------|--------------------------------|
| Severity | critical / warning / nit       |
| Location | `path/to/file:LINE`            |
| Fixed    | ❌                             |

Brief explanation (2-4 sentences max).

**Suggestion:**

One-line action item. Keep it concrete.
```

For pass 02+, before Findings insert:

```markdown
## Prior pass

- **Carried open:** ...
- **Fixed this pass:** ...
- **Dropped / obsolete:** ...

## Reconciliation

For each open ID from the previous file: fixed / partial / not done / worse (one line each).
```

Save the completed session file to `SESSION_PATH`.

## 6. Show summary

After saving, output:

```
Saved: reviews/local/<slug>/<NN>.md
N critical · N warning · N nit

Stance: <Ready / Ready with notes / Not ready>

Findings:
  C1 - <title>  path/to/file:LINE
  W1 - <title>  path/to/file:LINE
  N1 - <title>  path/to/file:LINE
```

**Stance rules:**
- `Ready` — no findings, or only nits that are truly cosmetic
- `Ready with notes` — warnings worth fixing before push, but nothing blocking
- `Not ready` — any critical finding, or a warning severe enough to fix before pushing

Store the stance in the session file Meta table as `Stance`.

Then stop. To fix findings, address them in your working tree and run `/local-review` again for a reconciliation pass.
