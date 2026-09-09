#!/usr/bin/env node

import { checkpoint } from "./actions/checkpoint.mjs";
import { collect } from "./actions/collect.mjs";
import { complete } from "./actions/complete.mjs";
import { openReport } from "./actions/open.mjs";
import { render } from "./actions/render.mjs";
import { renderSummary } from "./actions/render-summary.mjs";
import { submit } from "./actions/submit.mjs";

const [command, ...inputArgs] = process.argv.slice(2);

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
  const args = [];
  let contextPath;
  for (let index = 0; index < inputArgs.length; index += 1) {
    const value = inputArgs[index];
    if (value === "--message") {
      args.push(value);
      if (index + 1 < inputArgs.length) args.push(inputArgs[++index]);
    } else if (value === "--context") {
      if (contextPath || !inputArgs[index + 1]) throw new Error("--context requires exactly one absolute context.json path");
      contextPath = inputArgs[++index];
    } else args.push(value);
  }
  if (contextPath && command === "collect") throw new Error("collect takes an explicit PR target, not --context");
  const env = { ...process.env, ...(contextPath ? { REVIEW_PR_CONTEXT: contextPath } : {}) };
  let result;
  if (command === "collect" && args.length <= 1) {
    result = collect({ cwd: process.cwd(), env, target: args[0] });
  } else if (command === "checkpoint" && args.length === 0) {
    result = checkpoint({ cwd: process.cwd(), env });
  } else if (command === "complete" && args.length === 0) {
    result = complete({ cwd: process.cwd(), env });
  } else if (command === "render-summary" && args.length === 0) {
    result = renderSummary({ cwd: process.cwd(), env });
  } else if (command === "render" && args.length === 0) {
    result = render({ cwd: process.cwd(), env });
  } else if (command === "open" && args.length === 0) {
    result = openReport({ cwd: process.cwd(), env });
  } else if (command === "submit") {
    result = submit({
      ...submitArguments(args),
      cwd: process.cwd(),
      env,
      warn: (warning) => process.stderr.write(`Warning: ${warning}\n`),
    });
  } else {
    throw new Error("Usage: review-pr collect [PR-URL-or-number] | checkpoint | complete | render | open | submit [finding-id,...] [--message <text>] [--accept-moved-head]");
  }
  process.stdout.write(command === "complete" ? `${result.handoff}\n` : `${JSON.stringify(result)}\n`);
  if (result.status === "cancelled") process.exitCode = 2;
} catch (error) {
  process.stderr.write(`Error: ${error.message}\n`);
  process.exitCode = 1;
}
