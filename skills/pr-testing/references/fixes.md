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
Runtime: load the throwaway-services skill for any database or app you run; never use the repo's shared dev services or the coordinator's ports (<app port>, <dashboard port>, <S> set). Stop processes only with that skill's stop command or the PIDs you recorded; never pkill or killall.
Hosted checks: wait with `gh pr checks <n> --watch` in the background (your harness's background or monitor tool), not in a foreground call; macOS has no `timeout`.

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

## Reconcile and merge

For a PR that is behind or conflicting with its base (SKILL.md step 5). Same header lines as above, from `Repo:` to `Hosted checks:`; then:

```markdown
## Reconcile
Merge origin/<baseRefName> into <headRefName> with a normal merge commit. Never rebase or force-push. Resolve each conflict to keep both sides' intent; one you cannot resolve that way → stop and report it with both sides.
Hold for: <dependency PR #m merging first | nothing>

## Required checks
<the repo's gate commands>, run once on the merged head; then retest only the flows the merge diff touched: <flows or case ids>.

## Deliver
Push to <headRefName>, then message the coordinator with the new head SHA.
Merge: <the user's approval, quoted, or "not approved: stop after push">. Approved → once the hold is cleared and every required check is green, `gh pr merge <n> --<method> --match-head-commit <pushed SHA>`, then message the coordinator with the merge SHA.
Report: pushed SHA · conflicts and how each was resolved · checks with results · merge SHA or why it was held.

Ledger: <S>/ledger.md (read-only for you)
```

"Do not merge" belongs to the fix brief only. This brief merges only with the user's approval written into it.

## After it reports

1. Verify: the remote head equals the reported SHA, the commits are on the PR branch, and the checks it claims passed.
2. Deploy per [setup.md § Revision](setup.md#revision), with `--retest` set to the batch's case IDs. Add other cases whose code the diff touched.
3. Tell the user: what changed, the new SHA, which cases need a retest, and the same app URL.
4. Ledger: batch row → `deployed, retest asked`. Record the implementer's **link**; it is not reused for the next batch.

A failed or partial report → tell the user what is left. Spawn a new implementer only for a newly agreed batch.
