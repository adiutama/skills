import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { sessionInvocation } from "../invocation.mjs";

const skillRoot = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "..",
  "..",
  "..",
);
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

function checkoutStatus(context) {
  const sync = context.remoteSync;
  if (!sync) return "Checkout at collection: **local-only** — no PR or remote branch target was available.";
  const action = sync.status === "checked-out"
    ? "verified after PR checkout"
    : sync.status === "fast-forwarded"
      ? "verified after fast-forward"
      : "verified current";
  const checkout = context.checkout;
  const reasons = {
    "dirty-worktree": "The original checkout has local changes; they were preserved in place.",
    "active-review-in-worktree": "Another unfinished review keeps the original checkout.",
    "branch-name-conflict": "The source branch name belongs to other local work.",
    "branch-has-local-commits": "The source branch has local commits that were preserved.",
    "branch-in-another-worktree": "The source branch is checked out elsewhere.",
  };
  const detail = checkout ? ` Branch: \`${checkout.branch}\`. Review directory: ${JSON.stringify(checkout.path)}.${checkout.reason ? ` ${reasons[checkout.reason] || "A separate checkout was needed."}` : ""}` : "";
  return `Checkout at collection: **${action}** — ${sync.ref} at \`${sync.head}\`.${detail}`;
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
  return `To submit this review, invoke \`${sessionInvocation(context, ...args)}\`.`;
}

export function renderHandoff({ context, pass, review }) {
  const values = {
    VERDICT: label(review.verdict.value),
    VERDICT_REASON: review.verdict.reason || review.summary || "Review complete.",
    BLOCKING_FINDINGS: blockingSection(review),
    SUBMIT_MESSAGE: quote(review.body || review.summary || review.verdict.reason),
    COVERAGE: review.coverage?.confidence || "unspecified",
    COVERAGE_GAPS: coverageGaps(review),
    CHECKOUT_STATUS: checkoutStatus(context),
    SUBMISSION_ACTION: submissionAction({ context, pass, review }),
    OPEN_INVOCATION: sessionInvocation(context, "open"),
    RENDER_INVOCATION: sessionInvocation(context, "render"),
  };
  return Object.entries(values).reduce(
    (output, [key, value]) => output.replaceAll(`{{${key}}}`, value),
    template,
  ).trim();
}
