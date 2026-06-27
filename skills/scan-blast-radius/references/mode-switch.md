# Mode switch

Run this framing **before** any search or analysis. Do not re-litigate whether the focused change is correct in isolation.

```text
Stop implementation mode.

Assume the focused change works for the path we just edited.
Your job is blast radius only: breakages, missed wiring, and parallel gaps in
everything this change touches, plugs into, or replaces — including glue and
rewiring, not just files in the diff.

Do not optimize the original edit. Do not expand scope into unrelated refactors.
```

## Change kind

Infer from session context and diff shape. Ask once if unclear.

| Kind | Diff signals | Radius emphasis |
|------|--------------|-----------------|
| **fix** | Small patch, bug/context in intent | Callers, siblings with same pattern, behavior drift |
| **feature** | New routes/handlers/components, flags | Glue, registration, defaults, old path still live |
| **rewire** | Moved imports, renamed modules, DI | Orphan call sites, double wiring, stale config |

Record in report meta: `Change kind: fix | feature | rewire`.

## Intent line

One sentence from user or session context:

```text
Intent: <what we set out to change>
```

If missing, ask once before analysis.

## `--quick` mode

When invoked with `--quick`, run **Direct** and **Glue** rings only. Skip Parallel and Integration unless a finding in Direct/Glue raises a flag.
