import { createHash } from "node:crypto";
import { cpSync, existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, realpathSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { git, slug } from "./git.mjs";

export function checkoutIdentity(repository) {
  return realpathSync(resolve(repository.root, git(["rev-parse", "--git-common-dir"], repository.root)));
}

export function cloneKey(repository) {
  return createHash("sha256").update(checkoutIdentity(repository)).digest("hex").slice(0, 16);
}

export function contextCandidates(root, repository) {
  const directory = join(root, repository.owner, repository.repo);
  if (!existsSync(directory)) return [];
  return readdirSync(directory, { withFileTypes: true }).filter((entry) => entry.isDirectory()).flatMap((entry) => {
    const path = join(directory, entry.name, "review-pr", "context.json");
    if (!existsSync(path)) return [];
    const context = JSON.parse(readFileSync(path, "utf8"));
    return [{ path, context }];
  });
}

export function sessionLocation({ root, repository, target }) {
  const scope = target ? `pr-${target.number}-${cloneKey(repository)}` : slug(repository.branch);
  return join(root, repository.owner, repository.repo, scope, "review-pr", "context.json");
}

// Copy a single identifiable legacy series; never move or overwrite its files.
export function migrateLegacy({ root, repository, target, contextPath }) {
  if (!target || existsSync(contextPath)) return;
  const candidates = contextCandidates(root, repository).filter(({ context }) =>
    !context.identity && context.change?.mode === "pr"
    && context.change.repository.toLowerCase() === `${target.owner}/${target.repo}`.toLowerCase()
    && context.change.pullRequest === target.number);
  if (candidates.length > 1) throw new Error("multiple legacy reviews match this PR; select and resolve the legacy series before collecting");
  if (!candidates.length) return;
  const previous = candidates[0];
  const oldDirectory = dirname(previous.path);
  const directory = dirname(contextPath);
  mkdirSync(dirname(directory), { recursive: true });
  const staging = mkdtempSync(join(dirname(directory), ".migration-"));
  function relocateFields(object, keys) {
    for (const key of keys) {
      const value = object?.[key];
      if (typeof value === "string" && value.startsWith(`${oldDirectory}/`)) object[key] = directory + value.slice(oldDirectory.length);
    }
  }
  function rewriteJson(folder) {
    for (const entry of readdirSync(folder, { withFileTypes: true })) {
      const path = join(folder, entry.name);
      if (entry.isDirectory()) rewriteJson(path);
      else if (entry.name === "context.json") {
        const context = JSON.parse(readFileSync(path, "utf8"));
        relocateFields(context, ["output", "index", "contextPath"]);
        relocateFields(context.summary, ["data", "report"]);
        relocateFields(context.sources, Object.keys(context.sources ?? {}));
        for (const pass of context.passes ?? []) relocateFields(pass, ["diff", "activity", "review", "report"]);
        writeFileSync(path, `${JSON.stringify(context, null, 2)}\n`);
      }
    }
  }
  try {
    cpSync(oldDirectory, staging, { recursive: true, errorOnExist: true, force: false });
    rewriteJson(staging);
    renameSync(staging, directory);
  } finally { rmSync(staging, { recursive: true, force: true }); }
}

// Serialize checkout/session changes in one Git clone, including linked worktrees.
export function withCollectionLock({ root, repository }, action) {
  const directory = join(root, ".review-pr-locks");
  mkdirSync(directory, { recursive: true });
  const lock = join(directory, `${cloneKey(repository)}.lock`);
  try { mkdirSync(lock); } catch (error) {
    if (error.code !== "EEXIST") throw error;
    throw new Error(`another collection owns ${lock}; if it was interrupted, verify it stopped before removing that lock`);
  }
  try { return action(); } finally { rmSync(lock, { recursive: true }); }
}
