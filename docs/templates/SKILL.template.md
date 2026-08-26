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

<!-- Optional: keep only when a short, verified quotation sharpens the skill's central judgment. -->
> “A short, verified quotation.”
> — Author, source

<!-- Optional: replace with an original boundary line, or remove when it adds no judgment. -->
*State the posture this workflow must preserve.*

## Step 1 — Resolve inputs

Parse the arguments.

If a required input is missing or ambiguous, ask once and stop.

**Done when:** the input identifies exactly one valid target.

## Step 2 — Load context

Read the required files and references. Use explicit paths such as `<SKILL_DIR>/references/format.md`.

**Done when:** every required source is available or explicitly reported missing.

## Step 3 — Execute workflow

Perform the core task. Apply each constraint and safeguard where it becomes relevant.

**Done when:** `<observable completion condition>`.

## Step 4 — Produce output

Return the deterministic output format.

Include a concise summary and next action when relevant.

**Done when:** the output satisfies `<output contract>`.

<!-- Optional: include when the skill controls user-facing communication. -->
## Voice

Use plain English. Lead with the result. Define necessary technical terms.

Keep chat conversational and artifacts structured.

## Notes

- Keep instructions concise and executable.
- Keep behavior deterministic and fail-fast.
- Use **poetic boundaries, literal actions, and visible structure**. Define uncommon leading words that control behavior—see [CONVENTIONS.md](../../CONVENTIONS.md#voice-and-leading-words).
- Quotations are optional. Verify the wording, author, and source before keeping one.
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
