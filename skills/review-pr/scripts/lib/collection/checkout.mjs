import { createHash } from "node:crypto";
import { existsSync, mkdirSync, mkdtempSync, realpathSync } from "node:fs";
import { dirname, join } from "node:path";
import {
  cleanWorktree, fetchPullRequestHead, git, isAncestor, repositoryContext,
} from "../git.mjs";
import { collectPullRequest } from "../github.mjs";
import { contextCandidates } from "../session-location.mjs";
import { readJson, writeJson } from "../context.mjs";

function remoteIdentity(url) {
  const match = url?.match(/^(?:https:\/\/github\.com\/|git@github\.com:|ssh:\/\/git@github\.com\/)([^/]+)\/([^/]+?)(?:\.git)?\/?$/);
  return match ? `${match[1]}/${match[2]}`.toLowerCase() : null;
}

function sourceIdentity(metadata, target) {
  if (metadata.isCrossRepository === false) return `${target.owner}/${target.repo}`.toLowerCase();
  const owner = metadata.headRepositoryOwner?.login;
  const repo = metadata.headRepository?.name;
  return /^[a-zA-Z0-9_.-]+$/.test(owner ?? "") && /^[a-zA-Z0-9_.-]+$/.test(repo ?? "") ? `${owner}/${repo}`.toLowerCase() : null;
}

