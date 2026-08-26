#!/usr/bin/env node

import { readSync } from "node:fs";
import { collect } from "./lib/collect.mjs";
import { render } from "./lib/render.mjs";
import { renderSummary } from "./lib/render-summary.mjs";
import { submit } from "./lib/submit.mjs";

const [command, ...args] = process.argv.slice(2);

function submitArguments(values) {
  const findingIds = [];
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
      findingIds.push(value);
    }
  }
  return { findingIds, message, acceptMovedHead };
}

function confirmMovedHead({ currentHead }) {
  if (!process.stdin.isTTY) return false;
  process.stderr.write(`Submit against ${currentHead.slice(0, 12)} anyway? [y/N] `);
  const byte = Buffer.alloc(1);
  let answer = "";
  while (readSync(process.stdin.fd, byte, 0, 1, null) === 1) {
    const character = byte.toString();
    if (character === "\n" || character === "\r") break;
    answer += character;
  }
  return /^(?:y|yes)$/i.test(answer.trim());
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
    result = submit({
      ...submitArguments(args),
      cwd: process.cwd(),
      env: process.env,
      warn: (warning) => process.stderr.write(`Warning: ${warning}\n`),
      confirm: confirmMovedHead,
    });
  } else {
    throw new Error("Usage: review-change collect | render-summary | render | submit [finding-id ...] [--message <text>] [--accept-moved-head]");
  }
  process.stdout.write(`${JSON.stringify(result)}\n`);
  if (result.status === "cancelled") process.exitCode = 2;
} catch (error) {
  process.stderr.write(`Error: ${error.message}\n`);
  process.exitCode = 1;
}
