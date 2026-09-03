import { checkpoint } from "./checkpoint.mjs";
import { render } from "./render.mjs";

export function renderSummary({ cwd, env }) {
  const summarized = checkpoint({ cwd, env });
  const rendered = render({ cwd, env });
  return { ...summarized, report: rendered.summary, index: rendered.index, anchor: `${rendered.summary}#pass-${String(summarized.pass).padStart(2, "0")}` };
}
