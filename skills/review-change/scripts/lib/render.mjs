import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { readContext, writeContext } from "./context-store.mjs";
import { artifactRoot, repositoryContext, slug } from "./git.mjs";
import { renderSeries } from "./render-series.mjs";
import { validateReview } from "./review.mjs";

function resolveContext({ cwd, env }) {
  const repository = repositoryContext(cwd);
  const root = artifactRoot({ root: repository.root, env });
  const path = join(root, repository.owner, repository.repo, slug(repository.branch), "review-change", "context.json");
  if (!existsSync(path)) throw new Error(`no review-change session found for ${repository.owner}/${repository.repo} on ${repository.branch}`);
  return path;
}

export function render({ cwd, env }) {
  const contextPath = resolveContext({ cwd, env });
  const context = readContext(contextPath);
  const pass = context.passes.at(-1);
  if (!pass) throw new Error("context has no review pass");

  let review;
  try {
    review = JSON.parse(readFileSync(pass.review, "utf8"));
  } catch (error) {
    throw new Error(`review must be valid JSON at ${pass.review}: ${error.message}`);
  }
  validateReview(review, `review at ${pass.review}`);

  if (pass.status === "pending") {
    pass.status = "complete";
  } else if (pass.status !== "complete") {
    throw new Error(`latest pass has unsupported status: ${pass.status}`);
  }

  const index = renderSeries({ context });
  writeContext(contextPath, context);
  return { status: "rendered", context: contextPath, review: pass.review, report: pass.report, index, pass: pass.number };
}
