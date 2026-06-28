---
name: review-changes
description: Review local git changes before pushing. Catches problems early so the PR process is smoother. Saves a persistent session under .agents/artifacts/.../review-changes/ when gitignored, else ~/.agents/artifacts/ (see `<SKILL_DIR>/scripts/artifacts.sh` allocate).
disable-model-invocation: true
compatibility: Requires a git repository.
metadata:
  argument-hint: "[target-branch-or-commit-sha] (optional; defaults to HEAD)"
allowed-tools: Bash(git:* bash:*) Read Write
---

Invoked as `/review-changes [target-branch-or-commit-sha]`.
## Step 1 - Gather git state
`TARGET` = arg 1 (optional), default `HEAD`.
Run once: `bash <SKILL_DIR>/scripts/resolve-range.sh "<TARGET>"`.
Expected keys: `BRANCH`, `HEAD_SHA`, `TARGET_SHA`, `PR_BASE`, `RANGE_BASE`, `COMMITTED_RANGE`, `INCLUDE_UNCOMMITTED`.
If non-zero exit, stop and return error as-is.
Use `COMMITTED_RANGE` as committed scope (`parent+1..target`).
Run in parallel:
- `git diff <COMMITTED_RANGE>`
- `git status --short`
If `INCLUDE_UNCOMMITTED=1`, also run `git diff HEAD`.
Review surface = committed diff + optional uncommitted diff. If empty, print:
`Nothing to review — no relevant changes in <COMMITTED_RANGE> and no uncommitted modifications.`
Then stop.
## Step 2 — Session path

Run `bash <SKILL_DIR>/scripts/artifacts.sh allocate review-changes [branch]` (optional branch; default current HEAD). Parse KEY=VALUE output: `OWNER`, `REPO`, `BRANCH`, `BRANCH_SLUG`, `SESSION_DIR`, `SESSION_PATH`, `PASS`, `WRITE_ROOT`, `WRITE_SCOPE`.

Write root is **gitignore-gated**: when `<git-root>/.agents/artifacts` (or `.agents`) is ignored, artifacts stay project-local (`WRITE_SCOPE=local`); otherwise writes use `~/.agents/artifacts` (`WRITE_SCOPE=global`). Override with `AGENTS_ARTIFACTS_SCOPE=local|global`.

## Step 3 - Load context (parallel)
- `<SKILL_DIR>/references/checklist.md`
- `<SKILL_DIR>/references/format.md`
- `<SKILL_DIR>/references/output-contract.md`
- `<SKILL_DIR>/assets/template.md`
- Pass `02+`: previous session file (`<NN-1>.md`)
- Repo root docs: `AGENTS.md` or `CLAUDE.md`; fallback `README.md`
- `docs/` files relevant to touched areas
Repo root discovery order:
1. `.git` in workspace
2. `.git` in immediate child
3. `.git` in sibling
4. `.git` in parent
Stop at first match. Skip silently if docs are missing.
## Step 4 - Write the review
Follow `checklist.md` (workflow/coverage), `format.md` (structure/tags/summary), `output-contract.md` (guarantees), and `assets/template.md` (skeleton).
Save to `SESSION_PATH`. Use posture: skeptical, curious, and ambitious.
## Step 5 - Print summary
Print summary using `format.md` output summary format, then stop.
