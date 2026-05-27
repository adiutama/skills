---
name: review-changes
description: Review local git changes before pushing. Catches problems early so the PR process is smoother. Saves a persistent session file under reviews/review-changes/. Use when you want pre-push feedback on uncommitted or unpushed changes across standard and virtual-branch workflows.
compatibility: Requires a git repository.
metadata:
  argument-hint: "[target-branch-or-commit-sha] (optional; defaults to HEAD)"
allowed-tools: Bash(git:* bash:*) Read Write
---

Invoked as `/review-changes [target-branch-or-commit-sha]`.

## Step 1 — Gather git state

`TARGET` = first argument (optional). Branch or commit SHA; defaults to `HEAD`.

Run once:
- `bash <SKILL_DIR>/scripts/resolve-range.sh "<TARGET>"` → key/value output with:
  - `BRANCH`
  - `HEAD_SHA`
  - `TARGET_SHA`
  - `PR_BASE`
  - `RANGE_BASE`
  - `COMMITTED_RANGE`
  - `INCLUDE_UNCOMMITTED` (`1` or `0`)

If the script exits non-zero, stop and surface its error as-is.

Use `COMMITTED_RANGE` as committed review scope ("parent + 1 to target commit").

Then run in parallel:
- `git diff <COMMITTED_RANGE>` → committed diff surface
- `git status --short` → file list

Also run `git diff HEAD` and include uncommitted changes only when `INCLUDE_UNCOMMITTED=1`.

Combine both diffs into a single review surface (committed + uncommitted).

If the combined diff is empty, report "Nothing to review — no relevant changes in `<COMMITTED_RANGE>` and no uncommitted modifications." and stop.

## Step 2 — Determine session path

Derive a slug from `BRANCH` by replacing `/` and non-alphanumeric characters with `-` (e.g. `feat/add-login` → `feat-add-login`; detached HEAD becomes `detached-<sha>`).

Session dir: `reviews/review-changes/<slug>/`

Pick the next pass number:
- No files exist → `01.md`
- `01.md` exists → `02.md`, and so on

Set `SESSION_PATH = reviews/review-changes/<slug>/<NN>.md` and `PASS = NN`.

## Step 3 — Load context (in parallel)

- `<SKILL_DIR>/references/checklist.md`
- `<SKILL_DIR>/references/format.md`
- Pass 02+: previous session file (`<NN-1>.md` beside `SESSION_PATH`)
- Repo root: `AGENTS.md` or `CLAUDE.md`; `README.md` only if neither exists
- Docs under `docs/` matching areas touched by the diff

To find the repo root, check in order: `.git` in workspace → `.git` in any immediate child → `.git` in any sibling directory → `.git` in parent. Stop at first match. Skip silently if no docs are found.

## Step 4 — Write the review

Follow `checklist.md` for what to examine and `format.md` for the session file template, finding format, and rules. Save to `SESSION_PATH`.

## Step 5 — Print summary

Follow `format.md` output summary format, then stop.
