import {
  existsSync,
  mkdirSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";
import {
  archiveContext,
  readContext,
  writeContext,
  writeJson,
} from "../context.mjs";
import {
  diffTrees,
  isAncestor,
  slug,
} from "../git.mjs";
import { renderSeries } from "../presentation/series.mjs";

function sessionPaths(prepared) {
  const { repository, root } = prepared;
  const session = join(
    root,
    repository.owner,
    repository.repo,
    slug(repository.branch),
    "review-pr",
  );

  return {
    session,
    context: join(session, "context.json"),
  };
}

function loadSession(prepared) {
  const paths = sessionPaths(prepared);
  const existing = existsSync(paths.context)
    ? readContext(paths.context)
    : null;
  const pending = existing?.passes.at(-1);

  if (pending && pending.status !== "complete") {
    throw new Error(`complete pass ${pending.number} before collecting another review`);
  }

  return { ...paths, existing };
}

function invalidHistoryReason(prepared, existing) {
  const previous = existing.passes.at(-1);
  const baseChanged = existing.change.baseSha
    && existing.change.baseSha !== prepared.base.sha;
  const historyRewritten = previous?.head
    && !isAncestor({
      root: prepared.repository.root,
      ancestor: previous.head,
      descendant: prepared.head,
    });

  if (baseChanged) return "base-changed";
  if (historyRewritten) return "history-rewritten";
  return null;
}

function reconcileHistory(prepared, session) {
  const { existing } = session;
  let reason;

  if (!existing) return null;
  reason = invalidHistoryReason(prepared, existing);
  if (!reason) return existing;
  archiveContext(session.context, existing, reason);
  return null;
}

function collectionChanges(prepared, previous) {
  return {
    code: !previous || previous.tree !== prepared.tree,
    activity: previous
      ? previous.activityHash !== prepared.activityHash
      : Boolean(prepared.pullRequest),
  };
}

function unchangedResult(prepared, session, existing, previous) {
  existing.remoteSync = prepared.remoteSync;
  writeContext(session.context, existing);

  return {
    status: "unchanged",
    context: session.context,
    summary: existing.summary?.report ?? null,
    report: previous.report ?? null,
    index: existing.index ?? null,
    pass: previous.number,
    branchUpdate: prepared.branchUpdate,
    remoteSync: prepared.remoteSync,
  };
}

function passPaths(session, number, pullRequest) {
  const label = String(number).padStart(2, "0");

  return {
    diff: join(session.session, `${label}.diff`),
    activity: pullRequest
      ? join(session.session, `${label}.activity.json`)
      : null,
    review: join(session.session, `${label}.review.json`),
    summary: join(session.session, "summary.json"),
    summaryReport: join(session.session, "summary.html"),
  };
}

function buildPatch(prepared, previous, codeChanged) {
  const from = previous?.tree ?? prepared.base.sha;

  if (!codeChanged) return "";
  return diffTrees({
    root: prepared.repository.root,
    from,
    to: prepared.tree,
  });
}

function buildContext(prepared, existing, files) {
  const { repository, pullRequest, base, head } = prepared;
  const context = existing ?? {
    version: 2,
    passes: [],
  };

  context.version = 2;
  context.remoteSync = prepared.remoteSync;
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
  context.summary ??= {
    data: files.summary,
    report: files.summaryReport,
    study: null,
  };

  return context;
}

function appendPass({ prepared, context, files, number, kind, changes }) {
  context.passes.push({
    number,
    kind,
    diff: files.diff,
    activity: files.activity,
    review: files.review,
    head: prepared.head,
    headTree: prepared.headTree,
    pullRequestHead: prepared.pullRequest?.metadata.headRefOid ?? null,
    tree: prepared.tree,
    activityHash: prepared.activityHash,
    changes,
    branchUpdate: prepared.branchUpdate,
    remoteSync: prepared.remoteSync,
    status: "collected",
  });
  context.output = files.review;
}

function writePassFiles(prepared, session, files, patch) {
  mkdirSync(session.session, { recursive: true });
  writeFileSync(files.diff, patch);
  if (files.activity) {
    writeJson(files.activity, prepared.pullRequest);
  }
}

function refreshPresentation(context, previous) {
  const indexExists = context.index && existsSync(context.index);
  const summaryExists = existsSync(context.summary.report);

  if (!previous || (!indexExists && !summaryExists)) return;
  renderSeries({ context });
}

function collectedResult(prepared, session, files) {
  return {
    status: "ready",
    context: session.context,
    diff: files.diff,
    activity: files.activity,
    summary: files.summary,
    review: files.review,
    branchUpdate: prepared.branchUpdate,
    remoteSync: prepared.remoteSync,
  };
}

export function recordCollection(prepared) {
  const session = loadSession(prepared);
  const existing = reconcileHistory(prepared, session);
  const previous = existing?.passes.at(-1);
  const changes = collectionChanges(prepared, previous);
  const number = previous ? previous.number + 1 : 1;
  const kind = previous ? "incremental" : "full";
  const files = passPaths(session, number, prepared.pullRequest);
  const patch = buildPatch(prepared, previous, changes.code);
  let context;

  if (previous && !changes.code && !changes.activity) {
    return unchangedResult(prepared, session, existing, previous);
  }
  if (!previous && !patch) {
    throw new Error("nothing to review: the current change is empty");
  }

  writePassFiles(prepared, session, files, patch);
  context = buildContext(prepared, existing, files);
  appendPass({
    prepared,
    context,
    files,
    number,
    kind,
    changes,
  });
  refreshPresentation(context, previous);
  writeContext(session.context, context);

  return collectedResult(prepared, session, files);
}
