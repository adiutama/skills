import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { readJson } from "./context-store.mjs";
import { renderIndex } from "./render-index.mjs";
import { renderReport } from "./render-report.mjs";
import { validateReview } from "./review.mjs";

export function renderSeries({ context }) {
  const passes = context.passes
    .filter((pass) => pass.status === "complete" && existsSync(pass.review))
    .sort((left, right) => left.number - right.number);
  if (!passes.length) throw new Error("cannot render a review series without a completed pass");

  const latest = passes.at(-1);
  for (let index = 0; index < passes.length; index += 1) {
    const pass = passes[index];
    pass.report = join(dirname(pass.review), `${String(pass.number).padStart(2, "0")}.report.html`);
    const review = validateReview(readJson(pass.review), `review at ${pass.review}`);
    renderReport({
      path: pass.report,
      context,
      pass,
      review,
      historical: pass !== latest,
      navigation: {
        index: "index.html",
        previous: index > 0 ? `${String(passes[index - 1].number).padStart(2, "0")}.report.html` : null,
        next: index + 1 < passes.length ? `${String(passes[index + 1].number).padStart(2, "0")}.report.html` : null,
      },
    });
  }

  context.index = join(dirname(latest.review), "index.html");
  renderIndex({ path: context.index, context, passes });
  return context.index;
}
