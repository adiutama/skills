# Push code fixes

When the user chose **fix** and edits touched the repo, land changes before the closing Slack reply.

## When

- After execute, before reply
- Skip when fix was runbook-only (no file changes) or user chose skip/need-info

## Steps

1. `git status --short` — nothing to commit → skip push; go to reply.
2. Stage only files for this incident.
3. Commit — e.g. `fix(on-call): <short summary> [incident-<id>]`. Ask once unless already approved.
4. Push:

```bash
git push origin <current-branch>
```

5. On failure → stop; tell user in Slack draft that fix is local-only until push succeeds.

## Rules

- Never claim "fixed" in Slack before push succeeds when the fix is code.
- No force-push unless user explicitly asks.
