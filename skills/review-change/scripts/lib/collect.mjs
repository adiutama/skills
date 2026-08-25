import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { artifactRoot, diffTrees, isAncestor, repositoryContext, resolveBase, slug, snapshotWorktree } from "./git.mjs";
import { collectPullRequest, pullRequestFingerprint } from "./github.mjs";
import { archiveContext, readContext, writeContext, writeJson } from "./context-store.mjs";

export function collect({ cwd, env }) {
  const repository = repositoryContext(cwd);
  const root = artifactRoot({ root: repository.root, env });
  const session = join(root, repository.owner, repository.repo, slug(repository.branch), "review-change");
  const contextPath = join(session, "context.json");
  let existing = existsSync(contextPath) ? readContext(contextPath) : null;
  const pending = existing?.passes.at(-1);
  if (pending?.status === "pending") {
    throw new Error(`render pending pass ${pending.number} before collecting another review`);
  }
  const pullRequest = collectPullRequest({
    cwd: repository.root,
    owner: repository.owner,
    repo: repository.repo,
    number: existing?.change.pullRequest,
    required: existing?.change.mode === "pr",
  });
  const base = resolveBase({ ...repository, preferred: pullRequest?.metadata.baseRefName });
  const tree = snapshotWorktree({ root: repository.root, artifactDirectory: root });
  const activityHash = pullRequestFingerprint(pullRequest);
  if (existing) {
    const last = existing.passes.at(-1);
    let reason = null;
    if (existing.change.baseSha && existing.change.baseSha !== base.sha) {
      reason = "base-changed";
    } else if (last?.head && !isAncestor({ root: repository.root, ancestor: last.head, descendant: repository.head })) {
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
    return { status: "unchanged", context: contextPath, pass: previous.number };
  }

  const pass = previous ? previous.number + 1 : 1;
  const label = String(pass).padStart(2, "0");
  const diff = join(session, `${label}.diff`);
  const activity = pullRequest ? join(session, `${label}.activity.json`) : null;
  const review = join(session, `${label}.review.json`);
  const kind = previous ? "incremental" : "full";
  const from = previous?.tree ?? base.sha;
  const patch = codeChanged ? diffTrees({ root: repository.root, from, to: tree }) : "";
  if (!previous && !patch && !pullRequest) throw new Error("nothing to review: the current change is empty");

  mkdirSync(session, { recursive: true });
  writeFileSync(diff, patch);
  if (activity) writeJson(activity, pullRequest);
  const context = existing ?? {
    version: 1,
    passes: [],
  };
  context.change = {
    mode: pullRequest ? "pr" : "local",
    pullRequest: pullRequest?.metadata.number ?? null,
    repository: `${repository.owner}/${repository.repo}`,
    branch: repository.branch,
    base: base.ref,
    baseSha: base.sha,
    head: repository.head,
  };
  delete context.sources;
  context.passes.push({
    number: pass,
    kind,
    diff,
    activity,
    review,
    head: repository.head,
    tree,
    activityHash,
    changes: { code: codeChanged, activity: activityChanged },
    status: "pending",
  });
  context.output = review;
  writeContext(contextPath, context);
  return { status: "ready", context: contextPath, diff, activity, review };
}
