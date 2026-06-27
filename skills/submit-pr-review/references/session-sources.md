# Session sources

Where to find review session files and what they contain. Adapted from the common PR review session format used in this repo.

## Lookup order (`resolve.sh`)

For PR branch slug `<slug>` under `.agents/artifacts/<owner>/<repo>/<slug>/` (project-local; search `~/.agents/artifacts/...` as fallback):

1. **`submit-pr-review/`** — this skill's namespace (preferred for new sessions)
2. **`post-pr-review/`** — legacy rename (same layout)
3. **`review-pr/`** — legacy review namespace (same `NN.md` layout)

Highest-numbered `*.md` in the first directory that exists and has files wins.

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

Session header includes `OWNER`, `REPO`, `NUMBER`, `HEAD_SHA` — `resolve.sh` fills these from `gh pr view` when missing from disk context.

## Empty session

No `*.md` in any directory → stop with "no session file found"; user must provide a saved review pass or re-run a local review workflow that writes `NN.md` artifacts.
