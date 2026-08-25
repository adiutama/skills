import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { embeddedJson, renderPage, skillRoot } from "./page.mjs";

const template = readFileSync(resolve(skillRoot, "assets", "summary.html"), "utf8");

export function renderSummaryPage({ path, context, summary }) {
  const current = context.passes.at(-1);
  const latestComplete = [...context.passes].reverse().find((pass) => pass.status === "complete" && pass.report);
  return renderPage(path, template, {
    __REVIEW_CHANGE_SUMMARY_DATA__: embeddedJson({
      change: context.change,
      current,
      summary,
      latestReport: latestComplete ? `${String(latestComplete.number).padStart(2, "0")}.report.html` : null,
    }),
  });
}
