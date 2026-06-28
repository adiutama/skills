# Deep mode — one fork at a time

In **deep** mode, resolve the decision tree sequentially—like an interview, but only for forks that discovery cannot close.

## Rules

- One question per message; wait for answer.
- Include a **recommended** choice in plain language—not a formal "Option A".
- If the answer is in `brief.md` or `discovery/*`, state it—do not re-ask.
- Log to `decisions.md` immediately after each answer.

## Fork order (typical)

1. Scope / non-goals
2. Architectural boundary (where it lives)
3. Data model or integration surface
4. Operational concerns (auth, observability, rollout)
5. Option selection among `options.md`

## Escape hatch

User says "rapid" or "just pick" → switch to **rapid** for remainder; record in `meta.md`.
