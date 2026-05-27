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

---

## Minimal variant (simple skills)

```markdown
---
name: pickup-handoff
description: Load a handoff file from a provided path, send a short kickoff, and wait for confirmation before starting.
argument-hint: "Path to handoff .md file"
---

# Pickup handoff

1. Use the argument as the handoff file path.
2. Read the file.
3. Send a short kickoff (2-4 lines).
4. Ask for confirmation.
5. Start only after confirmation.
```
