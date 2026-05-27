---
name: commit-change
description: Generate a balanced commit message from edited-file context, then stage and commit with explicit confirmation.
compatibility: Requires a git repository and edited-file context in the current session.
metadata:
  argument-hint: "[scope-hint]"
allowed-tools: Bash(git:*) Read Write
---

Invoked as `/commit-change [scope-hint]`.

## Operating contract

- Source of truth for changed files: session context (edited/open/recent/user-listed files).
- Never use CLI to discover changed files (`git status`, broad `git diff`, or similar).
- Git is for execution; require confirmation for staging only.
- Ask at most one focused clarification when intent is ambiguous.

## Workflow

1. Build `target_files` from context. If empty, ask user to provide files and stop.
2. Read changes from context/tooling for `target_files` and infer intent/impact.
3. Show exact `target_files` and ask: confirm staging?
4. Only on explicit yes, run:
   - `git add -- <target_files...>`
5. Draft one default commit message (balanced style):
   - Conventional Commit
   - Imperative subject, <= 72 chars
   - Include a concise body focused on why/impact
6. Scope selection:
   - Prefer `[scope-hint]` when it clearly matches
   - Else infer one short scope from dominant area
   - Omit scope when mixed/unrelated
7. Present the default message directly. Only generate A/B/C variants if user explicitly asks for alternatives.
8. After staging is confirmed and the default message is prepared, run commit immediately:
   - `git commit -m "<subject>"` (no body)
   - `git commit -m "<subject>" -m "<body>"` (with body)

Never auto-stage.
