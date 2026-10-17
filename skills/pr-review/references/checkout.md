# Checkout

Review a detached worktree at the exact head, so the user's checkout, branches, index, and untracked files are never touched. Fetching into the user's clone and registering a worktree there are allowed; nothing else in it changes.

1. **Find a clone.** Use the current workspace if a remote points at the PR's base repo (`git remote -v`). Otherwise clone once to `<S>/../_clones/<owner>-<repo>` with `gh repo clone <owner>/<repo> <path> -- --filter=blob:none`.
2. **Fetch the head** through the base repo, which covers forks: `git -C <clone> fetch <remote> pull/<n>/head`.
3. **Verify.** `git -C <clone> rev-parse FETCH_HEAD` must equal `headRefOid`. If not, re-read metadata and retry once; if it moves again, stop and report that the PR is unstable.
4. **Add the worktree** from the verified SHA, never `FETCH_HEAD`: `git -C <clone> worktree add --detach <S>/tree <headRefOid>`. On a later pass, reuse `<S>/tree` only if it's registered and clean (`git status --porcelain` empty), then `git -C <S>/tree checkout --detach <new head>`.
5. **Confirm** `HEAD` equals the verified SHA and the tree is clean before reading code.

Then fetch the base branch. Review the diff against the merge base (`git diff $(git merge-base <remote>/<base> HEAD)...HEAD`). Then check drift against the current base: does it still merge cleanly (`git merge-tree`), and do numbered artifacts (migrations, version files) collide with ones added on the base since? Drift goes under Coverage, or becomes a finding if it breaks the merge.

## Running tests

- **Dependencies:** install them inside the worktree with the repo's lockfile command (e.g. a clean install). Never symlink or reuse the user's installed dependencies; they would run the user's code, not the PR's.
- **Environment:** run tests with the variables the repo's CI uses (e.g. `NODE_ENV=test`), not whatever your shell has set.
- **Services** (database, queue, …): never the developer's own. Use only what `--services` names: a `services.md` record (export its env lines) or one connection URL. None given → skip tests that need services and record them under Coverage. Never start services yourself.
- **Probes** (scratch tests you write): keep them in `<S>/probes/`, copy one into the tree only to run it, remove it from the tree afterwards, and save its output next to it in `<S>/probes/`. A probe deletes every row it creates, or runs after all other tests; leftover data breaks later tests.

Never force-checkout, reset, stash, rebase, or merge to make this work. On an auth, network, or filesystem error, report it and stop rather than reviewing stale code. Leave worktrees in place; tell the user the path and that `git worktree remove <path>` cleans it up.
