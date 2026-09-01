import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { artifactRoot, commitTree, diffTrees, ensureCommit, fastForwardBranch, isAncestor, refreshRemote, remoteBranch, repositoryContext, resolveBase, slug, snapshotWorktree } from "./git.mjs";
import { collectPullRequest, pullRequestFingerprint } from "./github.mjs";
import { archiveContext, readContext, writeContext, writeJson } from "./context-store.mjs";
import { renderSeries } from "./render-series.mjs";

export function collect({ cwd, env }) {
  let repository = repositoryContext(cwd);
  refreshRemote({ root: repository.root });
  repository = repositoryContext(repository.root);
  const root = artifactRoot({ root: repository.root, env });
  const session = join(root, repository.owner, repository.repo, slug(repository.branch), "review-change");
  const contextPath = join(session, "context.json");
  let existing = existsSync(contextPath) ? readContext(contextPath) : null;
  const pending = existing?.passes.at(-1);
  if (pending && pending.status !== "complete") {
    throw new Error(`complete pass ${pending.number} before collecting another review`);
  }
  const pullRequest = collectPullRequest({
    cwd: repository.root,
    owner: repository.owner,
    repo: repository.repo,
    branch: repository.branch,
    detached: repository.detached,
  });
  let head = repository.head;
  let headTree = commitTree({ root: repository.root, commit: head });
  let tree = snapshotWorktree({ root: repository.root, artifactDirectory: root });
  let branchUpdate = null;
  let remoteSync = null;
  const remote = pullRequest
    ? { ref: `pull request #${pullRequest.metadata.number}`, sha: pullRequest.metadata.headRefOid }
    : remoteBranch(repository);
  if (pullRequest) ensureCommit({ root: repository.root, commit: remote.sha });
  if (remote) {
    if (tree !== headTree) {
      throw new Error(`remote sync stopped: the worktree has staged, unstaged, or untracked changes; commit or stash them before reviewing ${remote.ref}`);
    }
    if (repository.head !== remote.sha) {
      if (isAncestor({ root: repository.root, ancestor: repository.head, descendant: remote.sha })) {
        fastForwardBranch({ root: repository.root, commit: remote.sha });
        branchUpdate = { from: repository.head, to: remote.sha };
      } else if (isAncestor({ root: repository.root, ancestor: remote.sha, descendant: repository.head })) {
        throw new Error(`remote sync stopped: local HEAD ${repository.head} is ahead of ${remote.ref} ${remote.sha}; decide whether to push or restore the remote state, then rerun review-change`);
      } else {
        throw new Error(`remote sync stopped: local HEAD ${repository.head} has diverged from ${remote.ref} ${remote.sha}; reconcile the branch, then rerun review-change`);
      }
    }
    const synchronized = repositoryContext(repository.root);
    head = synchronized.head;
    headTree = commitTree({ root: repository.root, commit: remote.sha });
    tree = snapshotWorktree({ root: repository.root, artifactDirectory: root });
    if (head !== remote.sha || tree !== headTree) {
      throw new Error(`remote sync verification failed: the checked-out tree does not exactly match ${remote.ref} ${remote.sha}; inspect git status and decide how to proceed`);
    }
    remoteSync = {
      ref: remote.ref,
      before: repository.head,
      head,
      status: branchUpdate ? "fast-forwarded" : "current",
    };
  }
  const base = resolveBase({ ...repository, preferred: pullRequest?.metadata.baseRefName, tip: head });
  const activityHash = pullRequestFingerprint(pullRequest);
  if (existing) {
    const last = existing.passes.at(-1);
    let reason = null;
    if (existing.change.baseSha && existing.change.baseSha !== base.sha) {
      reason = "base-changed";
    } else if (last?.head && !isAncestor({ root: repository.root, ancestor: last.head, descendant: head })) {
      reason = "history-rewritten";
    }
    if (reason) {
      archiveContext(contextPath, existing, reason);
      existing = null;
    }
  }
  const previous = existing?.passes.at(-1);

  const codeChanged = !previous || previous.tree !== tree;
  const activityChanged = previous ? previous.activityHash !== activityHash : Boolean(pullRequest);
  if (previous && !codeChanged && !activityChanged) {
    existing.remoteSync = remoteSync;
    writeContext(contextPath, existing);
    return {
      status: "unchanged",
      context: contextPath,
      summary: existing.summary?.report ?? null,
      report: previous.report ?? null,
      index: existing.index ?? null,
      pass: previous.number,
      branchUpdate,
      remoteSync,
    };
  }

  const pass = previous ? previous.number + 1 : 1;
  const label = String(pass).padStart(2, "0");
  const diff = join(session, `${label}.diff`);
  const activity = pullRequest ? join(session, `${label}.activity.json`) : null;
  const review = join(session, `${label}.review.json`);
  const summary = join(session, "summary.json");
  const summaryReport = join(session, "summary.html");
  const kind = previous ? "incremental" : "full";
  const from = previous?.tree ?? base.sha;
  const patch = codeChanged ? diffTrees({ root: repository.root, from, to: tree }) : "";
  if (!previous && !patch) throw new Error("nothing to review: the current change is empty");

  mkdirSync(session, { recursive: true });
  writeFileSync(diff, patch);
  if (activity) writeJson(activity, pullRequest);
  const context = existing ?? {
    version: 2,
    passes: [],
  };
  context.version = 2;
  context.remoteSync = remoteSync;
  context.change = {
    mode: pullRequest ? "pr" : "local",
    pullRequest: pullRequest?.metadata.number ?? null,
    repository: `${repository.owner}/${repository.repo}`,
    branch: repository.branch,
    base: base.ref,
    baseSha: base.sha,
    head,
  };
  delete context.sources;
  context.summary ??= { data: summary, report: summaryReport, study: null };
  context.passes.push({
    number: pass,
    kind,
    diff,
    activity,
    review,
    head,
    headTree,
    pullRequestHead: pullRequest?.metadata.headRefOid ?? null,
    tree,
    activityHash,
    changes: { code: codeChanged, activity: activityChanged },
    branchUpdate,
    remoteSync,
    status: "collected",
  });
  context.output = review;
  writeContext(contextPath, context);
  const presentationExists = (context.index && existsSync(context.index)) || existsSync(context.summary.report);
  if (previous && presentationExists) {
    renderSeries({ context });
    writeContext(contextPath, context);
  }
  return { status: "ready", context: contextPath, diff, activity, summary: context.summary.data, review, branchUpdate, remoteSync };
}
