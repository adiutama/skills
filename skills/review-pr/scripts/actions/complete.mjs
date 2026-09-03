import { readFileSync } from "node:fs";
import {
  readContext,
  readJson,
  resolveContext,
  writeContext,
} from "../lib/context.mjs";
import { renderHandoff } from "../lib/presentation/handoff.mjs";
import { validateReview } from "../lib/validation/review.mjs";
import { validateSummary } from "../lib/validation/summary.mjs";

export function complete({ cwd, env }) {
  const contextPath = resolveContext({ cwd, env });
  const context = readContext(contextPath);
  const pass = context.passes.at(-1);
  if (!pass) throw new Error("context has no review pass");
  if (!["summarized", "complete"].includes(pass.status)) {
    if (pass.status === "collected") throw new Error("checkpoint the change summary before completing findings");
    throw new Error(`latest pass has unsupported status: ${pass.status}`);
  }

  validateSummary(readJson(context.summary.data), context, `summary at ${context.summary.data}`);
  let review;
  try {
    review = JSON.parse(readFileSync(pass.review, "utf8"));
  } catch (error) {
    throw new Error(`review must be valid JSON at ${pass.review}: ${error.message}`);
  }
  validateReview(review, `review at ${pass.review}`);
  if (pass.status === "summarized") {
    pass.status = "complete";
    writeContext(contextPath, context);
  }
  return {
    status: "complete",
    context: contextPath,
    review: pass.review,
    pass: pass.number,
    handoff: renderHandoff({ context, pass, review }),
  };
}
