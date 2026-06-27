# Push addressed fixes

Land fixes on the PR branch **before** notifying reviewers. They need the commit on the remote to re-check.

## When

- After address batch confirmed **addressed**
- Before **notify**
- Skip if `--fetch-only` or no file changes from the address pass

## Steps

1. `git status --short` — nothing to commit → skip push; continue (notify only if human items addressed).
2. Stage only files touched for this batch's addressed IDs.
3. Commit — message references PR `#<number>` and finding IDs (e.g. `Address PR #42 feedback: W1, N2`). Ask once unless batch already approved.
4. Push the PR head branch from `meta.md` (`branch` field):

```bash
git push origin <branch>
```

5. On success, note commit SHA in `tracker.md` Rounds row. On failure → stop; do not notify until push succeeds.

## Rules

- Never notify before a successful push when there were local fixes.
- Never push without user confirming the commit (or prior batch approval covering commit+push).
- Do not amend or force-push unless the user explicitly asks.
