---
name: commit-changes
description: Check staged changes first; otherwise use context-discovered file changes to stage and commit with a generated message.
disable-model-invocation: true
compatibility: Requires a git repository and edited-file context in the current session.
metadata:
  argument-hint: "[scope-hint] [--skip-stage]"
allowed-tools: Bash(git:*) Read Write
---

Invoked as `/commit-changes [scope-hint] [--skip-stage]`.

## Step 1 — Operating contract

- Changed-file source is session context (edited/open/recent/user-listed files).
- Never use CLI to discover modified files (no `git status`, no broad working-tree diffs).
- CLI is allowed only for staged detection, staging execution, and commit execution.
- Stage by default; skip only when `--skip-stage` is explicit.
- Ask at most one focused clarification when intent is ambiguous.

## Step 2 — Workflow

1. Detect staged files first:
   - Run `git diff --cached --name-status`.
   - If staged files exist, skip discovery/staging and continue to step 5.
2. If step 1 is empty, discover modified files from context only:
   - Build `target_files` from edited/open/recent/user-listed files.
   - Classify each file as Create/Update/Delete from context/tooling.
   - If `target_files` is empty, ask user to provide files and stop.
3. Reconcile staged vs modified sets:
   - Compare step 1 and step 2 results as a safety check.
   - In normal flow here, step 1 is empty and step 2 is non-empty.
   - If staged files appear mid-flow (race/manual staging), show both sets and ask one focused confirmation before staging.
4. Stage changes (default):
   - If `--skip-stage` is present, do not run `git add`.
   - Otherwise run `git add -- <target_files...>`.
5. Draft one default commit message:
   - Conventional Commit format.
   - Imperative subject, <= 72 chars.
   - Concise body focused on why/impact.
   - Scope: prefer `[scope-hint]` if it matches; otherwise infer one short dominant scope; omit when mixed.
   - Present this default directly; only generate A/B/C variants when explicitly requested.
6. Commit immediately after message generation:
   - `git commit -m "<subject>"` (no body)
   - `git commit -m "<subject>" -m "<body>"` (with body)

Do not ask for staging confirmation.
