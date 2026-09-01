import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { reviewChangeInvocation } from "./invocation.mjs";

const skillRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const template = readFileSync(resolve(skillRoot, "assets", "agent-handoff.md"), "utf8");

function label(value) {
  return value === "reject" ? "Reject" : "Approve";
}

function quote(value) {
  return String(value || "Review complete.")
    .trim()
    .split("\n")
    .map((line) => `> ${line}`)
    .join("\n");
}

function blockingSection(review) {
  if (review.verdict.value !== "reject") return "";
  const findings = review.findings.filter((finding) => finding.blocking);
  const lines = findings.map((finding) => {
    const path = finding.location?.path || "unknown location";
    const line = Number.isInteger(finding.location?.line) ? `:${finding.location.line}` : "";
    const impact = finding.impact ? ` — ${finding.impact}` : "";
    return `- **${finding.id} · ${finding.title || "Untitled finding"}** (${path}${line})${impact}`;
  });
  return `Blocking findings:\n\n${lines.join("\n")}\n\n`;
}

function coverageGaps(review) {
  const gaps = review.coverage?.notReviewed || [];
  return gaps.length ? ` — Not verified: ${gaps.join("; ")}` : "";
}

function submissionAction({ context, pass, review }) {
  if (context.change.mode !== "pr" || !context.change.pullRequest) {
    return "Submission is unavailable because this review is not attached to an open pull request.";
  }
  if (pass.tree !== pass.headTree) {
    return "Submission is unavailable because the review includes local changes that are not in the pull request.";
  }
  const ids = review.findings
    .filter((finding) => finding.posting === "pending")
    .map((finding) => String(finding.id));
  const args = ids.length ? ["submit", ids.join(",")] : ["submit"];
  return `To submit this review, invoke \`${reviewChangeInvocation(...args)}\`.`;
}

export function renderHandoff({ context, pass, review }) {
  const values = {
    VERDICT: label(review.verdict.value),
    VERDICT_REASON: review.verdict.reason || review.summary || "Review complete.",
    BLOCKING_FINDINGS: blockingSection(review),
    SUBMIT_MESSAGE: quote(review.body || review.summary || review.verdict.reason),
    COVERAGE: review.coverage?.confidence || "unspecified",
    COVERAGE_GAPS: coverageGaps(review),
    SUBMISSION_ACTION: submissionAction({ context, pass, review }),
    OPEN_INVOCATION: reviewChangeInvocation("open"),
    RENDER_INVOCATION: reviewChangeInvocation("render"),
  };
  return Object.entries(values).reduce(
    (output, [key, value]) => output.replaceAll(`{{${key}}}`, value),
    template,
  ).trim();
}
