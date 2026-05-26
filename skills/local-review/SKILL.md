---
name: local-review
description: Review local git changes before pushing. Catches problems early so the PR process is smoother. Saves a persistent session file under reviews/local/. Use when you want pre-push feedback on uncommitted or unpushed changes.
compatibility: Requires a git repository.
metadata:
  argument-hint: "[base-ref]"
allowed-tools: Bash(git:*) Read Write
---

Invoked as `/local-review [base-ref]`.

## Step 1 — Gather git state

`BASE` = first argument, defaulting to `main`.

Run in parallel:
- `git rev-parse --abbrev-ref HEAD` → `BRANCH`
- `git rev-parse HEAD` → `HEAD_SHA`
- `git diff <BASE>...HEAD` → committed diff vs base
- `git diff HEAD` → uncommitted changes (staged + unstaged)
- `git status --short` → file list

Combine both diffs into a single review surface. If `BRANCH` equals `BASE`, review only uncommitted changes.

If the combined diff is empty, report "Nothing to review — no changes vs `<BASE>` and no uncommitted modifications." and stop.

## Step 2 — Determine session path

Derive a slug from `BRANCH` by replacing `/` and non-alphanumeric characters with `-` (e.g. `feat/add-login` → `feat-add-login`).

Session dir: `reviews/local/<slug>/`

Pick the next pass number:
- No files exist → `01.md`
- `01.md` exists → `02.md`, and so on

Set `SESSION_PATH = reviews/local/<slug>/<NN>.md` and `PASS = NN`.

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
