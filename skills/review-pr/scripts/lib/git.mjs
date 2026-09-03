import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, isAbsolute, join, relative, resolve, sep } from "node:path";
import { run } from "./command.mjs";

function git(args, cwd, options = {}) {
  return run("git", args, { cwd, ...options });
}

export function repositoryContext(cwd) {
  const root = git(["rev-parse", "--show-toplevel"], cwd);
  const branchName = git(["branch", "--show-current"], root);
  const head = git(["rev-parse", "HEAD"], root);
  const detached = !branchName;
  const detachedName = branchName
    ? null
    : git(["rev-parse", "--short", "HEAD"], root);
  const branch = branchName || `detached-${detachedName}`;
  const remote = git(
    ["config", "--get", "remote.origin.url"],
    root,
    { allowFailure: true },
  ) ?? "";
  const match = remote.match(/github\.com[:/]([^/]+)\/(.+)$/);
  const owner = match?.[1] ?? "_local";
  const repo = match?.[2]?.replace(/\.git$/, "") ?? basename(root);
  return { root, branch, detached, head, owner, repo };
}

export function refreshRemote({ root }) {
  const origin = git(["remote", "get-url", "origin"], root, { allowFailure: true });
  if (!origin) return false;
  git(["fetch", "--no-tags", "--prune", "origin"], root);
  return true;
}

export function remoteBranch({ root, branch, detached = false }) {
  let configured;
  let ref;

  if (detached) return null;
  configured = git(
    ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"],
    root,
    { allowFailure: true },
  );
  const candidates = [configured, `origin/${branch}`];
  ref = candidates.find((candidate) => {
    if (!candidate) return false;
    return git(
      ["rev-parse", "--verify", "--quiet", `${candidate}^{commit}`],
      root,
      { allowFailure: true },
    ) !== null;
  });
  if (!ref) return null;
  return { ref, sha: git(["rev-parse", `${ref}^{commit}`], root) };
}

export function artifactRoot({ root, env }) {
  if (env.AGENTS_ARTIFACTS_ROOT) {
    if (!isAbsolute(env.AGENTS_ARTIFACTS_ROOT)) throw new Error("AGENTS_ARTIFACTS_ROOT must be an absolute path");
    return resolve(root, env.AGENTS_ARTIFACTS_ROOT);
  }
  const local = ignoredPath({ root, path: ".agents/artifacts" })
    || ignoredPath({ root, path: ".agents" });
  return local ? join(root, ".agents", "artifacts") : join(env.HOME, ".agents", "artifacts");
}

function ignoredPath({ root, path }) {
  const normalized = path.replaceAll(sep, "/").replace(/\/+$/, "");
  const marker = `${normalized}/.review-pr-ignore-check`;

  return git(
    ["check-ignore", "-q", "--no-index", "--", marker],
    root,
    { allowFailure: true },
  ) !== null;
}

export function slug(value) {
  return value.replace(/[^a-zA-Z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}

export function resolveBase({ root, branch, preferred, tip }) {
  const configured = git(
    ["config", "--get", `branch.${branch}.gh-merge-base`],
    root,
    { allowFailure: true },
  );
  const originHead = git(
    ["symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD"],
    root,
    { allowFailure: true },
  );
  const remotePreferred = preferred && (
    preferred.startsWith("origin/")
      ? preferred
      : `origin/${preferred}`
  );
  const candidates = [
    remotePreferred,
    preferred,
    configured,
    originHead,
    "origin/main",
    "origin/develop",
    "origin/master",
    "origin/trunk",
    "main",
    "develop",
    "master",
    "trunk",
  ];
  const ref = candidates.find((candidate) => {
    if (!candidate) return false;
    return git(
      ["rev-parse", "--verify", "--quiet", `${candidate}^{commit}`],
      root,
      { allowFailure: true },
    ) !== null;
  });
  if (!ref) {
    throw new Error("could not resolve a base branch for the current change");
  }
  const sha = git(["merge-base", tip, ref], root);
  return { ref, sha };
}

export function hasCommit({ root, commit }) {
  return git(["cat-file", "-e", `${commit}^{commit}`], root, { allowFailure: true }) !== null;
}

export function ensureCommit({ root, commit }) {
  if (hasCommit({ root, commit })) return;
  git(["fetch", "--no-tags", "origin", commit], root);
  if (!hasCommit({ root, commit })) throw new Error(`could not fetch pull request HEAD ${commit}`);
}

export function fetchPullRequestHead({ root, number, commit }) {
  let fetched;
  let message;

  git(["fetch", "--no-tags", "origin", `refs/pull/${number}/head`], root);
  fetched = git(["rev-parse", "FETCH_HEAD^{commit}"], root);
  message = [
    `pull request #${number} moved while collecting: GitHub reported ${commit},`,
    `but fetch returned ${fetched}; rerun review-pr`,
  ].join(" ");
  if (fetched !== commit) {
    throw new Error(message);
  }
}

export function checkoutPullRequest({ root, number, commit }) {
  git(["switch", "-C", `pr/${number}`, commit], root);
}

export function fastForwardBranch({ root, commit }) {
  git(["merge", "--ff-only", commit], root);
}

export function snapshotWorktree({ root, artifactDirectory }) {
  const temporary = mkdtempSync(join(tmpdir(), "review-pr-index-"));
  const index = join(temporary, "index");
  const env = { ...process.env, GIT_INDEX_FILE: index };
  try {
    git(["read-tree", "HEAD"], root, { env });
    const pathspecs = ["."];
    const artifactRelative = relative(root, artifactDirectory);
    if (artifactRelative && !artifactRelative.startsWith(`..${sep}`) && artifactRelative !== "..") {
      if (!ignoredPath({ root, path: artifactRelative })) {
        pathspecs.push(`:(top,exclude)${artifactRelative.replaceAll(sep, "/")}/**`);
      }
    } else if (!ignoredPath({ root, path: ".agents/artifacts" })) {
      pathspecs.push(":(top,exclude).agents/artifacts/**");
    }
    git(["add", "-A", "--", ...pathspecs], root, { env });
    return git(["write-tree"], root, { env });
  } finally {
    rmSync(temporary, { recursive: true, force: true });
  }
}

export function commitTree({ root, commit }) {
  return git(["rev-parse", `${commit}^{tree}`], root);
}

export function diffTrees({ root, from, to }) {
  return git(["diff", "--binary", "--find-renames", from, to], root);
}

export function isAncestor({ root, ancestor, descendant }) {
  return git(["merge-base", "--is-ancestor", ancestor, descendant], root, { allowFailure: true }) !== null;
}
