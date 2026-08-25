import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { commandExists, run } from "./command.mjs";
import { readContext, readJson, writeContext, writeJson } from "./context-store.mjs";
import { artifactRoot, repositoryContext, slug } from "./git.mjs";
import { renderSeries } from "./render-series.mjs";
import { validateReview } from "./review.mjs";

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

function currentReview({ cwd, env }) {
  const repository = repositoryContext(cwd);
  const root = artifactRoot({ root: repository.root, env });
  const contextPath = join(root, repository.owner, repository.repo, slug(repository.branch), "review-change", "context.json");
  if (!existsSync(contextPath)) throw new Error(`no review-change session found for ${repository.owner}/${repository.repo} on ${repository.branch}`);
  const context = readContext(contextPath);
  if (context.change.repository !== `${repository.owner}/${repository.repo}` || context.change.branch !== repository.branch) {
    throw new Error("resolved review context does not match the current repository and branch");
  }
  const pass = context.passes.at(-1);
  if (!pass || pass.status !== "complete") throw new Error("the latest review pass is not complete");
  return { contextPath, context, pass };
}

export function submit({ findingIds, message, cwd, env }) {
  if (!commandExists("gh")) throw new Error("submitting a review requires authenticated gh");
  const { contextPath, context, pass } = currentReview({ cwd, env });
  if (context.change.mode !== "pr" || !context.change.pullRequest) throw new Error("this review is not attached to an open pull request");

  const slash = context.change.repository.indexOf("/");
  if (slash < 1) throw new Error(`invalid GitHub repository: ${context.change.repository}`);
  const owner = context.change.repository.slice(0, slash);
  const repo = context.change.repository.slice(slash + 1);
  const metadataRaw = run("gh", [
    "pr", "view", String(context.change.pullRequest), "--repo", `${owner}/${repo}`,
    "--json", "number,headRefOid,state,url",
  ], { cwd });
  const metadata = parseJson(metadataRaw, "gh pr view");
  if (metadata.state !== "OPEN") throw new Error(`pull request #${metadata.number} is no longer open`);
  if (metadata.headRefOid !== pass.head) {
    throw new Error(`pull request HEAD changed from ${pass.head} to ${metadata.headRefOid}; run review-change again`);
  }

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
  const payload = {
    commit_id: pass.head,
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
    postedAt: new Date().toISOString(),
  });
  writeJson(pass.review, review);
  pass.report ??= join(dirname(pass.review), `${String(pass.number).padStart(2, "0")}.report.html`);
  const index = renderSeries({ context });
  writeContext(contextPath, context);
  return { status: "submitted", url: response.html_url ?? null, event, findings: selected.map((finding) => String(finding.id)), report: pass.report, index };
}
