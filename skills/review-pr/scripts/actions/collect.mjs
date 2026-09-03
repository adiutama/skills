import { recordCollection } from "../lib/collection/session.mjs";
import { selectPullRequest } from "../lib/collection/checkout.mjs";
import { synchronizeCollection } from "../lib/collection/synchronize.mjs";
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
  const selection = selectPullRequest({
    repository: initialRepository,
    root,
    target,
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
    ...synchronized,
  };

  return recordCollection(prepared);
}
