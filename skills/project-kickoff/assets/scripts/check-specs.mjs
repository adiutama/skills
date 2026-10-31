#!/usr/bin/env node
// Keeps decisions, specs, and tests in sync. The rules are described in
// AGENTS.md and README.md; this script enforces them.

import { execFileSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const DECISIONS_DIR = "docs/decisions";
const SPECS_DIR = "docs/specs";
const TESTS_DIR = "tests";
export const TEST_REPORT = ".cache/test-results.json";

const ADR_FILE = /^(\d{12})-[a-z0-9]+(?:-[a-z0-9]+)*\.md$/;
const ADR_STATUSES = ["proposed", "accepted", "superseded"];
const SPEC_STATUSES = ["draft", "agreed", "implemented"];
const MUTABLE_ADR_FIELDS = ["Status", "Superseded by"];
const PREFIX = /^[A-Z]{2,6}$/;
const RULE_LINE = /^- \*\*([A-Z]{2,6})-(\d+)\*\* \S/;
const ADR_CITATION = /\(ADR (\d{12})\)/g;
const TEST_TITLE = /^([A-Z]{2,6}-\d+(?:,\s*[A-Z]{2,6}-\d+)*): /;

/**
 * @typedef {{ id: string, path: string, status: string, supersedes: string[], supersededBy: string | null }} Adr
 * @typedef {{ id: string, line: number, citations: string[] }} Rule
 * @typedef {{ path: string, status: string, prefix: string, decisions: string[], rules: Rule[] }} Spec
 * @typedef {{ title: string, status: string }} TestResult
 */

/**
 * @param {string} root
 * @param {TestResult[]} tests Results from the last full test run.
 * @returns {string[]}
 */
export function checkRepo(root, tests) {
  /** @type {string[]} */
  const errors = [];
  const adrs = readAdrs(root, errors);
  checkSupersession(adrs, errors);
  checkAdrHistory(root, errors);
  const specs = readSpecs(root, adrs, errors);
  checkTraceability(specs, tests, errors);
  return errors;
}

/**
 * Reads the Vitest JSON report. Coverage comes from tests that actually ran,
 * so commented-out, skipped, and fixture tests never count.
 * @param {string} root
 * @returns {{ tests: TestResult[] } | { error: string }}
 */
export function readTestReport(root) {
  const path = join(root, TEST_REPORT);
  if (!existsSync(path)) return { error: `${TEST_REPORT} is missing; run \`npm test\` first` };
  const reportTime = statSync(path).mtimeMs;
  if (newestMtime(join(root, TESTS_DIR)) > reportTime) {
    return { error: `${TEST_REPORT} is older than tests/; run \`npm test\` again` };
  }
  /** @type {{ testResults?: { assertionResults?: TestResult[] }[] }} */
  const report = JSON.parse(readFileSync(path, "utf8"));
  const tests = (report.testResults ?? []).flatMap((file) =>
    (file.assertionResults ?? []).map(({ title, status }) => ({ title, status })),
  );
  return { tests };
}

// --- ADRs ------------------------------------------------------------------

/**
 * Header fields are `- Name: value` lines before the first `## ` heading.
 * @param {string} text
 * @param {(message: string) => void} [onError]
 * @returns {Map<string, { value: string, line: number }>}
 */
function readFields(text, onError) {
  const fields = new Map();
  const lines = text.split("\n");
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].startsWith("## ")) break;
    const match = /^- ([A-Za-z][A-Za-z ]*): (.*)$/.exec(lines[i]);
    if (!match) continue;
    if (fields.has(match[1])) onError?.(`line ${i + 1}: "${match[1]}" is set twice`);
    fields.set(match[1], { value: match[2].trim(), line: i + 1 });
  }
  return fields;
}

/** @param {string} value @returns {string[]} */
function idList(value) {
  if (value === "none") return [];
  return value.split(",").map((id) => id.trim());
}

