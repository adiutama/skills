# Review JSON

Write one JSON object:

```json
{
  "version": 1,
  "summary": "Concise assessment of the change.",
  "body": "Suggested top-level GitHub review message in a natural reviewer voice.",
  "verdict": {
    "value": "approve | reject",
    "reason": "Why this verdict follows from the findings."
  },
  "coverage": {
    "reviewed": ["Files and behavior reviewed"],
    "notReviewed": ["Anything not verified and why"],
    "confidence": "high | medium | low"
  },
  "reconciliation": [
    {
      "findingId": "C1",
      "status": "fixed | partial | not_done | regressed | obsolete",
      "note": "What changed since the prior pass."
    }
  ],
  "findings": [
    {
      "id": "C1",
      "severity": "critical | warning | nit",
      "blocking": true,
      "title": "Short title",
      "location": {
        "path": "path/to/file",
        "line": 42
      },
      "explanation": "What is wrong and why.",
      "impact": "Consequence at the system or user level.",
      "suggestion": "One concrete direction.",
      "comment": "Concise text suitable for an inline PR comment.",
      "posting": "pending | duplicate | posted",
      "duplicateOf": {
        "kind": "conversation | inline | review",
        "id": 123456
      },
      "carriedFrom": {
        "pass": 1,
        "findingId": "C1"
      }
    }
  ],
  "tests": {
    "run": ["Checks performed"],
    "gaps": ["Checks still missing"]
  }
}
```

Use an empty array when a section has no entries. Number findings by severity: `C1`, `W1`, `N1`. `posting` is `duplicate` only when existing PR discussion already raises the same issue; otherwise new findings begin as `pending`.

Set `blocking` independently from severity. A finding is blocking only when it identifies a realistic correctness, security, data-loss, contract, or operational failure that should prevent merge; it must be grounded in specific behavior and have an actionable correction. Preferences, cleanup, optional tests, and nonessential improvements are non-blocking. Critical findings are always blocking. Nits are never blocking. Warnings may be either.

Use `reject` if any current finding is blocking. Use `approve` otherwise. Notes do not change an approval into a third verdict. The renderer rejects inconsistent JSON, so make the individual blocking judgments first and derive the verdict from them.

For every `duplicate` finding, include `duplicateOf` with the source activity collection and exact GitHub activity ID from the pass's activity JSON. Omit `duplicateOf` for other posting states. The report resolves this pointer to the original author, body, and GitHub URL; do not copy those values into the review.

For a finding that continues from an earlier pass, include `carriedFrom` with the exact source pass and finding ID. Point to the pass where that specific finding version appeared. Omit it for findings introduced in the current pass. The report resolves the pointer and links back to the original finding.

Only include findings that pass the value check in `SKILL.md`. The schema permits `nit` for explicitly requested polish reviews; it is not a request to look for nits. Keep unresolved prior findings traceable even when no new comment is needed.

Use the length rules and output check in `SKILL.md` for `body` and every finding `comment`.

Start both `body` and every `comment` with the AI authorship header defined in `SKILL.md`, followed by `\n\n` and the review text. Store it in the JSON so previews and submission use the same attributed text.

- `summary`: write the AI commentary for the user: explain the overall assessment, relevant context, and material caveats. Keep it distinct from the proposed GitHub message and avoid repeating the verdict reason. The handoff displays it outside the message blockquote; it is not submitted as the review body.
- `body`: state the decision and the main consequence or remaining correction. Do not list the inline findings again.
- `comment`: name the trigger, consequence, and a useful correction. Put additional proof in `explanation`; keep `impact` and `suggestion` to one sentence each.

Before saving, apply the plain-English definition and sentence checks in `SKILL.md` to every prose field—not only `body` and `comment`. Preserve identifiers and evidence exactly.

The HTML report preloads `body` for editing and can reset it exactly; an edited message replaces it when submitting. Finding `comment` values remain inline. The submission script maps `approve` to `APPROVE` and `reject` to `REQUEST_CHANGES`. It accepts pending finding IDs as one comma-separated value, such as `C1,C2`. It may append `submissions`; that field records mechanics and is not reviewer-authored judgment. Each submission records the reviewed, observed, and GitHub-returned head; whether movement was observed; how it was confirmed; and every warning shown.
