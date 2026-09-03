import {
  commitTree,
  ensureCommit,
  fastForwardBranch,
  isAncestor,
  remoteBranch,
  repositoryContext,
  snapshotWorktree,
} from "../git.mjs";

function remoteTarget(repository, pullRequest) {
  if (pullRequest) {
    return {
      ref: `pull request #${pullRequest.metadata.number}`,
      sha: pullRequest.metadata.headRefOid,
    };
  }

  return remoteBranch(repository);
}

function assertCleanWorktree({ repository, root, remote }) {
  const headTree = commitTree({
    root: repository.root,
    commit: repository.head,
  });
  const tree = snapshotWorktree({
    root: repository.root,
    artifactDirectory: root,
  });
  const message = [
    "remote sync stopped: the worktree has staged, unstaged, or untracked",
    `changes; commit or stash them before reviewing ${remote.ref}`,
  ].join(" ");

  if (tree === headTree) return;
  throw new Error(message);
}

function synchronizeHead(repository, remote) {
  const localHead = repository.head;
  const remoteHead = remote.sha;
  const aheadMessage = [
    `remote sync stopped: local HEAD ${localHead} is ahead of`,
    `${remote.ref} ${remoteHead}; decide whether to push or restore`,
    "the remote state, then rerun review-pr",
  ].join(" ");
  const divergedMessage = [
    `remote sync stopped: local HEAD ${localHead} has diverged from`,
    `${remote.ref} ${remoteHead}; reconcile the branch, then rerun review-pr`,
  ].join(" ");

  if (localHead === remoteHead) return null;
  if (isAncestor({
    root: repository.root,
    ancestor: localHead,
    descendant: remoteHead,
  })) {
    fastForwardBranch({
      root: repository.root,
      commit: remoteHead,
    });
    return { from: localHead, to: remoteHead };
  }
  if (isAncestor({
    root: repository.root,
    ancestor: remoteHead,
    descendant: localHead,
  })) {
    throw new Error(aheadMessage);
  }
  throw new Error(divergedMessage);
}

function verifyCheckout({ repository, root, remote }) {
  const synchronized = repositoryContext(repository.root);
  const head = synchronized.head;
  const headTree = commitTree({
    root: repository.root,
    commit: remote.sha,
  });
  const tree = snapshotWorktree({
    root: repository.root,
    artifactDirectory: root,
  });
  const message = [
    "remote sync verification failed: the checked-out tree does not exactly",
    `match ${remote.ref} ${remote.sha}; inspect git status and decide how to proceed`,
  ].join(" ");

  if (head !== remote.sha || tree !== headTree) {
    throw new Error(message);
  }

  return { head, headTree, tree };
}

function synchronizationStatus(checkout, branchUpdate) {
  if (checkout?.switched) return "checked-out";
  if (branchUpdate) return "fast-forwarded";
  return "current";
}

function localCollection(repository, root, branchUpdate) {
  const head = repository.head;
  const headTree = commitTree({
    root: repository.root,
    commit: head,
  });
  const tree = snapshotWorktree({
    root: repository.root,
    artifactDirectory: root,
  });

  return {
    head,
    headTree,
    tree,
    branchUpdate,
    remoteSync: null,
  };
}

export function synchronizeCollection({
  repository,
  root,
  pullRequest,
  checkout,
}) {
  const remote = remoteTarget(repository, pullRequest);
  const initialHead = repository.head;
  let branchUpdate = checkout?.headChanged
    ? { from: checkout.before, to: initialHead }
    : null;
  let verified;

  if (!remote) {
    return localCollection(repository, root, branchUpdate);
  }
  if (pullRequest) {
    ensureCommit({
      root: repository.root,
      commit: remote.sha,
    });
  }
  assertCleanWorktree({ repository, root, remote });
  branchUpdate ??= synchronizeHead(repository, remote);
  verified = verifyCheckout({ repository, root, remote });

  return {
    ...verified,
    branchUpdate,
    remoteSync: {
      ref: remote.ref,
      before: checkout?.before ?? initialHead,
      head: verified.head,
      status: synchronizationStatus(checkout, branchUpdate),
    },
  };
}
