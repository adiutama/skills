import {
  readContext,
  readJson,
  resolveContext,
  writeContext,
} from "../lib/context.mjs";
import { reviewPrInvocation } from "../lib/invocation.mjs";
import {
  contentHash,
  studyHash,
  validateSummary,
} from "../lib/validation/summary.mjs";

export function checkpoint({ cwd, env }) {
  const contextPath = resolveContext({ cwd, env });
  const context = readContext(contextPath);
  const pass = context.passes.at(-1);
  if (!pass) throw new Error("context has no review pass");
  if (!["collected", "summarized"].includes(pass.status)) {
    if (pass.status === "complete") throw new Error("the latest review pass is already complete");
    throw new Error(`latest pass has unsupported status: ${pass.status}`);
  }

  const summary = validateSummary(readJson(context.summary.data), context, `summary at ${context.summary.data}`);
  context.summary.study = {
    revision: summary.study.revision,
    writtenAtPass: summary.study.writtenAtPass,
    hash: studyHash(summary.study),
  };
  context.summary.updates = summary.updates.map(contentHash);
  pass.status = "summarized";
  writeContext(contextPath, context);
  return {
    status: "summarized",
    context: contextPath,
    summary: context.summary.data,
    review: pass.review,
    pass: pass.number,
    next: `Write the review JSON, then continue the active ${reviewPrInvocation()} workflow. Invoke ${reviewPrInvocation("render")} to inspect the summary in HTML.`,
  };
}
