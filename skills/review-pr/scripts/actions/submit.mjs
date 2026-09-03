import { existsSync } from "node:fs";
import { commandExists, run } from "../lib/command.mjs";
import {
  readContext,
  readJson,
  resolveContext,
  writeContext,
  writeJson,
} from "../lib/context.mjs";
import {
  commitTree,
  repositoryContext,
} from "../lib/git.mjs";
import { renderSeries } from "../lib/presentation/series.mjs";
import { validateReview } from "../lib/validation/review.mjs";

function parseJson(value, source) {
  try {
    return JSON.parse(value);
  } catch (error) {
    throw new Error(`${source} returned invalid JSON: ${error.message}`);
  }
}

function reviewEvent(verdict) {
  return verdict === "reject" ? "REQUEST_CHANGES" : "APPROVE";
}

function movedHeadWarning({ reviewedHead, previousHead, currentHead, inlineCount }) {
  const reviewed = reviewedHead.slice(0, 12);
  const previous = previousHead.slice(0, 12);
  const current = currentHead.slice(0, 12);
  const lines = [
    `PR HEAD moved from ${previous} to ${current} after this review.`,
    "",
  ];
  if (inlineCount) {
    lines.push(
      `${inlineCount} selected inline ${inlineCount === 1 ? "comment was" : "comments were"} written against ${reviewed}.`,
      "Their line locations may now be incorrect, and GitHub may reject the entire review.",
      "",
    );
  } else {
    lines.push("The verdict and message were written against older code.", "");
  }
  lines.push("Recommended: cancel and run review-pr again.");
  return lines.join("\n");
}

function pullRequestMetadata({ cwd, owner, repo, number }) {
  const metadataRaw = run("gh", [
    "pr", "view", String(number), "--repo", `${owner}/${repo}`,
    "--json", "number,headRefOid,state,url",
  ], { cwd });
  const metadata = parseJson(metadataRaw, "gh pr view");
  if (metadata.state !== "OPEN") throw new Error(`pull request #${metadata.number} is no longer open`);
  return metadata;
}

function currentReview({ cwd, env }) {
  const repository = repositoryContext(cwd);
  const contextPath = resolveContext({ cwd, env });
  const context = readContext(contextPath);
  if (context.change.repository !== `${repository.owner}/${repository.repo}` || context.change.branch !== repository.branch) {
    throw new Error("resolved review context does not match the current repository and branch");
  }
  const pass = context.passes.at(-1);
  if (!pass || pass.status !== "complete") throw new Error("the latest review pass is not complete");
  return { contextPath, context, pass, repository };
}

export function submit({ findingIds, message, acceptMovedHead = false, cwd, env, warn = () => {} }) {
  if (!commandExists("gh")) throw new Error("submitting a review requires authenticated gh");
  const { contextPath, context, pass, repository } = currentReview({ cwd, env });
  if (context.change.mode !== "pr" || !context.change.pullRequest) throw new Error("this review is not attached to an open pull request");
  const reviewedHeadTree = commitTree({ root: repository.root, commit: pass.head });
  if (pass.tree !== reviewedHeadTree) {
    throw new Error("this review includes local worktree changes that are not in the pull request; commit, push, and run review-pr again");
  }

  const slash = context.change.repository.indexOf("/");
  if (slash < 1) throw new Error(`invalid GitHub repository: ${context.change.repository}`);
  const owner = context.change.repository.slice(0, slash);
  const repo = context.change.repository.slice(slash + 1);
  let metadata = pullRequestMetadata({ cwd, owner, repo, number: context.change.pullRequest });
  const review = validateReview(readJson(pass.review), `review at ${pass.review}`);
  const findings = Array.isArray(review.findings) ? review.findings : [];
  const requested = [...new Set(findingIds)];
  const selected = requested.map((id) => {
    const finding = findings.find((candidate) => String(candidate.id) === id);
    if (!finding) throw new Error(`finding ${id} does not exist in pass ${pass.number}`);
    if (finding.posting !== "pending") throw new Error(`finding ${id} is ${finding.posting}, not pending`);
    if (!finding.location?.path || !Number.isInteger(finding.location?.line) || !finding.comment) {
      throw new Error(`finding ${id} lacks a valid inline comment location or body`);
    }
    return finding;
  });
  const event = reviewEvent(review.verdict?.value);
  const warnings = [];
  let confirmation = null;
  let acceptedHead = pass.head;
  let flagAvailable = acceptMovedHead;
  while (true) {
    if (metadata.headRefOid !== acceptedHead) {
      const warning = movedHeadWarning({ reviewedHead: pass.head, previousHead: acceptedHead, currentHead: metadata.headRefOid, inlineCount: selected.length });
      warnings.push(warning);
      warn(warning);
      if (flagAvailable) {
        confirmation = "flag";
      } else {
        return { status: "cancelled", reason: "pull-request-head-changed", warnings };
      }
      acceptedHead = metadata.headRefOid;
      flagAvailable = false;
    }
    const latest = pullRequestMetadata({ cwd, owner, repo, number: context.change.pullRequest });
    if (latest.headRefOid === metadata.headRefOid) {
      metadata = latest;
      break;
    }
    metadata = latest;
  }
  const payload = {
    event,
    body: message?.trim() || review.body || review.summary || review.verdict?.reason || "Review complete.",
  };
  if (selected.length) {
    payload.comments = selected.map((finding) => ({
      path: finding.location.path,
      line: finding.location.line,
      side: "RIGHT",
      body: finding.comment,
    }));
  }
  const responseRaw = run("gh", [
    "api", `repos/${owner}/${repo}/pulls/${metadata.number}/reviews`, "--method", "POST", "--input", "-",
  ], { cwd, input: `${JSON.stringify(payload)}\n` });
  const response = parseJson(responseRaw, "GitHub review submission");

  for (const finding of selected) finding.posting = "posted";
  review.submissions ??= [];
  review.submissions.push({
    url: response.html_url ?? null,
    event,
    body: payload.body,
    findings: selected.map((finding) => String(finding.id)),
    reviewedHead: pass.head,
    observedHead: metadata.headRefOid,
    submittedHead: response.commit_id ?? metadata.headRefOid,
    headMoved: warnings.length > 0,
    confirmation,
    warnings,
    postedAt: new Date().toISOString(),
  });
  writeJson(pass.review, review);
  const presentationExists = (context.index && existsSync(context.index)) || existsSync(context.summary.report) || (pass.report && existsSync(pass.report));
  const index = presentationExists ? renderSeries({ context }) : null;
  writeContext(contextPath, context);
  return { status: "submitted", url: response.html_url ?? null, event, findings: selected.map((finding) => String(finding.id)), warnings, report: pass.report, index };
}
