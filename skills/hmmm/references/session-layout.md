# Session artifact layout

One session directory per brainstorm. Timestamps sort lexically (`sort -r` = newest first).

## Path

```text
<git-root>/.agents/artifacts/<owner>/<repo>/<branch-slug>/hmmm/sessions/<session-id>/
```

Fallback when not in a git repo, or when `<git-root>/.agents/artifacts` is **not** gitignored: `~/.agents/artifacts/.../hmmm/sessions/<session-id>/`

- `<session-id>` — `YYYYMMDD-HHmmss` UTC, optional `-<slug>` (kebab, ≤32)

## Files

| File | Owner | Child | Purpose |
|------|-------|-------|---------|
| `meta.md` | parent | read | problem, mode, phase, status |
| `master.md` | parent | read only | problem, constraints, decisions, log |
| `brief.md` | parent | read only | distilled discovery (≤80 lines) |
| `options.md` | parent | read only | option sketches |
| `decisions.md` | parent | read only | resolved forks |
| `recommendation.md` | parent | — | final outcome |
| `discovery/*.md` | child | write | per-lane raw discovery |
| `reports/` | parent | optional | archived phase notes |

## Phases (`meta.md`)

`frame` → `discover` → `synthesize` → `ideate` → `outcome` → `done`

Resume loads phase from `meta.md`; never restart from frame unless user asks.

## Resume

| User | Script | Then |
|------|--------|------|
| `resume` | `resolve-resume.sh` | confirm → continue at phase |
| `resume <hint>` | `resolve-resume.sh <hint>` | confirm → continue |

Always confirm. Show id, problem, phase, status, path.

## Scripts

| Script | Purpose |
|--------|---------|
| `init-session.sh [slug]` | create skeleton + `discovery/` |
| `list-sessions.sh [limit]` | JSON, newest first |
| `resolve-resume.sh [hint]` | recommend + candidates |
| `validate-discovery.sh <file>` | lane report check |
| `compact-master.sh <master.md> [max]` | size budget |
