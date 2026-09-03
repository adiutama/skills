# Change summary JSON

Write one session-level JSON object to the `summary` path returned by `collect`:

```json
{
  "version": 1,
  "study": {
    "revision": 1,
    "writtenAtPass": 1,
    "refreshReason": null,
    "oneSentence": "What the pull request changes in plain English.",
    "purpose": "Why the change exists.",
    "claimedIntent": ["Claims from the PR description or discussion."],
    "observedBehavior": ["Behavior confirmed from code or tests."],
    "before": ["Relevant behavior before the change."],
    "after": ["Relevant behavior after the change."],
    "flow": [
      {
        "step": "Short step name",
        "explanation": "What happens in plain English.",
        "evidence": ["path/to/file:line"]
      }
    ],
    "components": [
      {
        "name": "Component or file",
        "role": "Its role in the system.",
        "reason": "Why this change touches it.",
        "evidence": ["path/to/file:line"]
      }
    ],
    "contracts": ["Affected API, schema, event, configuration, or compatibility promise."],
    "unknowns": ["Questions repository evidence cannot answer."]
  },
  "updates": [
    {
      "pass": 1,
      "kind": "full",
      "head": "reviewed commit SHA",
      "summary": "What this pass adds to the understanding.",
      "changes": {
        "code": true,
        "activity": true
      },
      "blastRadius": [
        {
          "ring": "direct | glue | contract | parallel | integration | operational",
          "status": "checked | not_applicable | not_verified",
          "scope": ["Surface inspected or affected."],
          "notes": "Plain-English result.",
          "evidence": ["path/to/file:line"]
        }
      ],
      "reviewTargets": ["Concrete behavior to investigate during findings review."]
    }
  ]
}
```

The first summary checkpoint creates the study; normally this is pass 1. Later passes preserve the study byte-for-byte and append one update for the delta between the previous and current pass. Set `kind` to `incremental` for those updates.

Refresh the study only when the PR's fundamental intent or behavior model changed, or when the user asks. Increment `revision`, set `writtenAtPass` to the current pass, and explain the invalidation in `refreshReason`. Never delete earlier blast-radius updates.

Every update must cover all six rings. Mark each ring `checked`, `not_applicable`, or `not_verified`; never omit a ring silently. `not_verified` is an evidence gap, not a finding. Findings belong only in the review JSON.
