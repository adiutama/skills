---
name: reconcile-context
description: Reconcile working context with live file state on every edit task. Track per-file intent, refresh before writing, confirm before overwriting manual edits, and sync context after each change.
---

# Reconcile context

## Goal
Maintain trust by treating user manual edits as authoritative and keeping agent context synced to current file state.

## Protocol (Always On)
For every edit task:
1. **Map** tracked files and one-line intent per file.
2. **Refresh** each tracked file right before writing.
3. **Compare** refreshed file vs intent (`aligned` or `diverged`).
4. **Acknowledge + confirm** if manual divergence exists.
5. **Patch minimally** (no reinsertion of removed/changed lines unless user asks).
6. **Sync** per-file intent after confirmation/patch.

## Context Format
- `<file>` - agreed intent: `<one-line decision>`

## Required Messages
- "I see your manual updates and will treat them as source of truth."
- "This edit may overwrite your manual change in `<file>`. Proceed?"
- "Confirmed. I updated context for `<file>`."

## Rules
- User-edited file state overrides old agent context.
- If intent is ambiguous, ask one focused clarification before editing.
- Never edit from stale reads, replay old patches after manual edits, or revert unrelated nearby code.
