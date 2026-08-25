import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { readJson } from "./context-store.mjs";
import { embeddedJson, renderPage, skillRoot } from "./page.mjs";

const template = readFileSync(resolve(skillRoot, "assets", "index.html"), "utf8");

function verdictLabel(value) {
  return value === "reject" ? "Reject" : "Approve";
}

export function renderIndex({ path, context, passes }) {
  const entries = passes.map((pass) => {
    const complete = pass.status === "complete" && existsSync(pass.review);
    const review = complete ? readJson(pass.review) : null;
    const findings = Array.isArray(review?.findings) ? review.findings : [];
    return {
      number: pass.number,
      kind: pass.kind,
      head: pass.head,
      changes: pass.changes,
      status: pass.status,
      summary: review?.summary || (pass.status === "summarized" ? "Context ready; findings review in progress." : "Collecting context."),
      verdict: complete ? verdictLabel(review.verdict?.value) : "Reviewing",
      confidence: review?.coverage?.confidence || "pending",
      findings: {
        total: findings.length,
        blocking: findings.filter((finding) => finding.blocking).length,
        pending: findings.filter((finding) => finding.posting === "pending").length,
        duplicate: findings.filter((finding) => finding.posting === "duplicate").length,
        posted: findings.filter((finding) => finding.posting === "posted").length,
      },
      href: complete ? `${String(pass.number).padStart(2, "0")}.report.html` : null,
      summaryHref: pass.status === "summarized" || complete ? `summary.html#pass-${String(pass.number).padStart(2, "0")}` : null,
    };
  });
  const current = entries.at(-1);
  const data = {
    change: context.change,
    passes: entries,
    summary: existsSync(context.summary?.report ?? "") ? { href: "summary.html", revision: context.summary.study?.revision ?? 1 } : null,
    latest: current?.status === "complete" ? current.href : null,
  };
  return renderPage(path, template, { __REVIEW_CHANGE_SERIES_DATA__: embeddedJson(data) });
}
