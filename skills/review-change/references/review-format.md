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

`body` is the reviewer's suggested top-level message. The HTML report preloads it for editing and can reset it exactly; an edited message replaces it when submitting. Finding `comment` values remain inline. The submission script maps `approve` to `APPROVE` and `reject` to `REQUEST_CHANGES`. It may append `submissions`; that field records mechanics and is not reviewer-authored judgment.
