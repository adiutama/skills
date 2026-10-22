# Fix batches

One agreed batch → one fresh **implementer**. You never edit the tested project yourself.

## Before spawning

- The batch is agreed: a `fix-request` submission, or the user's explicit yes in chat to the batch you proposed.
- No other implementer is working on this PR branch (ledger). Otherwise wait for it, or add the items to its batch with **tell**.
- The PR's remote head equals the SHA the user tested. If it moved, re-read the PR first.

## Brief

Write `<S>/briefs/<n>-<batch>.md` with no secrets and no values from secret files. Then spawn: `H spawn-implementer --brief <file> --title "PR #<n> fix <batch>"`. It defaults to the deep tier at medium effort; pass `--model`/`--effort` only when the user asked.

```markdown
Role: implementer. Fix the items below on an existing pull request.

Repo: <owner/repo> · PR: #<n> <URL> · Branch: <headRefName> · Base: <baseRefName>
Start from: <tested SHA> (must equal the remote head; if not, stop and report)
Worktree: your own. Create it from the PR branch; never use <S>/tree, the coordinator checkout, or any running test environment.
Repo instructions: read the repo's agent instruction files and CONTRIBUTING first and follow them.

## Feedback (from manual testing at <tested SHA>)
- <case id> — <title>: <steps> → expected <…>, saw <user note / your reproduction, log lines>
- User note: <verbatim>

## Acceptance
- <observable result per item, in the user's words>
- Existing behaviour outside these items unchanged.

## Required checks
<the repo's lint, type check, and test commands; the CI jobs that must pass>

## Deliver
Commit on <headRefName> and push to the existing PR. Never open a new PR, force-push, rebase, or change the base unless told to.
Report: new head SHA · what changed per item · checks run with results · anything not fixed and why.
Do not merge. Do not mark the PR ready.

Ledger: <S>/ledger.md (read-only for you)
```

## After it reports

1. Verify: the remote head equals the reported SHA, the commits are on the PR branch, and the checks it claims passed.
2. Deploy per [setup.md § Revision](setup.md#revision), with `--retest` set to the batch's case IDs. Add other cases whose code the diff touched.
3. Tell the user: what changed, the new SHA, which cases need a retest, and the same app URL.
4. Ledger: batch row → `deployed, retest asked`. Record the implementer's **link**; it is not reused for the next batch.

A failed or partial report → tell the user what is left. Spawn a new implementer only for a newly agreed batch.
