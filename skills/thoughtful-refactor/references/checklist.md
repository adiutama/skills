# Poetic Refactor Checklist

Use this checklist during refactoring. Prioritize correctness first, then elegance.

## 1) Structure and flow

- [ ] Break overly long functions into cohesive units with clear intent.
- [ ] Remove dead code, commented-out blocks, and duplicate logic.
- [ ] Flatten avoidable nesting with early returns/guards.
- [ ] Keep module layout predictable (public API near top, helpers grouped).

## 2) Naming and readability

- [ ] Replace vague names with intent-revealing names.
- [ ] Make data transformations legible step-by-step.
- [ ] Keep line length and spacing visually calm and scan-friendly.
- [ ] Prefer explicit control flow over clever compact tricks.

## 3) Correctness and safety

- [ ] Preserve public behavior and error semantics.
- [ ] Validate external inputs at boundaries.
- [ ] Harden unsafe operations (escaping, parsing, casting, file/path handling).
- [ ] Ensure secrets/tokens are never logged or hardcoded.

## 4) Simplicity and efficiency

- [ ] Remove unnecessary allocations, passes, or conversions.
- [ ] Keep complexity proportional to the problem.
- [ ] Prefer straightforward defaults over configuration sprawl.

## 5) Verification

- [ ] Tests pass before and after refactor (or characterization tests added).
- [ ] Lint/type/static checks pass where available.
- [ ] Diff reviewed for accidental behavior changes.

## Refactor quality gate

A refactor is complete only if all are true:

1. The code reads more clearly than before.
2. Behavior is preserved and verified.
3. Security posture is same or better.
4. The resulting shape is simpler, not merely different.
