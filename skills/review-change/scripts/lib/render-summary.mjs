import { existsSync } from "node:fs";
import { join } from "node:path";
import { artifactRoot, repositoryContext, slug } from "./git.mjs";
import { readContext, readJson, writeContext } from "./context-store.mjs";
import { renderSeries } from "./render-series.mjs";
import { renderSummaryPage } from "./render-summary-page.mjs";
import { contentHash, studyHash, validateSummary } from "./summary.mjs";

function resolveContext({ cwd, env }) {
  const repository = repositoryContext(cwd);
  const root = artifactRoot({ root: repository.root, env });
  const path = join(root, repository.owner, repository.repo, slug(repository.branch), "review-change", "context.json");
  if (!existsSync(path)) throw new Error(`no review-change session found for ${repository.owner}/${repository.repo} on ${repository.branch}`);
  return path;
}

export function renderSummary({ cwd, env }) {
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
  renderSummaryPage({ path: context.summary.report, context, summary });
  const index = renderSeries({ context });
  writeContext(contextPath, context);
  return {
    status: "summarized",
    context: contextPath,
    summary: context.summary.data,
    report: context.summary.report,
    index,
    pass: pass.number,
    anchor: `${context.summary.report}#pass-${String(pass.number).padStart(2, "0")}`,
  };
}
