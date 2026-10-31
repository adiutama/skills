import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, utimesSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { checkRepo, readTestReport, TEST_REPORT } from "../scripts/check-specs.mjs";

const ADR_A = "202610100900";
const ADR_B = "202610101000";

type AdrOptions = { status?: string; supersedes?: string; supersededBy?: string; body?: string };

function adr(id: string, options: AdrOptions = {}) {
  return [
    `# Decision ${id}`,
    "",
    `- Status: ${options.status ?? "accepted"}`,
    "- Date: 2026-10-10",
    `- Supersedes: ${options.supersedes ?? "none"}`,
    `- Superseded by: ${options.supersededBy ?? "none"}`,
    "- Applies to: docs/specs/sample.md",
    "",
    "## Context",
    "",
    options.body ?? "Because.",
    "",
  ].join("\n");
}

function spec(
  options: { status?: string; prefix?: string; decisions?: string; rules?: string[] } = {},
) {
  return [
    "# Sample",
    "",
    `- Status: ${options.status ?? "agreed"}`,
    `- Prefix: ${options.prefix ?? "FIX"}`,
    `- Decisions: ${options.decisions ?? ADR_A}`,
    "",
    "## Rules",
    "",
    ...(options.rules ?? [`- **FIX-1** Does the thing. (ADR ${ADR_A})`]),
    "",
  ].join("\n");
}

const passed = (title: string) => ({ title, status: "passed" });
const covered = [passed("FIX-1: does the thing")];

const roots: string[] = [];
afterEach(() => {
  for (const root of roots.splice(0)) rmSync(root, { recursive: true, force: true });
});

function repo(files: Record<string, string>) {
  const root = mkdtempSync(join(tmpdir(), "check-specs-"));
  roots.push(root);
  git(root, "init", "-q", "-b", "main");
  write(root, files);
  return root;
}

function write(root: string, files: Record<string, string>) {
  for (const [path, content] of Object.entries(files)) {
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), content);
  }
}

function git(root: string, ...args: string[]) {
  execFileSync(
    "git",
    [
      "-c",
      "user.name=test",
      "-c",
      "user.email=test@example.com",
      "-c",
      "commit.gpgsign=false",
      ...args,
    ],
    { cwd: root, stdio: "ignore" },
  );
}

function commitAll(root: string, message = "snapshot") {
  git(root, "add", "-A");
  git(root, "commit", "-q", "-m", message);
}

const validFiles = () => ({
  [`docs/decisions/${ADR_A}-first.md`]: adr(ADR_A),
  "docs/specs/sample.md": spec(),
});

const adrPath = `docs/decisions/${ADR_A}-first.md`;

