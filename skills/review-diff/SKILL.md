---
name: review-diff
description: Skeptical pre-push review—shippable before the PR exists. Session under ~/.agents/artifacts/.../review-diff/.
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

Remote → `OWNER`/`REPO` (else `_local`). Slugify branch. Dir: `~/.agents/artifacts/<OWNER>/<REPO>/<slug>/review-diff/`. Next pass `NN.md` → `SESSION_PATH`, `PASS`. Legacy `review-workspace/`, `review-changes/` — full path or migrate.

## Step 3 — Context (parallel)

`<SKILL_DIR>/references/checklist.md`, `format.md`, `output-contract.md`, `assets/template.md`; prior pass if `02+`; repo docs + touched `docs/`. Find `.git`: workspace → child → sibling → parent.

## Step 4 — Write

Checklist + format + contract + template → `SESSION_PATH`. Bar: **shippable**.

## Step 5 — Summary

Print per `format.md`; stop.
