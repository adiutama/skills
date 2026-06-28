# Session sources

Where to find review session files and what they contain. Adapted from the common PR review session format used in this repo.

## Lookup order (`resolve-session.sh`)

For PR branch slug `<slug>` under `.agents/artifacts/<owner>/<repo>/<slug>/` (project-local; search `~/.agents/artifacts/...` as fallback):

1. **`review-pr/`** — sessions from `/review-pr`
2. **`submit-pr-review/`** — this skill's namespace (fallback)

Highest-numbered `*.md` in the first directory that has one wins.

## Session file format

Numbered passes: `01.md`, `02.md`, … in the artifact directory.

Finding IDs by severity: `C1, C2…` · `W1, W2…` · `N1, N2…`

Each finding block:

```markdown
### <ID> — short title

| Field    | Value                    |
|----------|--------------------------|
| Severity | critical / warning / nit |
| Location | `repo/path/to/file:LINE` |
| Posted   | ❌                       |

Brief explanation (2-4 sentences).

**Paste:**

    One-line summary.
    *Risk:* ... (critical only)
    *Suggestion:* ...
```

`Posted` values: `❌` not posted · `✅` posted · `✅ dup` skip (already on PR).

Session header includes `OWNER`, `REPO`, `NUMBER`, `HEAD_SHA` — `resolve-session.sh` fills these from `gh pr view` when missing from disk context.

## Empty session

No `*.md` in the directory → stop with "no session file found"; user must provide a saved review pass or re-run a local review workflow that writes `NN.md` artifacts.
