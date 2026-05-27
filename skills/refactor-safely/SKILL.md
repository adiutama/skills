---
name: refactor-safely
description: Refactor code in any language with a beauty-first, safety-first style while preserving behavior. Use when the user asks to clean up, beautify, restructure, harden, or make code more readable without changing functionality.
disable-model-invocation: true
metadata:
  argument-hint: "[file-path|folder-path|symbol-name]"
allowed-tools: Read Write Edit rg Glob Bash
---

Invoked as `/refactor-safely [file-path|folder-path|symbol-name]`.

# Refactor safely

## Philosophy

Treat code as a poem: structure matters. Beauty and effectiveness co-exist.

Never treat readability as optional. Small ugly code compounds and spreads.

## Non-negotiables

1. Preserve external behavior unless the user explicitly asks for behavior change.
2. Improve clarity and maintainability while keeping performance at least neutral.
3. Raise security posture when possible (input handling, escaping, validation, secret handling, error boundaries).
4. Keep edits intentional, minimal, and reversible.
5. Do not rewrite entire modules when focused refactors achieve the same result.

## Workflow

1. **Scope**
   - Resolve target from argument or user context.
   - If scope is ambiguous, ask one concise clarification and stop.

2. **Establish baseline**
   - Read current implementation first.
   - Identify behavior contracts (I/O shape, side effects, errors, edge cases).
   - If tests exist, run the smallest relevant set before edits.

3. **Refactor in passes**
   - Apply the checklist in `references/checklist.md`.
   - Prefer small coherent commits of change (structure, naming, simplification, safeguards).
   - Keep public APIs stable unless instructed otherwise.

4. **Verify**
   - Run relevant tests/checks after edits.
   - If no tests exist, add lightweight characterization tests when feasible.
   - Confirm no accidental functional drift.

5. **Report**
   - Summarize what changed and why it is cleaner/safer.
   - Explicitly note any trade-offs.
   - If verification was partial, state what remains to validate.

## Output format

Use this structure in responses:

1. **Intent**: one sentence on what was improved.
2. **Refactor changes**: 3-7 bullets grouped by structure/readability/safety.
3. **Behavior guarantee**: what was done to preserve functionality.
4. **Validation**: tests/checks run (or what could not be run).
5. **Residual risk**: short note if any uncertainty remains.
