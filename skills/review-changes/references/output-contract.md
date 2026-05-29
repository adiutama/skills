# Review changes output contract

Workflow is in `SKILL.md`. This file defines mandatory review/output guarantees.

## Your job

**Default posture:** skeptical, curious, and ambitious.

1. **Declare scope first:** primary changed files, adjacent impacted files, and explicit out-of-scope files.
2. **Pass 1:** review combined diff + adjacent scope using deterministic order (`file path asc x lens order`).
3. **Pass 2+:** reconcile previous findings as `fixed / partial / not done / regressed / missed in prior pass`, then scan only new/touched code.
4. **Disclose coverage:** report reviewed, partial, and unreviewed scope with reasons.
5. **Be ambitious:** challenge assumptions and inspect non-obvious cross-system interactions.

## Severity labels

Use exactly:

- **critical** — blocks push
- **warning** — must fix before push
- **nit** — minor, still expected to be fixed unless deferred

## Push gate policy

Zero-finding gate:

- Any finding (`critical`, `warning`, `nit`) => **Not ready**
- Severity controls fix priority, not readiness
- No findings => **Ready**

## Technical taxonomy tags

Use 1-3 tags from this fixed list only:

- `code-smell`
- `tech-debt`
- `spaghetti-code`
- `tight-coupling`
- `leaky-abstraction`
- `api-inconsistency`
- `cohesion-gap`
- `clarity-debt`
- `test-debt`

## Review lenses (fixed order)

1. correctness
2. security
3. contract
4. operations
5. cohesion
6. clarity
7. tests
8. docs

## Session file rules

Use `assets/template.md` skeleton and `references/format.md` finding/output format.

- H1: `# Review changes - <branch>` only
- Pass must match session filename (`01`, `02`, ...)
- Keep only real findings
- Remove empty sections or use `- None.`
- Pass 01: no Prior pass/Reconciliation
- Pass 02+: include Prior pass and Reconciliation
- In reconciliation, use `missed in prior pass` when a new issue is inside previously covered scope

## Required coverage sections

Every saved session must include:

- `## Scope coverage`
  - primary scope reviewed
  - adjacent scope reviewed
  - out of scope
  - lens coverage summary per reviewed file
- `## Coverage notes`
  - partial/shallow areas and why
  - confidence limits
  - exact next-run scope when incomplete

Include `Coverage confidence` (`High`, `Medium`, `Low`) in Meta and printed summary.

## Concision

Keep findings short and actionable.

Every finding must include:
- exact location (`path:line` or range)
- what is wrong
- system-level impact
- one concrete action
