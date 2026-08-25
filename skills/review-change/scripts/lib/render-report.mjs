import { randomUUID } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const skillRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const templatePath = resolve(skillRoot, "assets", "report.html");
const entrypoint = resolve(skillRoot, "bin", "review-change");
const reportTemplate = readFileSync(templatePath, "utf8");

function embeddedJson(value) {
  return JSON.stringify(value)
    .replaceAll("&", "\\u0026")
    .replaceAll("<", "\\u003c")
    .replaceAll(">", "\\u003e")
    .replaceAll("\u2028", "\\u2028")
    .replaceAll("\u2029", "\\u2029");
}

function replaceOnce(template, marker, value) {
  const parts = template.split(marker);
  if (parts.length !== 2) throw new Error(`report template must contain exactly one ${marker}`);
  return `${parts[0]}${value}${parts[1]}`;
}

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

export function renderReport({ path, context, pass, review, navigation = { index: "index.html", previous: null, next: null }, historical = false }) {
  const submit = !historical && context.change.mode === "pr" && context.change.pullRequest
    ? { tokens: [entrypoint, "submit"] }
    : null;
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
  };
  let document = reportTemplate;
  document = replaceOnce(document, "__REVIEW_CHANGE_PASS__", String(pass.number));
  document = replaceOnce(document, "__REVIEW_CHANGE_DATA__", embeddedJson(data));

  mkdirSync(dirname(path), { recursive: true });
  const temporary = `${path}.${randomUUID()}.tmp`;
  writeFileSync(temporary, document);
  renameSync(temporary, path);
  return path;
}
