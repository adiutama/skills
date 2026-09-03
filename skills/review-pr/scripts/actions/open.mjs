import { platform } from "node:os";
import { run } from "../lib/command.mjs";
import { render } from "./render.mjs";

function opener() {
  if (platform() === "darwin") return "open";
  if (platform() === "win32") return "explorer.exe";
  return "xdg-open";
}

export function openReport({ cwd, env }) {
  const result = render({ cwd, env });
  run(opener(), [result.index], { cwd, env });
  return { status: "opened", index: result.index, pass: result.pass };
}
