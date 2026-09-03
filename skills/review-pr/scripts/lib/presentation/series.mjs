import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { readJson } from "../context.mjs";
import { validateReview } from "../validation/review.mjs";
import { renderIndex } from "./index.mjs";
import { renderReport } from "./report.mjs";

export function renderSeries({ context }) {
  const complete = context.passes
    .filter((pass) => pass.status === "complete" && existsSync(pass.review))
    .sort((left, right) => left.number - right.number);
  const current = context.passes.at(-1);
  for (let index = 0; index < complete.length; index += 1) {
    const pass = complete[index];
    pass.report = join(dirname(pass.review), `${String(pass.number).padStart(2, "0")}.report.html`);
    const review = validateReview(readJson(pass.review), `review at ${pass.review}`);
    renderReport({
      path: pass.report,
      context,
      pass,
      review,
      historical: pass !== current || current.status !== "complete",
      navigation: {
        index: "index.html",
        summary: `summary.html#pass-${String(pass.number).padStart(2, "0")}`,
        previous: index > 0 ? `${String(complete[index - 1].number).padStart(2, "0")}.report.html` : null,
        next: index + 1 < complete.length ? `${String(complete[index + 1].number).padStart(2, "0")}.report.html` : null,
      },
    });
  }

  const session = dirname(current.review);
  context.index = join(session, "index.html");
  renderIndex({ path: context.index, context, passes: context.passes });
  return context.index;
}
