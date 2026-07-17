# PR revision protocol

Use this protocol whenever the live `headRefOid` differs from the notebook's current head.

## Compare

Let `OLD` be the notebook head and `NEW` the live PR head. Resolve `OWNER/REPO` from the PR URL, then inspect:

```bash
gh api "repos/<OWNER>/<REPO>/compare/<OLD>...<NEW>"
gh pr view <PR> --json title,body,headRefOid,commits,files
gh pr diff <PR>
```

The comparison may fail after a force-push because `OLD` is no longer reachable. In that case, use the fresh PR diff and previously cited excerpts; conservatively mark affected material `needs recheck`.

Determine:

- commits added, removed, or rewritten;
- files and hunks changed since `OLD`;
- whether claimed intent or PR description changed;
- which studied paths, contracts, tests, diagrams, annotations, and review leads intersect the delta.

## Reconcile learning

Create the next `Revision history` entry and classify every affected notebook item:

- `still valid` — evidence and implication survive unchanged;
- `changed` — update the current model while retaining the old explanation under its revision;
- `resolved` — a prior question or review lead is addressed by the new revision;
- `needs recheck` — the delta or force-push prevents a confident carry-forward;
- `superseded` — old code or reasoning no longer describes the PR.

Unrelated items may be carried forward as `still valid`; do not re-investigate them merely because the SHA changed.

## Explain the delta

Before resuming, tell the learner:

1. old SHA → new SHA;
2. commits or force-push detected;
3. changed files and behaviors relevant to the study;
4. what remains valid;
5. what must be revisited;
6. which review leads were added, resolved, or superseded.

Update the notebook head only after this reconciliation. Regenerate an existing HTML snapshot so its current-revision banner and revision timeline cannot remain stale.

Completion: no current claim depends solely on superseded evidence, and the learner knows exactly which part of their mental model changed.
