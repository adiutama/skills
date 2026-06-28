---
name: review-diff
description: Skeptical pre-push review—shippable before the PR exists. Session under .agents/artifacts/.../review-diff/ (project-local; global fallback).
disable-model-invocation: true
compatibility: Requires a git repository.
metadata:
  argument-hint: "[target-branch-or-commit-sha] (optional; defaults to HEAD)"
allowed-tools: Bash(git:* bash:*) Read Write
---

Invoked as `/review-diff [target-branch-or-commit-sha]`.

*Regret belongs in the diff review—not in the PR thread. Be **skeptical** while the fix is still yours.*

## Step 1 — Git state

`TARGET` = arg 1 or `HEAD`. `bash <SKILL_DIR>/scripts/resolve-range.sh "<TARGET>"`. Fail → stop with error.

Parallel: `git diff <COMMITTED_RANGE>`, `git status --short`, optional `git diff HEAD` if uncommitted included.

Empty surface → nothing-to-review message; stop.

## Step 2 — Session path

Run `bash <SKILL_DIR>/scripts/artifacts.sh allocate review-diff [branch]` (optional branch; default current HEAD). Parse KEY=VALUE output: `OWNER`, `REPO`, `BRANCH`, `BRANCH_SLUG`, `SESSION_DIR`, `SESSION_PATH`, `PASS`, `WRITE_ROOT`, `WRITE_SCOPE`.

Write root is **gitignore-gated**: when `<git-root>/.agents/artifacts` (or `.agents`) is ignored, artifacts stay project-local (`WRITE_SCOPE=local`); otherwise writes use `~/.agents/artifacts` (`WRITE_SCOPE=global`). Override with `AGENTS_ARTIFACTS_SCOPE=local|global`.

## Step 3 — Context (parallel)

`<SKILL_DIR>/references/checklist.md`, `format.md`, `output-contract.md`, `assets/template.md`; prior pass if `02+`; repo docs + touched `docs/`. Find `.git`: workspace → child → sibling → parent.

## Step 4 — Write

Checklist + format + contract + template → `SESSION_PATH`. Bar: **shippable**.

## Step 5 — Summary

Print per `format.md`; stop.
