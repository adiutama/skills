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
  const branch = branchName || `detached-${git(["rev-parse", "--short", "HEAD"], root)}`;
  const remote = git(["remote", "get-url", "origin"], root, { allowFailure: true }) ?? "";
  const match = remote.match(/github\.com[:/]([^/]+)\/(.+)$/);
  const owner = match?.[1] ?? "_local";
  const repo = match?.[2]?.replace(/\.git$/, "") ?? basename(root);
  return { root, branch, detached, head, owner, repo };
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
  return git(["check-ignore", "-q", "--no-index", "--", `${normalized}/.review-change-ignore-check`], root, { allowFailure: true }) !== null;
}

export function slug(value) {
  return value.replace(/[^a-zA-Z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}

export function resolveBase({ root, branch, preferred }) {
  const configured = git(["config", "--get", `branch.${branch}.gh-merge-base`], root, { allowFailure: true });
  const originHead = git(["symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD"], root, { allowFailure: true });
  const remotePreferred = preferred && (preferred.startsWith("origin/") ? preferred : `origin/${preferred}`);
  const candidates = [remotePreferred, preferred, configured, originHead, "origin/main", "origin/develop", "origin/master", "origin/trunk", "main", "develop", "master", "trunk"];
  const ref = candidates.find((candidate) => candidate && git(["rev-parse", "--verify", "--quiet", `${candidate}^{commit}`], root, { allowFailure: true }) !== null);
  if (!ref) {
    throw new Error("could not resolve a base branch for the current change");
  }
  const sha = git(["merge-base", "HEAD", ref], root);
  return { ref, sha };
}

export function snapshotWorktree({ root, artifactDirectory }) {
  const temporary = mkdtempSync(join(tmpdir(), "review-change-index-"));
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
