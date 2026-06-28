# Session artifact layout

One session directory per run. Timestamps sort lexically (`sort -r` = newest first).

## Path

```text
<git-root>/.agents/artifacts/<owner>/<repo>/<branch-slug>/work-until/sessions/<session-id>/
```

Fallback when not in a git repo, or when `<git-root>/.agents/artifacts` is **not** gitignored (writes use global root): `~/.agents/artifacts/.../work-until/sessions/<session-id>/`

- `<owner>/<repo>` — `git remote get-url origin`; else `_local/_local`
- `<branch-slug>` — sanitized branch; detached → `detached-<short-sha>`
- `<session-id>` — `YYYYMMDD-HHmmss` UTC, optional `-<slug>` (kebab, ≤32)

## Files

| File | Owner | Child | Purpose |
|------|-------|-------|---------|
| `meta.md` | parent | read | id, status, goal, exit, max |
| `master.md` | parent | **read only** | goal, exit, constraints, log |
| `handoff.md` | parent | read | this iteration's focus |
| `report.md` | child | write | this iteration's result |
| `reports/<NN>.md` | parent | optional | archived reports |

## master.md budget

Before each handoff: `compact-master.sh <master.md> 150`

- Attempts: keep 8 newest → fold rest to Archive
- Archive: trim to 20 bullets when master >150 lines
- Iteration log: never truncate (summarize old rows to Archive prose if needed)

## Resume

| User | Script | Then |
|------|--------|------|
| `resume` | `resolve-resume.sh` | confirm → continue |
| `resume <hint>` | `resolve-resume.sh <hint>` | confirm → continue |
| session id | `list-sessions.sh` + match | confirm → continue |

Always confirm. Show id, goal, exit, status, iteration count, path.

Pick order: newest `active` → `blocked`/`max-reached` → newest.

## Scripts

| Script | Purpose |
|--------|---------|
| `init-session.sh [slug]` | create skeleton |
| `list-sessions.sh [limit]` | JSON, newest first |
| `resolve-resume.sh [hint]` | recommend + candidates |
| `validate-report.sh <report.md>` | field check |
| `compact-master.sh <master.md> [max]` | size budget |

`init-session.sh` returns JSON with `session_dir`; parent fills `meta.md` + `master.md`.
