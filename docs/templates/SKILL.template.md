---
name: verb-object
description: What this skill does and when to use it.
compatibility: Environment requirements (if relevant).
metadata:
  argument-hint: "<required-arg> [optional-arg]"
allowed-tools: Read Write
disable-model-invocation: true
---

Invoked as `/verb-object [args]`. If missing or invalid, ask once and stop.

## Step 1 — Resolve inputs

- Parse arguments.
- Validate required inputs.
- Stop early on invalid/ambiguous input.

## Step 2 — Load context

- Read required files and references.
- Prefer explicit paths like `<SKILL_DIR>/references/format.md`.

## Step 3 — Execute workflow

- Perform the core task.
- Apply constraints and safeguards.

## Step 4 — Produce output

- Return deterministic output format.
- Include concise summary and next action when relevant.

## Notes

- Keep instructions concise and executable.
- Keep behavior deterministic and fail-fast.
- Prefer **voice** on the spine (gates, trust, judgment) and **leading words** for repeated concepts—see [CONVENTIONS.md](../../CONVENTIONS.md#voice-and-leading-words).
- **Standalone:** this skill must complete its job without invoking or assuming other skills—see [CONVENTIONS.md](../../CONVENTIONS.md#skill-independence).
- **Duplicate shared concepts** from other skills into this package; do not link to their files at runtime.

---

## Minimal variant (simple skills)

```markdown
---
name: verb-object
description: What this skill does and when to use it.
argument-hint: "<required-arg>"
---

# Verb object

1. Parse and validate the argument.
2. Read required inputs.
3. Send a short kickoff (2-4 lines).
4. Ask for confirmation.
5. Execute only after confirmation.
```
