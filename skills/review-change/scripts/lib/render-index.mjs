import { randomUUID } from "node:crypto";
import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { readJson } from "./context-store.mjs";

const skillRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const template = readFileSync(resolve(skillRoot, "assets", "index.html"), "utf8");

function verdictLabel(value) {
  return value === "reject" ? "Reject" : "Approve";
}

function embeddedJson(value) {
  return JSON.stringify(value)
    .replaceAll("&", "\\u0026")
    .replaceAll("<", "\\u003c")
    .replaceAll(">", "\\u003e")
    .replaceAll("\u2028", "\\u2028")
    .replaceAll("\u2029", "\\u2029");
}

export function renderIndex({ path, context, passes }) {
  const entries = passes.map((pass) => {
    const review = readJson(pass.review);
    const findings = Array.isArray(review.findings) ? review.findings : [];
    return {
      number: pass.number,
      kind: pass.kind,
      head: pass.head,
      changes: pass.changes,
      summary: review.summary || "Review complete",
      verdict: verdictLabel(review.verdict?.value),
      confidence: review.coverage?.confidence || "unspecified",
      findings: {
        total: findings.length,
        blocking: findings.filter((finding) => finding.blocking).length,
        pending: findings.filter((finding) => finding.posting === "pending").length,
        duplicate: findings.filter((finding) => finding.posting === "duplicate").length,
        posted: findings.filter((finding) => finding.posting === "posted").length,
      },
      href: `${String(pass.number).padStart(2, "0")}.report.html`,
    };
  });
  const data = {
    change: context.change,
    passes: entries,
    latest: entries.at(-1)?.href || null,
  };
  const document = template.replace("__REVIEW_CHANGE_SERIES_DATA__", embeddedJson(data));
  mkdirSync(dirname(path), { recursive: true });
  const temporary = `${path}.${randomUUID()}.tmp`;
  writeFileSync(temporary, document);
  renameSync(temporary, path);
  return path;
}