/** @param {string} root @param {string[]} errors @returns {Map<string, Adr>} */
function readAdrs(root, errors) {
  /** @type {Map<string, Adr>} */
  const adrs = new Map();
  for (const name of listMarkdown(join(root, DECISIONS_DIR))) {
    const path = `${DECISIONS_DIR}/${name}`;
    const match = ADR_FILE.exec(name);
    if (!match) {
      errors.push(`${path}: ADR file names must be YYYYMMDDHHMM-slug.md`);
      continue;
    }
    const id = match[1];
    if (!isValidTimestamp(id)) errors.push(`${path}: ${id} is not a valid UTC timestamp`);
    const duplicate = adrs.get(id);
    if (duplicate) {
      errors.push(`${path}: timestamp ${id} is already used by ${duplicate.path}`);
      continue;
    }

    const fields = readFields(readFileSync(join(root, path), "utf8"), (message) =>
      errors.push(`${path}: ${message}`),
    );
    for (const field of ["Status", "Date", "Supersedes", "Superseded by", "Applies to"]) {
      if (!fields.has(field)) errors.push(`${path}: missing "- ${field}:" header line`);
    }
    const status = fields.get("Status")?.value ?? "";
    if (!ADR_STATUSES.includes(status)) {
      errors.push(`${path}: Status must be one of ${ADR_STATUSES.join(", ")}`);
    }
    const supersedes = idList(fields.get("Supersedes")?.value ?? "none");
    const supersededByList = idList(fields.get("Superseded by")?.value ?? "none");
    if (supersededByList.length > 1) errors.push(`${path}: Superseded by takes one ADR id`);
    adrs.set(id, { id, path, status, supersedes, supersededBy: supersededByList[0] ?? null });
  }
  return adrs;
}

/** @param {string} id */
function isValidTimestamp(id) {
  const [y, mo, d, h, mi] = [0, 4, 6, 8, 10].map((start, i) =>
    Number(id.slice(start, i === 0 ? 4 : start + 2)),
  );
  const date = new Date(Date.UTC(y, mo - 1, d, h, mi));
  return (
    date.getUTCFullYear() === y &&
    date.getUTCMonth() === mo - 1 &&
    date.getUTCDate() === d &&
    date.getUTCHours() === h &&
    date.getUTCMinutes() === mi
  );
}

/** @param {Map<string, Adr>} adrs @param {string[]} errors */
function checkSupersession(adrs, errors) {
  for (const adr of adrs.values()) {
    if (adr.supersededBy === adr.id || adr.supersedes.includes(adr.id)) {
      errors.push(`${adr.path}: an ADR cannot supersede itself`);
      continue;
    }
    if (adr.status === "superseded" && !adr.supersededBy) {
      errors.push(`${adr.path}: superseded ADRs must name their replacement in "Superseded by"`);
    }
    if (adr.supersededBy) {
      const next = adrs.get(adr.supersededBy);
      if (adr.status !== "superseded") {
        errors.push(`${adr.path}: has "Superseded by" but Status is ${adr.status}`);
      }
      if (!next) {
        errors.push(`${adr.path}: Superseded by ${adr.supersededBy}, which does not exist`);
      } else if (!next.supersedes.includes(adr.id)) {
        errors.push(`${next.path}: must list ${adr.id} in "Supersedes"`);
      }
    }
    for (const previousId of adr.supersedes) {
      const previous = adrs.get(previousId);
      if (!previous) {
        errors.push(`${adr.path}: Supersedes ${previousId}, which does not exist`);
      } else if (adr.status !== "proposed" && previous.supersededBy !== adr.id) {
        errors.push(`${previous.path}: must be Status superseded, Superseded by ${adr.id}`);
      }
    }

    // A chain of replacements must end at an accepted decision.
    if (adr.status === "superseded") {
      const seen = new Set([adr.id]);
      let current = adrs.get(adr.supersededBy ?? "");
      while (current?.status === "superseded" && current.supersededBy) {
        if (seen.has(current.id)) {
          errors.push(`${adr.path}: supersession chain loops through ${current.id}`);
          current = undefined;
          break;
        }
        seen.add(current.id);
        current = adrs.get(current.supersededBy);
      }
      if (current && current.status !== "accepted") {
        errors.push(
          `${adr.path}: supersession chain ends at ${current.id}, which is ${current.status}`,
        );
      }
    }
  }
}

/** @param {string} text */
function withoutMutableFields(text) {
  return text
    .split("\n")
    .filter((line) => !MUTABLE_ADR_FIELDS.some((field) => line.startsWith(`- ${field}:`)))
    .join("\n");
}

/** @param {string} root @param {string[]} args */
function git(root, args) {
  return execFileSync("git", args, {
    cwd: root,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
    maxBuffer: 64 * 1024 * 1024,
  });
}

