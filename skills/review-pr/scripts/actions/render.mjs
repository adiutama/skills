import { readFileSync } from "node:fs";
import {
  readContext,
  resolveContext,
  writeContext,
} from "../lib/context.mjs";
import { reviewPrInvocation } from "../lib/invocation.mjs";
import { renderSeries } from "../lib/presentation/series.mjs";
import { renderSummaryPage } from "../lib/presentation/summary-page.mjs";
import { validateReview } from "../lib/validation/review.mjs";
import { validateSummary } from "../lib/validation/summary.mjs";

export function render({ cwd, env }) {
  const contextPath = resolveContext({ cwd, env });
  const context = readContext(contextPath);
  const pass = context.passes.at(-1);
  if (!pass) throw new Error("context has no review pass");
  if (pass.status === "collected") throw new Error("checkpoint the change summary before rendering HTML");
  if (!["summarized", "complete"].includes(pass.status)) throw new Error(`latest pass has unsupported status: ${pass.status}`);

  const summary = validateSummary(readContext(context.summary.data), context, `summary at ${context.summary.data}`);
  if (pass.status === "complete") {
    let review;
    try {
      review = JSON.parse(readFileSync(pass.review, "utf8"));
    } catch (error) {
      throw new Error(`review must be valid JSON at ${pass.review}: ${error.message}`);
    }
    validateReview(review, `review at ${pass.review}`);
  }

  renderSummaryPage({ path: context.summary.report, context, summary });
  const index = renderSeries({ context });
  writeContext(contextPath, context);
  return {
    status: "rendered",
    context: contextPath,
    summary: context.summary.report,
    review: pass.review,
    report: pass.status === "complete" ? pass.report : null,
    index,
    pass: pass.number,
    next: `Invoke ${reviewPrInvocation("open")} to view the report in a browser.`,
  };
}
