# Commit message format

## Output shape

Use this output format when proposing candidates:

```text
Candidate A
<type>(<scope>): <subject>

<optional body>

Candidate B
<type>(<scope>): <subject>

<optional body>

Candidate C
<type>(<scope>): <subject>

<optional body>

Recommendation: <A|B|C> — <one line reason>
```

If scope is omitted, format subject as `<type>: <subject>`.

## Message constraints

- Follow Conventional Commits type vocabulary from checklist.
- Keep subject under 72 chars.
- Avoid vague subjects like `update files` or `misc changes`.
- Ensure each candidate emphasizes a distinct trade-off:
  - A: safest and concise
  - B: balanced detail
  - C: impact-focused

## Style alignment

- Mirror naming terms from the diff and recent commit subjects.
- Keep tense and punctuation consistent with existing history.
