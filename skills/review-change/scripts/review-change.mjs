#!/usr/bin/env node

import { collect } from "./lib/collect.mjs";
import { checkpoint } from "./lib/checkpoint.mjs";
import { complete } from "./lib/complete.mjs";
import { openReport } from "./lib/open.mjs";
import { render } from "./lib/render.mjs";
import { renderSummary } from "./lib/render-summary.mjs";
import { submit } from "./lib/submit.mjs";

const [command, ...args] = process.argv.slice(2);

function submitArguments(values) {
  let findingList;
  let message;
  let acceptMovedHead = false;
  for (let index = 0; index < values.length; index += 1) {
    const value = values[index];
    if (value === "--message") {
      if (message !== undefined || index + 1 >= values.length) throw new Error("--message requires exactly one value");
      message = values[index + 1];
      index += 1;
    } else if (value === "--accept-moved-head") {
      acceptMovedHead = true;
    } else if (value.startsWith("--")) {
      throw new Error(`unknown submit option: ${value}`);
    } else {
      if (findingList !== undefined) throw new Error("submit accepts finding IDs as one comma-separated value, such as C1,C2");
      findingList = value;
    }
  }
  const findingIds = findingList === undefined ? [] : findingList.split(",").map((id) => id.trim());
  if (findingIds.some((id) => !id)) throw new Error("finding IDs must be a comma-separated value without empty entries");
  return { findingIds, message, acceptMovedHead };
}

try {
  let result;
  if (command === "collect" && args.length === 0) {
    result = collect({ cwd: process.cwd(), env: process.env });
  } else if (command === "checkpoint" && args.length === 0) {
    result = checkpoint({ cwd: process.cwd(), env: process.env });
  } else if (command === "complete" && args.length === 0) {
    result = complete({ cwd: process.cwd(), env: process.env });
  } else if (command === "render-summary" && args.length === 0) {
    result = renderSummary({ cwd: process.cwd(), env: process.env });
  } else if (command === "render" && args.length === 0) {
    result = render({ cwd: process.cwd(), env: process.env });
  } else if (command === "open" && args.length === 0) {
    result = openReport({ cwd: process.cwd(), env: process.env });
  } else if (command === "submit") {
    result = submit({
      ...submitArguments(args),
      cwd: process.cwd(),
      env: process.env,
      warn: (warning) => process.stderr.write(`Warning: ${warning}\n`),
    });
  } else {
    throw new Error("Usage: review-change collect | checkpoint | complete | render | open | submit [finding-id,...] [--message <text>] [--accept-moved-head]");
  }
  process.stdout.write(command === "complete" ? `${result.handoff}\n` : `${JSON.stringify(result)}\n`);
  if (result.status === "cancelled") process.exitCode = 2;
} catch (error) {
  process.stderr.write(`Error: ${error.message}\n`);
  process.exitCode = 1;
}
