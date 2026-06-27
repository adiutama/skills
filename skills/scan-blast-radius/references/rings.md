# Impact rings

Walk rings in order. For each ring, record `checked`, `n/a`, or findings. Do not skip silently.

## 1 — Direct

**Question:** Who calls this, and what does this call?

| Kind | Check |
|------|-------|
| fix | Callers/callees of patched symbols; tests covering changed modules |
| feature | New exports, routes, hooks, public API surface |
| rewire | Import graph: anything still pointing at old module/path? |

Actions: `rg` references, read call sites, read tests for touched paths.

## 2 — Glue

**Question:** What sits *between* layers — and did we wire it symmetrically?

Glue is middleware, adapters, mappers, DI registration, event bus subscribers, route tables, plugin loaders, ORM/repository facades, error translators, auth guards on boundaries.

| Kind | Check |
|------|-------|
| fix | Did the fix bypass or duplicate middleware/error mapping? |
| feature | Is the new path registered once? Old path still mounted? Defaults on boundary? |
| rewire | Register/unregister symmetric? Two sources of truth? Config still points at old target? |

Prompts:
- What still calls the **old** entry point?
- Is there **one** authoritative path or two parallel paths?
- Are null/empty/error cases handled at the **boundary**?
- Feature flag off — does old behavior still work?

## 3 — Contract

**Question:** What implicit promises changed?

Types, schemas, JSON shapes, error codes, env vars, feature flags, DB columns, OpenAPI/GraphQL, event payloads, file formats.

| Kind | Check |
|------|-------|
| fix | Did error semantics or return shape change for callers? |
| feature | New required fields downstream? Migration needed? |
| rewire | Stale types/docs/tests referencing old contract? |

## 4 — Parallel paths

**Question:** Did we fix/build one instance and leave siblings?

| Kind | Check |
|------|-------|
| fix | Same bug pattern in sibling files/modules? |
| feature | Duplicate handler pattern elsewhere needing same feature? |
| rewire | Copy-pasted wiring only updated in one place? |

Actions: search for similar symbols, strings, route patterns, duplicated logic.

## 5 — Integration

**Question:** What external or cross-team systems assume the old graph?

Auth, cache keys, background jobs, webhooks, third-party APIs, cross-service RPC, analytics events, search indexes.

Flag deploy order risks (migration before code, or vice versa).

## 6 — Operational

**Question:** Can we observe, roll back, and run this safely?

Logging, metrics, alerts, feature flags, rollback path, partial deploy, data backfill.

Often `n/a` for tiny fixes; required for feature/rewire with schema or flag changes.

## Ring summary table (required in report)

```markdown
| Ring | Status | Notes |
|------|--------|-------|
| Direct | checked / n/a | |
| Glue | checked / n/a | |
| Contract | checked / n/a | |
| Parallel | checked / n/a | |
| Integration | checked / n/a | |
| Operational | checked / n/a | |
```

## Severity (impact, not code quality)

| Level | When |
|-------|------|
| **critical** | Likely breakage, auth/data loss, silent wrong behavior in production path |
| **warning** | Probable gap: missed wiring, untested path, stale parallel code |
| **note** | Worth verifying; low confidence or edge-only |

IDs: `I1, I2…` (impact). Do not reuse review-diff C/W/N taxonomy.