function worktrees(root) {
  const entries = [];
  for (const field of git(["worktree", "list", "--porcelain", "-z"], root).split("\0")) {
    if (field.startsWith("worktree ")) entries.push({ path: field.slice(9), branch: null });
    if (field.startsWith("branch ")) entries.at(-1).branch = field.slice(7).replace(/^refs\/heads\//, "");
  }
  return entries;
}

function config(root, key) {
  return git(["config", "--get", key], root, { allowFailure: true });
}

function associated({ root, branch, source, metadata }) {
  const remote = config(root, `branch.${branch}.remote`);
  const merge = config(root, `branch.${branch}.merge`);
  if (remote || merge) {
    return source !== null && remoteIdentity(config(root, `remote.${remote}.url`)) === source
      && merge === `refs/heads/${metadata.headRefName}`;
  }
  if (config(root, `branch.${branch}.review-pr-url`) === metadata.url) return true;
  // A matching name is only a candidate. Confirm its same-repository remote ref.
  return source !== null && branch === metadata.headRefName
    && remoteIdentity(config(root, "remote.origin.url")) === source
    && git(["rev-parse", "--verify", `refs/remotes/origin/${branch}^{commit}`], root, { allowFailure: true }) === metadata.headRefOid;
}

function chooseBranch({ root, metadata, source, checkoutPath, entries }) {
  const preferred = metadata.headRefName;
  if (!preferred || preferred.startsWith("-") || preferred === "HEAD"
    || git(["check-ref-format", `refs/heads/${preferred}`], root, { allowFailure: true }) === null) {
    throw new Error("GitHub returned an invalid PR source branch name");
  }
  function state(branch) {
    const refs = git(["for-each-ref", "--format=%(refname)", "refs/heads/"], root).split("\n");
    const ref = `refs/heads/${branch}`;
    if (refs.some((existing) => existing.startsWith(`${ref}/`) || ref.startsWith(`${existing}/`))) return { reason: "branch-name-conflict" };
    const tip = git(["rev-parse", "--verify", `refs/heads/${branch}^{commit}`], root, { allowFailure: true });
    if (!tip) return { branch, create: true };
    if (entries.some((entry) => entry.branch === branch && entry.path !== checkoutPath)) return { reason: "branch-in-another-worktree" };
    if (!associated({ root, branch, source, metadata })) return { reason: "branch-name-conflict" };
    if (tip === metadata.headRefOid || isAncestor({ root, ancestor: tip, descendant: metadata.headRefOid })) return { branch, create: false };
    return { reason: "branch-has-local-commits" };
  }
  const selected = state(preferred);
  if (selected.branch) return { ...selected, reason: null };
  const stem = git(["show-ref", "--verify", "--quiet", "refs/heads/review"], root, { allowFailure: true }) !== null
    ? `review-pr-${metadata.number}` : `review/pr-${metadata.number}`;
  for (let index = 1; index <= 1000; index += 1) {
    const candidate = state(`${stem}${index === 1 ? "" : `-${index}`}`);
    if (candidate.branch) return { ...candidate, reason: selected.reason };
  }
  throw new Error("could not allocate an unused review branch after 1000 candidates");
}

function configureTracking({ root, branch, source, metadata }) {
  git(["config", `branch.${branch}.review-pr-url`, metadata.url], root);
  if (!source) return false; // Deleted/inaccessible fork metadata: PR ref still identifies the snapshot.
  const remotes = git(["remote"], root).split("\n").filter(Boolean);
  let remote = remotes.find((name) => remoteIdentity(config(root, `remote.${name}.url`)) === source);
  if (!remote) {
    const stem = `review-pr-${createHash("sha256").update(source).digest("hex").slice(0, 12)}`;
    remote = stem;
    for (let index = 2; remotes.includes(remote); index += 1) remote = `${stem}-${index}`;
    git(["remote", "add", remote, `https://github.com/${source}.git`], root);
  }
  // Fetching the verified PR ref suffices; a second fork fetch may be inaccessible.
  git(["config", `branch.${branch}.remote`, remote], root);
  git(["config", `branch.${branch}.merge`, `refs/heads/${metadata.headRefName}`], root);
  return true;
}

function verifiedPullRequest(repository, target) {
  for (let attempt = 0; attempt < 2; attempt += 1) {
    const pullRequest = collectPullRequest({ cwd: repository.root, ...target, required: true });
    if (pullRequest.metadata.number !== target.number || !/^[a-f0-9]{40,64}$/i.test(pullRequest.metadata.headRefOid)) {
      throw new Error("GitHub returned a mismatched PR identity or invalid head commit");
    }
    try {
      fetchPullRequestHead({ root: repository.root, number: target.number, commit: pullRequest.metadata.headRefOid });
      // Read again before touching branches: metadata and the fetched ref must agree.
      const latest = collectPullRequest({ cwd: repository.root, ...target, required: true });
      if (latest.metadata.headRefOid === pullRequest.metadata.headRefOid
        && latest.metadata.headRefName === pullRequest.metadata.headRefName
        && sourceIdentity(latest.metadata, target) === sourceIdentity(pullRequest.metadata, target)) return latest;
    } catch (error) {
      if (error.code !== "PR_HEAD_MOVED") throw error;
    }
  }
  throw new Error("PR moved during both collection attempts; rerun review-pr when its head is stable");
}

export function selectPullRequest({ repository, root, target, contextPath, existing }) {
  if (!target) return {
    repository,
    pullRequest: collectPullRequest({ cwd: repository.root, owner: repository.owner, repo: repository.repo, branch: repository.branch, detached: repository.detached }),
    checkout: null,
  };
  if (`${target.owner}/${target.repo}`.toLowerCase() !== `${repository.owner}/${repository.repo}`.toLowerCase()) {
    throw new Error(`pull request ${target.owner}/${target.repo}#${target.number} does not belong to the current repository ${repository.owner}/${repository.repo}`);
  }
  const pullRequest = verifiedPullRequest(repository, target);
  const metadata = pullRequest.metadata;
  const source = sourceIdentity(metadata, target);
  const entries = worktrees(repository.root);
  const originalPath = realpathSync(repository.root);
  const dirty = !cleanWorktree({ root: originalPath, artifactDirectory: root });
  const occupiedReview = contextCandidates(root, repository).some(({ path, context }) => path !== contextPath
    && context.checkout?.path === originalPath && context.passes?.at(-1)?.status !== "complete");
  let checkoutPath = originalPath;
  let createdWorktree = false;
  const ownershipPath = join(dirname(contextPath), "worktrees.json");
  const ownedWorktrees = existsSync(ownershipPath) ? readJson(ownershipPath) : existing?.ownedWorktrees ?? [];
  const reason = dirty ? "dirty-worktree" : occupiedReview ? "active-review-in-worktree" : null;
  if (reason) {
    const reusable = [...ownedWorktrees].reverse().find((path) => existsSync(path) && entries.some((entry) => entry.path === path)
      && cleanWorktree({ root: path, artifactDirectory: root }));
    if (reusable) checkoutPath = reusable;
    else {
      const parent = join(dirname(contextPath), "worktrees");
      mkdirSync(parent, { recursive: true });
      checkoutPath = realpathSync(mkdtempSync(join(parent, "review-")));
      createdWorktree = true;
      ownedWorktrees.push(checkoutPath);
      // Record ownership before Git mutation, even if a later verification fails.
      writeJson(ownershipPath, ownedWorktrees);
    }
  }
  const branch = chooseBranch({ root: repository.root, metadata, source, checkoutPath, entries });
  const before = createdWorktree ? repository.head : repositoryContext(checkoutPath).head;
  if (createdWorktree) {
    git(["worktree", "add", ...(branch.create ? ["-b", branch.branch, checkoutPath, metadata.headRefOid] : [checkoutPath, branch.branch])], repository.root);
  } else {
    // Recheck immediately before mutation; do not carry local changes between branches.
    if (!cleanWorktree({ root: checkoutPath, artifactDirectory: root })) throw new Error("checkout became dirty during collection; rerun review-pr");
    git(["switch", ...(branch.create ? ["--no-track", "-c", branch.branch, metadata.headRefOid] : [branch.branch])], checkoutPath);
  }
  const tip = repositoryContext(checkoutPath).head;
  if (tip !== metadata.headRefOid) {
    if (!isAncestor({ root: checkoutPath, ancestor: tip, descendant: metadata.headRefOid })) throw new Error("review branch changed during checkout; its commits were preserved");
    git(["merge", "--ff-only", metadata.headRefOid], checkoutPath);
  }
  const trackingConfigured = configureTracking({ root: checkoutPath, branch: branch.branch, source, metadata });
  const selected = repositoryContext(checkoutPath);
  return {
    repository: selected,
    pullRequest,
    ownedWorktrees,
    checkout: {
      path: checkoutPath, originalPath, branch: selected.branch,
      kind: checkoutPath === originalPath ? "current-worktree" : "separate-worktree",
      reason: reason || branch.reason, branchReason: branch.reason,
      createdWorktree, trackingConfigured,
      before, headChanged: before !== selected.head,
      switched: checkoutPath !== originalPath || repository.branch !== selected.branch || before !== selected.head,
    },
  };
}
