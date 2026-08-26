import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { artifactRoot, commitTree, diffTrees, ensureCommit, fastForwardBranch, isAncestor, repositoryContext, resolveBase, slug, snapshotWorktree } from "./git.mjs";
import { collectPullRequest, pullRequestFingerprint } from "./github.mjs";
import { archiveContext, readContext, writeContext, writeJson } from "./context-store.mjs";
import { renderSeries } from "./render-series.mjs";

export function collect({ cwd, env }) {
  const repository = repositoryContext(cwd);
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
    number: existing?.change.pullRequest,
    required: existing?.change.mode === "pr",
  });
  let head = repository.head;
  let headTree = commitTree({ root: repository.root, commit: head });
  let tree = snapshotWorktree({ root: repository.root, artifactDirectory: root });
  let branchUpdate = null;
  let shouldFastForward = false;
  if (pullRequest && tree === headTree) {
    head = pullRequest.metadata.headRefOid;
    ensureCommit({ root: repository.root, commit: head });
    shouldFastForward = repository.head !== head && isAncestor({ root: repository.root, ancestor: repository.head, descendant: head });
    headTree = commitTree({ root: repository.root, commit: head });
    tree = headTree;
  }
  const base = resolveBase({ ...repository, preferred: pullRequest?.metadata.baseRefName, tip: head });
  if (shouldFastForward) {
    fastForwardBranch({ root: repository.root, commit: head });
    branchUpdate = { from: repository.head, to: head };
  }
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
    return {
      status: "unchanged",
      context: contextPath,
      summary: existing.summary?.report ?? null,
      report: previous.report ?? null,
      index: existing.index ?? null,
      pass: previous.number,
      branchUpdate,
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
    status: "collected",
  });
  context.output = review;
  writeContext(contextPath, context);
  if (previous) {
    renderSeries({ context });
    writeContext(contextPath, context);
  }
  return { status: "ready", context: contextPath, diff, activity, summary: context.summary.data, review, branchUpdate };
}
