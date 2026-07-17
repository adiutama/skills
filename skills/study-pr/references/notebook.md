# Living notebook

Write `SESSION_PATH` in Markdown and update it after every substantive exchange. Preserve earlier misconceptions as learning history; mark them corrected instead of deleting them.

Use this structure:

```markdown
# Study PR #<number> — <title>

- Status: active | paused | ready
- PR: <url>
- Head: <sha>
- Last head check: <UTC timestamp>
- Head check interval: 10 minutes | <learner override>
- Learner goal: <what they want to understand>

## Revision history
### R1 — <sha> (current)
- Arrived: <session start or detected timestamp>
- Change from prior revision: initial
- Learning impact: initial model

## Initial code map
- Claimed change: <plain-language behavior>
- Before → after: <behavior delta>
- Main path: <entry → changed components → observable result>
- Touched files: `<path>` — <role> — <why changed>
- Related contracts/tests: <citations>
- Evidence gaps: <unknowns>

## Working model
<current learner-owned explanation>

## Learner language
- Familiar terms: <words or domain concepts already comfortable>
- New glossary: `<technical term>` — <plain meaning>
- Helpful analogy or visual: <what made the concept click>

## System map
<components and relationships explored so far>

## Conversation ledger
### Q1 — <learner question>
- Answer: <concise answer>
- Evidence: [PR] <diff location>; [repository] `path:line`
- Implication: <what follows>
- Confidence: confirmed | inferred | unknown

## Misconceptions corrected
- ~~<earlier model>~~ → <corrected model> — <evidence>

## Learner annotations
### A1 — <screenshot or sketch description>
- Learner marked: <arrows, labels, grouping, deletion, or question>
- Interpreted as: <agent's reading of the annotation>
- Checked against: [PR] <diff location>; [repository] `path:line`
- Outcome: confirmed | corrected | unresolved

## Review leads
- <possible improvement> — Evidence: <citation> — Unknown: <what still needs judgment>

## Ask the author
- <question unavailable from inspected evidence>

## Teach-back
- Goal and strategy:
- Before → after path:
- Affected contracts/invariants:
- Review focus:
- Remaining unknowns:
```

Rules:

- Attribute learner conclusions to the learner; do not rewrite inference as fact.
- Preserve annotated screenshots as descriptions in the notebook; reference an available attachment or file path without depending on it remaining accessible.
- Treat annotations as evidence of the learner's mental model, not of runtime behavior.
- Keep exactly one revision marked `current`; attach every Q&A entry, annotation, implication, and review lead to the revision where it was checked.
- Preserve superseded explanations; never edit history to make an earlier model appear current.
- Keep review leads neutral and falsifiable.
- Keep the initial code map separate from the learner's evolving model so the guide can teach before conversation starts.
- Record enough evidence to reconstruct why the session reached a conclusion.
- The final summary must be derivable from this notebook without relying on chat history.
