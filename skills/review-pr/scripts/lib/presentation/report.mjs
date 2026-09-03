import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { reviewPrInvocation } from "../invocation.mjs";
import { embeddedJson, renderPage, skillRoot } from "./page.mjs";

const templatePath = resolve(skillRoot, "assets", "report.html");
const reportTemplate = readFileSync(templatePath, "utf8");

function verdictLabel(value) {
  return value === "reject" ? "Reject" : "Approve";
}

function duplicateSources(pass, review) {
  if (!pass.activity || !existsSync(pass.activity)) return {};
  const activity = JSON.parse(readFileSync(pass.activity, "utf8"));
  const collections = {
    conversation: activity.comments?.conversation,
    inline: activity.comments?.inline,
    review: activity.comments?.reviews,
  };
  const resolved = {};
  for (const finding of Array.isArray(review.findings) ? review.findings : []) {
    if (finding.posting !== "duplicate" || !finding.duplicateOf) continue;
    const { kind, id } = finding.duplicateOf;
    const source = Array.isArray(collections[kind])
      ? collections[kind].find((item) => String(item.id) === String(id))
      : null;
    if (!source) continue;
    resolved[String(finding.id)] = {
      kind,
      id: source.id,
      author: source.user?.login || "unknown reviewer",
      body: source.body || "",
      url: source.html_url || null,
    };
  }
  return resolved;
}

function carryOverSources(context, review) {
  const resolved = {};
  for (const finding of Array.isArray(review.findings) ? review.findings : []) {
    if (!finding.carriedFrom) continue;
    const sourcePass = context.passes.find((pass) => pass.number === finding.carriedFrom.pass);
    if (!sourcePass?.review || !existsSync(sourcePass.review)) continue;
    const sourceReview = JSON.parse(readFileSync(sourcePass.review, "utf8"));
    const sourceFinding = Array.isArray(sourceReview.findings)
      ? sourceReview.findings.find((candidate) => String(candidate.id) === String(finding.carriedFrom.findingId))
      : null;
    if (!sourceFinding) continue;
    resolved[String(finding.id)] = {
      pass: sourcePass.number,
      findingId: String(sourceFinding.id),
      href: `${String(sourcePass.number).padStart(2, "0")}.report.html#finding-${encodeURIComponent(String(sourceFinding.id))}`,
      title: sourceFinding.title || "Untitled finding",
      explanation: sourceFinding.explanation || "",
    };
  }
  return resolved;
}

export function renderReport({ path, context, pass, review, navigation = { index: "index.html", summary: "summary.html", previous: null, next: null }, historical = false }) {
  let submissionUnavailable = null;
  if (historical) {
    submissionUnavailable = "Historical pass — open the latest report to prepare a submission.";
  } else if (context.change.mode !== "pr" || !context.change.pullRequest) {
    submissionUnavailable = "No open pull request was detected for this review.";
  } else if (pass.tree !== pass.headTree) {
    submissionUnavailable = "Submission unavailable — this review includes local worktree changes that are not in the pull request.";
  }
  const submit = submissionUnavailable ? null : { invocation: reviewPrInvocation("submit") };
  const data = {
    change: context.change,
    pass,
    review,
    display: { verdict: verdictLabel(review.verdict?.value) },
    duplicates: duplicateSources(pass, review),
    carryOvers: carryOverSources(context, review),
    navigation,
    historical,
    submit,
    submissionUnavailable,
  };
  return renderPage(path, reportTemplate, {
    __REVIEW_CHANGE_PASS__: String(pass.number),
    __REVIEW_CHANGE_DATA__: embeddedJson(data),
  });
}
