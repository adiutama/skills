# Exit criteria examples

When exit is undefined, offer 2–3 fits; let user pick or combine.

## Objective (preferred)

| Pattern | Example |
|---------|---------|
| Tests | `npm test exits 0` |
| Lint / typecheck | `npm run lint && npm run typecheck exit 0` |
| Zero findings | `0 unresolved review items` |
| File / artifact | `docs/plan.md complete` |
| Metric | `bundle ≤ 250kb` |
| Git | `no unstaged changes except X` |
| Saved session verdict | artifact file shows `safe to commit` or `0 pending threads` |
| Fetch-only empty | command exits 0 with `total_count == 0` in JSON output |

## Bounded effort

| Pattern | Example |
|---------|---------|
| Hard cap | `max 5; stop when tests pass or cap hit` |
| Diminishing returns | `stop after 2 consecutive no-fix iterations` |

Pair caps with what each pass tries to achieve.

## Human gate

| Pattern | Example |
|---------|---------|
| Per round | `stop when I reply "ship it"` |
| Summary approval | `exit when I confirm done` |

Stop after each iteration — do not auto-loop.

## Composite

Verify each testable clause: `tests pass AND lint clean AND I confirm`.

## Verification

After child `status: done`, parent verifies when possible:

| Exit mentions | Verify |
|---------------|--------|
| tests | `npm test` (or project cmd) |
| lint | `npm run lint` |
| typecheck | `npm run typecheck` / `tsc --noEmit` |
| build | `npm run build` |
| file exists | `test -f <path>` |
| zero findings | re-run the cited audit command or re-read the session artifact |
| session verdict | read artifact path recorded in `master.md` → Decisions |
| fetch-only empty | re-run fetch-only; confirm `total_count == 0` |

Record verify commands in `master.md` → Decisions. Verify fail → next iteration (≤5 lines in handoff). Do not set `meta.md` `done` until verify passes.
