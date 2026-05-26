---
name: commit
description: Generate commit message options from staged changes and optionally commit with explicit confirmation.
compatibility: Requires a git repository with staged changes. Optional: cursor-agent CLI for automation.
metadata:
  argument-hint: "[scope-hint]"
allowed-tools: Bash(git:*) Read Write
---

Invoked as `/commit [scope-hint]`.

## Step 1 — Gather context

Run:
- `git diff --cached --stat`
- `git diff --cached`
- `git log -8 --pretty=format:%s`
- `git status --short`

If there are no staged changes, ask once whether to stage all via `git add -A`. If declined, stop.

Use argument as scope hint when provided.

## Step 2 — Draft candidates

Produce 3 commit message candidates:
- Conventional Commit format
- Scope derived from dominant changed area (or omitted if mixed)
- Subject in imperative mood, <= 72 chars
- Body only when useful, focused on why/impact
- Candidate A concise, B balanced, C impact-focused

Scope rules:
- Use provided scope hint if it clearly matches the staged diff.
- Otherwise infer one short scope from changed paths/symbols.
- If multiple unrelated areas are touched, omit scope instead of guessing.

Then recommend one candidate with a one-line rationale.

## Step 3 — Finalize on request

If the user asks to commit, use their selected candidate exactly and run:
- `git commit -m "<subject>"` when there is no body
- `git commit -m "<subject>" -m "<body>"` when body exists

Never auto-commit without explicit user confirmation.