/**
 * Every version of an ADR committed while accepted (or superseded) must match
 * the current file, ignoring the mutable fields. This holds regardless of
 * commit order or merges, and the fix for a violation is to revert the edit.
 * Accepted ADRs may not be deleted, renamed, or moved back to proposed.
 * @param {string} root @param {string[]} errors
 */
function checkAdrHistory(root, errors) {
  try {
    try {
      git(root, ["rev-parse", "--verify", "--quiet", "HEAD"]);
    } catch (error) {
      // Exit status 1 with --quiet means HEAD does not exist yet: no commits.
      if (/** @type {{ status?: number }} */ (error).status === 1) return;
      throw error;
    }
    if (git(root, ["rev-parse", "--is-shallow-repository"]).trim() === "true") {
      errors.push(
        "git history is shallow; ADR immutability needs full history (git fetch --unshallow)",
      );
      return;
    }

    // -m shows merge commits' changes against each parent, so an ADR accepted
    // while resolving a merge is seen too.
    const log = git(root, [
      "log",
      "-m",
      "--no-renames",
      "--format=@%H",
      "--name-status",
      "--",
      DECISIONS_DIR,
    ]);
    /** @type {Map<string, Set<string>>} */
    const frozen = new Map();
    const seen = new Set();
    let commit = "";
    for (const line of log.split("\n")) {
      if (line.startsWith("@")) {
        commit = line.slice(1);
        continue;
      }
      const [change, path] = line.split("\t");
      if (!path || change === "D" || !ADR_FILE.test(path.split("/").pop() ?? "")) continue;
      const key = `${commit}:${path}`;
      if (seen.has(key)) continue;
      seen.add(key);
      const content = git(root, ["show", key]);
      const status = readFields(content).get("Status")?.value;
      if (status !== "accepted" && status !== "superseded") continue;
      const versions = frozen.get(path) ?? new Set();
      versions.add(withoutMutableFields(content));
      frozen.set(path, versions);
    }

    for (const [path, versions] of frozen) {
      const file = join(root, path);
      if (!existsSync(file)) {
        errors.push(`${path}: accepted ADRs may not be deleted or renamed; supersede it instead`);
        continue;
      }
      const current = readFileSync(file, "utf8");
      if (readFields(current).get("Status")?.value === "proposed") {
        errors.push(`${path}: accepted ADRs may not go back to proposed`);
      }
      const body = withoutMutableFields(current);
      if ([...versions].some((version) => version !== body)) {
        errors.push(
          `${path}: accepted ADRs are immutable except Status and Superseded by; revert the edit and write a new ADR that supersedes it`,
        );
      }
    }
  } catch (error) {
    errors.push(
      `git failed while checking ADR history: ${/** @type {Error} */ (error).message.trim()}`,
    );
  }
}

// --- Specs -----------------------------------------------------------------

/**
 * @param {string} root @param {Map<string, Adr>} adrs @param {string[]} errors
 * @returns {Spec[]}
 */
function readSpecs(root, adrs, errors) {
  /** @type {Spec[]} */
  const specs = [];
  /** @type {Map<string, string>} */
  const prefixes = new Map();
  for (const name of listMarkdown(join(root, SPECS_DIR))) {
    const path = `${SPECS_DIR}/${name}`;
    const text = readFileSync(join(root, path), "utf8");
    const fields = readFields(text, (message) => errors.push(`${path}: ${message}`));
    const status = fields.get("Status")?.value ?? "";
    const prefix = fields.get("Prefix")?.value ?? "";
    const decisions = idList(fields.get("Decisions")?.value ?? "none");
    const binding = status !== "draft";

    if (!SPEC_STATUSES.includes(status)) {
      errors.push(`${path}: Status must be one of ${SPEC_STATUSES.join(", ")}`);
    }
    if (!PREFIX.test(prefix)) errors.push(`${path}: Prefix must be 2-6 capital letters`);
    const owner = prefixes.get(prefix);
    if (owner) errors.push(`${path}: Prefix ${prefix} is already used by ${owner}`);
    prefixes.set(prefix, path);
    if (!fields.has("Decisions"))
      errors.push(`${path}: missing "- Decisions:" header line (use "none")`);
    for (const id of decisions) {
      const adr = adrs.get(id);
      if (!adr) errors.push(`${path}: Decisions lists ${id}, which does not exist`);
      else if (binding && adr.status !== "accepted") {
        errors.push(`${path}: Decisions lists ${id}, which is ${adr.status}`);
      }
    }

    const rules = readRules(path, text, prefix, errors);
    if (binding && rules.length === 0)
      errors.push(`${path}: a ${status} spec needs at least one rule`);
    for (const rule of rules) {
      for (const id of rule.citations) {
        const adr = adrs.get(id);
        if (!decisions.includes(id)) {
          errors.push(
            `${path}:${rule.line}: ${rule.id} cites ADR ${id}, which is not in Decisions`,
          );
        }
        if (!adr)
          errors.push(`${path}:${rule.line}: ${rule.id} cites ADR ${id}, which does not exist`);
        else if (binding && adr.status !== "accepted") {
          errors.push(`${path}:${rule.line}: ${rule.id} cites ADR ${id}, which is ${adr.status}`);
        }
      }
    }
    specs.push({ path, status, prefix, decisions, rules });
  }
  return specs;
}

