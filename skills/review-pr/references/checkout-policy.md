# Checkout policy

**The PR identifies the work. The commit identifies the evidence. The branch helps the client find it.**

## Prefer the source branch

Resolve the explicit GitHub PR number or URL in the current base repository. Fetch the PR ref and compare it with fresh metadata before touching local branches. Retry once if the head or source changes; a second movement stops collection.

A matching local name is only a candidate. Reuse it when its tracking configuration matches the PR's source repository and branch, or when a skill-recorded PR association matches. Without tracking, a same-repository branch must also match the verified remote branch name and ref. Never infer a fork association from equal commits alone.

When the branch is behind, fast-forward. When it has extra commits or diverged history, preserve its tip and use a fallback. Never use force-create, hard reset, stash, rebase, or merge reconciliation as a checkout fallback.

## Choose a fallback

| Cause | Action |
|---|---|
| Source branch is unrelated, ahead, diverged, or checked out elsewhere | Use `review/pr-<number>`. Reuse only a verified compatible branch; otherwise add `-2`, `-3`, and so on. |
| A branch named `review` blocks that namespace | Use `review-pr-<number>` with the same suffix rules. |
| Current checkout has staged, unstaged, or untracked changes | Preserve its files and index; review in a separate worktree. |
| Another unfinished PR review owns the current checkout | Give the new review a separate worktree. |
| A recorded owned worktree is still registered and clean | Reuse it on the next pass if its branch can safely reach the target. |
| Authentication, remote access, Git, or filesystem error | Report the specific error. Never treat an unknown failure as permission to force checkout. |

Tracking uses the PR source repository, including forks. When no existing remote names that repository, create a uniquely named `review-pr-<hash>` remote and configure the review branch to track the source branch. The verified commit is fetched through the base repository's PR ref; collection does not need a second fork fetch. If source repository metadata is unavailable, retain the explicit PR association without inventing an upstream.

After checkout, require both the exact verified commit and a clean tree. Review from `checkout.path`; report separate paths visibly. The original client workspace is not rebound automatically.

## Keep sessions addressable

Explicit PR sessions are keyed by repository, PR number, and Git clone. The artifact scope is `pr-<number>-<clone-key>` in the usual `<owner>/<repo>/<scope>/review-pr/` layout. Linked worktrees share the primary checkout's artifact root.

Retain the absolute `context` path returned by collection. Use `--context <path>` for checkpoint, complete, render, open, and submit, from a checkout of the same clone. This avoids branch-dependent lookup and cross-thread guesses. If an unqualified action matches multiple sessions, request a selector rather than choosing the latest.

One PR series can have only one unfinished pass. Different PRs can have separate unfinished passes. Collection holds a per-clone lock while selecting a checkout and writing the session. If collection was interrupted, verify no collection is running before removing the reported stale lock.

A single identifiable legacy PR series is copied, including archived passes. Only context file paths are relocated; review text and source activity remain unchanged. Original files remain available. Ambiguous legacy series stop collection rather than merging histories.

## Preserve the workspace lifecycle

Record every owned fallback worktree. Keep artifacts outside those worktrees. Do not delete worktrees or branches automatically. A user or client may clean them up later; subsequent collection must verify registration and cleanliness before reuse.

Matching source names and tracking information can help a client recognize the PR. The skill neither requires a client API nor guarantees PR badges or automatic thread archiving.
