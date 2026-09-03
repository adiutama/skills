import {
  checkoutPullRequest,
  commitTree,
  fetchPullRequestHead,
  repositoryContext,
  snapshotWorktree,
} from "../git.mjs";
import { collectPullRequest } from "../github.mjs";

function sameRepository(target, repository) {
  const targetOwner = target.owner.toLowerCase();
  const targetRepo = target.repo.toLowerCase();
  const localOwner = repository.owner.toLowerCase();
  const localRepo = repository.repo.toLowerCase();

  return targetOwner === localOwner && targetRepo === localRepo;
}

function assertTargetRepository(target, repository) {
  const targetName = `${target.owner}/${target.repo}#${target.number}`;
  const repositoryName = `${repository.owner}/${repository.repo}`;

  if (sameRepository(target, repository)) return;
  throw new Error(
    `pull request ${targetName} does not belong to the current repository ${repositoryName}`,
  );
}

function assertCleanWorktree(repository, root, target) {
  const headTree = commitTree({
    root: repository.root,
    commit: repository.head,
  });
  const worktreeTree = snapshotWorktree({
    root: repository.root,
    artifactDirectory: root,
  });
  const message = [
    "pull request checkout stopped: the worktree has staged, unstaged,",
    "or untracked changes; commit or stash them before reviewing",
    `pull request #${target.number}`,
  ].join(" ");

  if (worktreeTree === headTree) return;
  throw new Error(message);
}

function collectExplicitPullRequest(repository, target) {
  return collectPullRequest({
    cwd: repository.root,
    owner: target.owner,
    repo: target.repo,
    number: target.number,
    required: true,
  });
}

function checkoutExplicitPullRequest({ repository, root, target }) {
  const pullRequest = collectExplicitPullRequest(repository, target);
  const before = repository.head;
  const branchBefore = repository.branch;
  const head = pullRequest.metadata.headRefOid;
  let checkedOutRepository;

  assertTargetRepository(target, repository);
  assertCleanWorktree(repository, root, target);
  fetchPullRequestHead({
    root: repository.root,
    number: target.number,
    commit: head,
  });
  checkoutPullRequest({
    root: repository.root,
    number: target.number,
    commit: head,
  });
  checkedOutRepository = repositoryContext(repository.root);

  return {
    repository: checkedOutRepository,
    pullRequest,
    checkout: {
      before,
      headChanged: before !== checkedOutRepository.head,
      switched: branchBefore !== checkedOutRepository.branch
        || before !== checkedOutRepository.head,
    },
  };
}

function collectCurrentPullRequest(repository) {
  return collectPullRequest({
    cwd: repository.root,
    owner: repository.owner,
    repo: repository.repo,
    branch: repository.branch,
    detached: repository.detached,
  });
}

export function selectPullRequest({ repository, root, target }) {
  if (target) {
    return checkoutExplicitPullRequest({
      repository,
      root,
      target,
    });
  }

  return {
    repository,
    pullRequest: collectCurrentPullRequest(repository),
    checkout: null,
  };
}
