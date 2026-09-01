import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { artifactRoot, repositoryContext, slug } from "./git.mjs";
import { readContext, readJson, writeContext } from "./context-store.mjs";
import { validateSummary } from "./summary.mjs";
import { validateReview } from "./review.mjs";
import { renderHandoff } from "./render-handoff.mjs";

function resolveContext({ cwd, env }) {
  const repository = repositoryContext(cwd);
  const root = artifactRoot({ root: repository.root, env });
  const path = join(root, repository.owner, repository.repo, slug(repository.branch), "review-change", "context.json");
  if (!existsSync(path)) throw new Error(`no review-change session found for ${repository.owner}/${repository.repo} on ${repository.branch}`);
  return path;
}

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
