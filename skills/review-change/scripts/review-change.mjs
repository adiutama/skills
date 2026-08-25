#!/usr/bin/env node

import { collect } from "./lib/collect.mjs";
import { render } from "./lib/render.mjs";
import { renderSummary } from "./lib/render-summary.mjs";
import { submit } from "./lib/submit.mjs";

const [command, ...args] = process.argv.slice(2);

function submitArguments(values) {
  const findingIds = [];
  let message;
  for (let index = 0; index < values.length; index += 1) {
    const value = values[index];
    if (value === "--message") {
      if (message !== undefined || index + 1 >= values.length) throw new Error("--message requires exactly one value");
      message = values[index + 1];
      index += 1;
    } else if (value.startsWith("--")) {
      throw new Error(`unknown submit option: ${value}`);
    } else {
      findingIds.push(value);
    }
  }
  return { findingIds, message };
}

try {
  let result;
  if (command === "collect" && args.length === 0) {
    result = collect({ cwd: process.cwd(), env: process.env });
  } else if (command === "render-summary" && args.length === 0) {
    result = renderSummary({ cwd: process.cwd(), env: process.env });
  } else if (command === "render" && args.length === 0) {
    result = render({ cwd: process.cwd(), env: process.env });
  } else if (command === "submit") {
    result = submit({ ...submitArguments(args), cwd: process.cwd(), env: process.env });
  } else {
    throw new Error("Usage: review-change collect | render-summary | render | submit [finding-id ...] [--message <text>]");
  }
  process.stdout.write(`${JSON.stringify(result)}\n`);
} catch (error) {
  process.stderr.write(`Error: ${error.message}\n`);
  process.exitCode = 1;
}