describe("check-specs", () => {
  it("passes a consistent repo", () => {
    expect(checkRepo(repo(validFiles()), covered)).toEqual([]);
  });

  it("passes an empty repo", () => {
    expect(checkRepo(repo({}), [])).toEqual([]);
  });

  describe("decisions", () => {
    it("rejects bad file names and impossible timestamps", () => {
      const root = repo({
        "docs/decisions/0001-first.md": adr(ADR_A),
        "docs/decisions/202613010000-bad-month.md": adr("202613010000"),
      });
      const errors = checkRepo(root, []);
      expect(errors).toContainEqual(expect.stringContaining("YYYYMMDDHHMM-slug.md"));
      expect(errors).toContainEqual(expect.stringContaining("not a valid UTC timestamp"));
    });

    it("rejects duplicate timestamps", () => {
      const root = repo({
        [`docs/decisions/${ADR_A}-one.md`]: adr(ADR_A),
        [`docs/decisions/${ADR_A}-two.md`]: adr(ADR_A),
      });
      expect(checkRepo(root, [])).toContainEqual(expect.stringContaining("already used by"));
    });

    it("rejects missing, duplicate, and invalid header fields", () => {
      const root = repo({ [adrPath]: "# First\n\n- Status: maybe\n- Status: accepted\n" });
      const errors = checkRepo(root, []);
      expect(errors).toContainEqual(expect.stringContaining('missing "- Applies to:"'));
      expect(errors).toContainEqual(expect.stringContaining('"Status" is set twice'));
    });

    it("accepts a reciprocal supersession", () => {
      const root = repo({
        [adrPath]: adr(ADR_A, { status: "superseded", supersededBy: ADR_B }),
        [`docs/decisions/${ADR_B}-second.md`]: adr(ADR_B, { supersedes: ADR_A }),
      });
      expect(checkRepo(root, [])).toEqual([]);
    });

    it("rejects one-sided or dangling supersession links", () => {
      const oneSided = repo({
        [adrPath]: adr(ADR_A),
        [`docs/decisions/${ADR_B}-second.md`]: adr(ADR_B, { supersedes: ADR_A }),
      });
      expect(checkRepo(oneSided, [])).toContainEqual(
        expect.stringContaining(`Superseded by ${ADR_B}`),
      );

      const dangling = repo({
        [adrPath]: adr(ADR_A, { status: "superseded", supersededBy: ADR_B }),
      });
      expect(checkRepo(dangling, [])).toContainEqual(expect.stringContaining("does not exist"));
    });

    it("rejects self-supersession, loops, and chains ending at a proposal", () => {
      const self = repo({ [adrPath]: adr(ADR_A, { status: "superseded", supersededBy: ADR_A }) });
      expect(checkRepo(self, [])).toContainEqual(
        expect.stringContaining("cannot supersede itself"),
      );

      const loop = repo({
        [adrPath]: adr(ADR_A, { status: "superseded", supersedes: ADR_B, supersededBy: ADR_B }),
        [`docs/decisions/${ADR_B}-second.md`]: adr(ADR_B, {
          status: "superseded",
          supersedes: ADR_A,
          supersededBy: ADR_A,
        }),
      });
      expect(checkRepo(loop, [])).toContainEqual(expect.stringContaining("loops through"));

      const proposal = repo({
        [adrPath]: adr(ADR_A, { status: "superseded", supersededBy: ADR_B }),
        [`docs/decisions/${ADR_B}-second.md`]: adr(ADR_B, {
          status: "proposed",
          supersedes: ADR_A,
        }),
      });
      expect(checkRepo(proposal, [])).toContainEqual(expect.stringContaining("which is proposed"));
    });

    it("lets a proposed ADR supersede without touching the accepted one yet", () => {
      const root = repo({
        [adrPath]: adr(ADR_A),
        [`docs/decisions/${ADR_B}-second.md`]: adr(ADR_B, {
          status: "proposed",
          supersedes: ADR_A,
        }),
      });
      expect(checkRepo(root, [])).toEqual([]);
    });
  });

  describe("decision history", () => {
    it("allows status-only changes to an accepted ADR", () => {
      const root = repo(validFiles());
      commitAll(root);
      write(root, {
        [adrPath]: adr(ADR_A, { status: "superseded", supersededBy: ADR_B }),
        [`docs/decisions/${ADR_B}-second.md`]: adr(ADR_B, { supersedes: ADR_A }),
        "docs/specs/sample.md": spec({
          decisions: ADR_B,
          rules: [`- **FIX-1** Does it. (ADR ${ADR_B})`],
        }),
      });
      expect(checkRepo(root, covered)).toEqual([]);
      commitAll(root);
      expect(checkRepo(root, covered)).toEqual([]);
    });

    it("rejects edits to an accepted ADR, committed or not, until reverted", () => {
      const root = repo({ [adrPath]: adr(ADR_A) });
      commitAll(root);
      write(root, { [adrPath]: adr(ADR_A, { body: "Changed my mind." }) });
      expect(checkRepo(root, [])).toContainEqual(expect.stringContaining("immutable"));
      commitAll(root);
      expect(checkRepo(root, [])).toContainEqual(expect.stringContaining("immutable"));
      write(root, { [adrPath]: adr(ADR_A) });
      expect(checkRepo(root, [])).toContainEqual(expect.stringContaining("immutable"));
    });

    it("freezes an ADR from the commit that accepts it", () => {
      const root = repo({ [adrPath]: adr(ADR_A, { status: "proposed" }) });
      commitAll(root);
      write(root, { [adrPath]: adr(ADR_A, { status: "proposed", body: "Reworded." }) });
      commitAll(root);
      expect(checkRepo(root, [])).toEqual([]);

      write(root, { [adrPath]: adr(ADR_A, { body: "Reworded." }) });
      commitAll(root);
      expect(checkRepo(root, [])).toEqual([]);

      write(root, { [adrPath]: adr(ADR_A, { body: "Edited after acceptance." }) });
      commitAll(root);
      expect(checkRepo(root, [])).toContainEqual(expect.stringContaining("immutable"));
    });

    it("sees an ADR accepted while resolving a merge", () => {
      const root = repo({ [adrPath]: adr(ADR_A, { status: "proposed" }), "a.txt": "base" });
      commitAll(root);
      git(root, "checkout", "-q", "-b", "side");
      write(root, { "a.txt": "side" });
      commitAll(root);
      git(root, "checkout", "-q", "main");
      write(root, { "b.txt": "main" });
      commitAll(root);
      git(root, "merge", "-q", "--no-ff", "--no-commit", "side");
      write(root, { [adrPath]: adr(ADR_A) });
      commitAll(root, "merge side");

      write(root, { [adrPath]: adr(ADR_A, { body: "Edited after the merge." }) });
      commitAll(root);
      expect(checkRepo(root, [])).toContainEqual(expect.stringContaining("immutable"));
    });

    it("rejects deleting or renaming an accepted ADR", () => {
      const root = repo({ [adrPath]: adr(ADR_A) });
      commitAll(root);
      rmSync(join(root, adrPath));
      write(root, { [`docs/decisions/${ADR_A}-renamed.md`]: adr(ADR_A) });
      expect(checkRepo(root, [])).toContainEqual(
        expect.stringContaining("may not be deleted or renamed"),
      );
    });

    it("rejects moving an accepted ADR back to proposed", () => {
      const root = repo({ [adrPath]: adr(ADR_A) });
      commitAll(root);
      write(root, { [adrPath]: adr(ADR_A, { status: "proposed" }) });
      expect(checkRepo(root, [])).toContainEqual(expect.stringContaining("back to proposed"));
    });

    it("skips history in a repo with no commits", () => {
      expect(checkRepo(repo({ [adrPath]: adr(ADR_A) }), [])).toEqual([]);
    });

    it("fails on shallow history", () => {
      const root = repo({ [adrPath]: adr(ADR_A) });
      commitAll(root);
      write(root, { "a.txt": "more" });
      commitAll(root);
      const clone = mkdtempSync(join(tmpdir(), "check-specs-clone-"));
      roots.push(clone);
      git(clone, "clone", "-q", "--depth", "1", `file://${root}`, ".");
      expect(checkRepo(clone, [])).toContainEqual(expect.stringContaining("shallow"));
    });

    it("fails when git cannot read the repository", () => {
      const root = repo({ [adrPath]: adr(ADR_A) });
      writeFileSync(join(root, ".git/HEAD"), "garbage\n");
      expect(checkRepo(root, [])).toContainEqual(expect.stringContaining("git failed"));
    });
  });

  describe("specs", () => {
    it("rejects anything under Rules that is not a rule", () => {
      const bad = [
        "- FIX-2 forgot the bold",
        "1. **FIX-2** Numbered.",
        "Some prose.",
        "  - **FIX-2** Nested.",
      ];
      for (const line of bad) {
        const root = repo({
          ...validFiles(),
          "docs/specs/sample.md": spec({ rules: [`- **FIX-1** Does it. (ADR ${ADR_A})`, line] }),
        });
        expect(checkRepo(root, covered), line).toContainEqual(
          expect.stringContaining('only rules go under "## Rules"'),
        );
      }
    });

    it("allows indented continuation lines", () => {
      const root = repo({
        ...validFiles(),
        "docs/specs/sample.md": spec({
          rules: [`- **FIX-1** Does it. (ADR ${ADR_A})`, "  More detail."],
        }),
      });
      expect(checkRepo(root, covered)).toEqual([]);
    });

    it("requires at least one rule once a spec is agreed", () => {
      const root = repo({ ...validFiles(), "docs/specs/sample.md": spec({ rules: [] }) });
      expect(checkRepo(root, [])).toContainEqual(
        expect.stringContaining("needs at least one rule"),
      );
    });

    it("rejects duplicate rule IDs, foreign prefixes, and shared prefixes", () => {
      const root = repo({
        ...validFiles(),
        "docs/specs/sample.md": spec({
          rules: [
            `- **FIX-1** One. (ADR ${ADR_A})`,
            "- **FIX-1** Again.",
            "- **OTHER-1** Wrong prefix.",
          ],
        }),
        "docs/specs/twin.md": spec({ status: "draft", rules: [] }),
      });
      const errors = checkRepo(root, covered);
      expect(errors).toContainEqual(expect.stringContaining("defined twice"));
      expect(errors).toContainEqual(expect.stringContaining("does not use this spec's Prefix"));
      expect(errors).toContainEqual(expect.stringContaining("Prefix FIX is already used"));
    });

    it("rejects citations outside Decisions, missing ADRs, and superseded ADRs", () => {
      const root = repo({
        [adrPath]: adr(ADR_A, { status: "superseded", supersededBy: ADR_B }),
        [`docs/decisions/${ADR_B}-second.md`]: adr(ADR_B, { supersedes: ADR_A }),
        "docs/specs/sample.md": spec({
          decisions: ADR_A,
          rules: [
            `- **FIX-1** Old. (ADR ${ADR_A})`,
            `- **FIX-2** Unlisted. (ADR ${ADR_B})`,
            "- **FIX-3** Ghost. (ADR 202601010000)",
          ],
        }),
      });
      const errors = checkRepo(root, [passed("FIX-1, FIX-2, FIX-3: all")]);
      expect(errors).toContainEqual(
        expect.stringContaining(`Decisions lists ${ADR_A}, which is superseded`),
      );
      expect(errors).toContainEqual(
        expect.stringContaining(`cites ADR ${ADR_A}, which is superseded`),
      );
      expect(errors).toContainEqual(
        expect.stringContaining(`cites ADR ${ADR_B}, which is not in Decisions`),
      );
      expect(errors).toContainEqual(expect.stringContaining("which does not exist"));
    });
  });

  describe("traceability", () => {
    it("requires a passing test for every implemented rule", () => {
      const root = repo({
        ...validFiles(),
        "docs/specs/sample.md": spec({ status: "implemented" }),
      });
      expect(checkRepo(root, [])).toContainEqual(
        expect.stringContaining("FIX-1 has no passing test"),
      );
      expect(checkRepo(root, [{ title: "FIX-1: later", status: "skipped" }])).toContainEqual(
        expect.stringContaining("FIX-1 has no passing test"),
      );
    });

    it("exempts draft and agreed specs from test coverage", () => {
      for (const status of ["draft", "agreed"]) {
        const root = repo({ ...validFiles(), "docs/specs/sample.md": spec({ status }) });
        expect(checkRepo(root, []), status).toEqual([]);
      }
    });

    it("rejects tests that name unknown rules, including misspelled prefixes", () => {
      const root = repo(validFiles());
      expect(checkRepo(root, [...covered, passed("FXI-1: typo")])).toContainEqual(
        expect.stringContaining("names FXI-1, which no spec defines"),
      );
    });

    it("ignores titles that do not start with rule IDs", () => {
      const root = repo({
        ...validFiles(),
        "docs/specs/sample.md": spec({ status: "implemented" }),
      });
      expect(checkRepo(root, [passed("covers FIX-1 eventually")])).toContainEqual(
        expect.stringContaining("FIX-1 has no passing test"),
      );
    });
  });

  describe("test report", () => {
    const report = JSON.stringify({
      testResults: [
        { assertionResults: [{ title: "FIX-1: works", status: "passed", fullName: "x" }] },
      ],
    });

    it("reads titles and statuses from the Vitest JSON report", () => {
      const root = repo({ "tests/a.test.ts": "", [TEST_REPORT]: report });
      expect(readTestReport(root)).toEqual({
        tests: [{ title: "FIX-1: works", status: "passed" }],
      });
    });

    it("fails when the report is missing or older than the tests", () => {
      const missing = repo({ "tests/a.test.ts": "" });
      expect(readTestReport(missing)).toEqual({ error: expect.stringContaining("missing") });

      const stale = repo({ [TEST_REPORT]: report, "tests/a.test.ts": "" });
      const past = new Date(Date.now() - 60_000);
      utimesSync(join(stale, TEST_REPORT), past, past);
      expect(readTestReport(stale)).toEqual({
        error: expect.stringContaining("older than tests/"),
      });
    });
  });
});
