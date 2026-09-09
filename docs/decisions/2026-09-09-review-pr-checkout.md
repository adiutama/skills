# Review PR checkout transition

Status: implemented and verified.

## Agreed outcome

Prefer the PR's source branch name. Verify repository identity, source association, and the exact head commit. Preserve existing work through alternate branch names and isolated worktrees. Keep the skill portable across clients.

## Decisions

- Replace unconditional `git switch -C pr/<number>` with inspect, select, checkout, and verify. A clean worktree does not authorize resetting committed history.
- Preserve the existing review philosophy, verdict rules, and deliberate submission flow. This change addresses checkout and session behavior.
- Give PR sessions a stable PR scope with a hash of the Git common directory. This deliberately replaces the physical branch slug for explicit PR sessions; local-only legacy adapter sessions retain their existing layout. The hash separates independent clones and is shared by linked worktrees.
- Use explicit `--context` selectors in generated handoffs and internal follow-up commands. No repository-wide latest-review pointer. A single unqualified match remains a compatibility convenience.
- Allow one unfinished pass per PR per clone. Serialize collections per clone. Another unfinished PR review triggers a separate worktree instead of changing the checkout it is using.
- Copy a single legacy series through a staging directory; retain originals and relocate only context paths. Ambiguous histories stop with an explanation.
- Record owned worktree paths before Git mutation in a session-side ownership file, so later failures and review-history resets do not lose that record.
- Store fallback worktrees under the session's `worktrees/` directory, with reports alongside rather than inside them. Reuse only registered, clean, recorded owned worktrees. Never delete them automatically.
- Use a flat `review-pr-<number>` fallback when an existing `review` branch prevents a `review/` namespace.
- Fetch the PR ref through the base repository. Configure source tracking from verified GitHub metadata, adding a uniquely named remote for a fork when needed. Do not require a second fork fetch. Missing source repository metadata means no invented upstream.
- Resolve linked-worktree artifacts using the primary checkout's artifact policy. This preserves session discovery when the agent runs from the fallback directory.
- Retry a changing PR snapshot once, before branch mutation. Access and filesystem failures retain their real errors. Unknown errors do not trigger force, stash, or reset.
- Follow the host's normal approval mechanism if sandbox protection prevents the authorized Git operation from running. Once the adapter executes, actual collection errors stop the review. No permission settings are changed.
- Do not bind, archive, or otherwise control client threads. Report the review path because the client may still display the original checkout.

## Validation

Baseline: 37 existing tests passed before implementation.

Final automated suite: 66 tests passed with `node --test skills/review-pr/tests/review-pr.test.mjs` (37 baseline tests plus added coverage). Tests use temporary Git repositories and controlled `gh` responses. Coverage includes source-name selection, fast-forward, local commits, occupied branches, namespace collisions, forks, all dirty states including staged-then-reverted files, PR movement, worktree reuse/removal, session ambiguity, independent clones, legacy migration, and historical submission rejection. The complete fallback lifecycle includes rendering and mocked submission.

Fresh-thread evaluations:

| Fixture | Result | Thread |
|---|---|---|
| Original skill, dirty checkout | Stops on dirty checkout; existing notes preserved. | `thr_m2ab2nnfxe` |
| Updated skill, dirty checkout | Completes using a separate worktree and explicit context selector; notes preserved. | `thr_fym2zkkafq` |
| Updated skill, source branch with local commits | Completes on `review/pr-42`; source branch and its local file preserved. | `thr_m8pwppxnix` |

All three initially encountered the environment's Git metadata sandbox restriction. Their approved retries exercised the actual skill behavior. This exposed an instruction ambiguity, so the skill now distinguishes host approval prerequisites from adapter checkout errors.

The command transcripts were inspected: both updated runs read the specified skill and references, reviewed the returned checkout, wrote structured artifacts, and completed using the explicit selector. No evaluation submitted a review. Original fixture notes and local commits were independently verified afterward.

These are local fixture evaluations in bb. They validate the portable Git workflow and agent instructions, not every client's PR badge or automatic archive behavior.

## Operational limits

- Existing open threads may have cached old skill instructions; use the updated repository skill in a fresh thread.
- Source tracking may add a remote for a fork; no push occurs.
- Owned worktrees are retained until deliberate cleanup. Reports are outside those fallback worktrees, but deleting the configured artifact root still deletes the reports.
- A stale collection lock requires checking that its process stopped before removing it.
- Submission verdict and moved-head acceptance policies are unchanged by this transition.
