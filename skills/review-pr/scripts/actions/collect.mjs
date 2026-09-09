import { recordCollection } from "../lib/collection/session.mjs";
import { selectPullRequest } from "../lib/collection/checkout.mjs";
import { synchronizeCollection } from "../lib/collection/synchronize.mjs";
import { existsSync } from "node:fs";
import { readContext } from "../lib/context.mjs";
import { checkoutIdentity, migrateLegacy, sessionLocation, withCollectionLock } from "../lib/session-location.mjs";
import {
  artifactRoot,
  refreshRemote,
  repositoryContext,
  resolveBase,
} from "../lib/git.mjs";
import {
  parsePullRequestTarget,
  pullRequestFingerprint,
} from "../lib/github.mjs";

function refreshRepository(cwd) {
  let repository = repositoryContext(cwd);

  refreshRemote({ root: repository.root });
  repository = repositoryContext(repository.root);
  return repository;
}

export function collect({ cwd, env, target: targetInput }) {
  const initialRepository = refreshRepository(cwd);
  const root = artifactRoot({
    root: initialRepository.root,
    env,
  });
  const target = parsePullRequestTarget(
    targetInput,
    initialRepository,
  );
  const perform = () => {
    const contextPath = sessionLocation({ root, repository: initialRepository, target });
    migrateLegacy({ root, repository: initialRepository, target, contextPath });
    const existing = existsSync(contextPath) ? readContext(contextPath) : null;
    if (existing?.passes.at(-1)?.status !== "complete" && existing?.passes.length) {
      throw new Error(`complete pass ${existing.passes.at(-1).number} before collecting another review; context: ${contextPath}`);
    }
    const selection = selectPullRequest({
      repository: initialRepository,
      root,
      target,
      contextPath,
      existing,
    });
    const synchronized = synchronizeCollection({
      repository: selection.repository,
      root,
      pullRequest: selection.pullRequest,
      checkout: selection.checkout,
    });
    const base = resolveBase({
      ...selection.repository,
      preferred: selection.pullRequest?.metadata.baseRefName,
      tip: synchronized.head,
    });
    const activityHash = pullRequestFingerprint(selection.pullRequest);
    const prepared = {
      repository: selection.repository,
      root,
      pullRequest: selection.pullRequest,
      base,
      activityHash,
      contextPath,
      checkout: selection.checkout,
      identity: target ? { repository: `${target.owner}/${target.repo}`, number: target.number, gitCommonDir: checkoutIdentity(initialRepository) } : null,
      ownedWorktrees: selection.ownedWorktrees,
      ...synchronized,
    };

    return recordCollection(prepared);
  };
  return target ? withCollectionLock({ root, repository: initialRepository }, perform) : perform();
}