/**
 * Under `## Rules`, every line is a rule, an indented continuation, or blank.
 * Anything else fails, so a typo cannot hide a rule from the coverage check.
 * @param {string} path @param {string} text @param {string} prefix @param {string[]} errors
 * @returns {Rule[]}
 */
function readRules(path, text, prefix, errors) {
  /** @type {Rule[]} */
  const rules = [];
  const seen = new Set();
  let inRules = false;
  let sawRules = false;
  const lines = text.split("\n");
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.startsWith("## ")) {
      inRules = line.trim() === "## Rules";
      sawRules ||= inRules;
      continue;
    }
    if (!inRules || line.trim() === "") continue;
    if (/^\s/.test(line) && rules.length > 0 && !/\*\*[A-Z]{2,6}-\d+\*\*/.test(line)) continue;
    const match = RULE_LINE.exec(line);
    if (!match) {
      errors.push(
        `${path}:${i + 1}: only rules go under "## Rules", as "- **${prefix || "PREFIX"}-1** text"`,
      );
      continue;
    }
    const id = `${match[1]}-${match[2]}`;
    if (match[1] !== prefix)
      errors.push(`${path}:${i + 1}: ${id} does not use this spec's Prefix ${prefix}`);
    if (seen.has(id)) errors.push(`${path}:${i + 1}: ${id} is defined twice`);
    seen.add(id);
    rules.push({ id, line: i + 1, citations: [...line.matchAll(ADR_CITATION)].map((m) => m[1]) });
  }
  if (!sawRules) errors.push(`${path}: missing "## Rules" section`);
  return rules;
}

// --- Tests -----------------------------------------------------------------

/** @param {Spec[]} specs @param {TestResult[]} tests @param {string[]} errors */
function checkTraceability(specs, tests, errors) {
  const known = new Set(specs.flatMap((spec) => spec.rules.map((rule) => rule.id)));
  const tested = new Set();
  for (const test of tests) {
    const match = TEST_TITLE.exec(test.title);
    if (!match) continue;
    for (const id of match[1].split(",").map((s) => s.trim())) {
      if (!known.has(id)) errors.push(`test "${test.title}" names ${id}, which no spec defines`);
      if (test.status === "passed") tested.add(id);
    }
  }

  for (const spec of specs) {
    if (spec.status !== "implemented") continue;
    for (const rule of spec.rules) {
      if (!tested.has(rule.id)) {
        errors.push(
          `${spec.path}:${rule.line}: ${rule.id} has no passing test titled "${rule.id}: …"`,
        );
      }
    }
  }
}

// --- Files -----------------------------------------------------------------

/** Markdown files in a directory, skipping `_template.md` and other `_` files. @param {string} dir */
function listMarkdown(dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((name) => name.endsWith(".md") && !name.startsWith("_"))
    .sort();
}

/** @param {string} dir @returns {number} */
function newestMtime(dir) {
  if (!existsSync(dir)) return 0;
  let newest = statSync(dir).mtimeMs;
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    const stat = statSync(full);
    newest = Math.max(newest, stat.isDirectory() ? newestMtime(full) : stat.mtimeMs);
  }
  return newest;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const root = fileURLToPath(new URL("..", import.meta.url));
  const report = readTestReport(root);
  const errors = "error" in report ? [report.error] : checkRepo(root, report.tests);
  if (errors.length > 0) {
    for (const error of errors) console.error(`✗ ${error}`);
    console.error(`\ncheck-specs: ${errors.length} problem(s)`);
    process.exit(1);
  }
  console.log("check-specs: decisions, specs, and tests are in sync");
}
