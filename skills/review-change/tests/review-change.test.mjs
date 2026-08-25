import assert from "node:assert/strict";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const skillDir = resolve(import.meta.dirname, "..");
const publicBin = join(skillDir, "bin", "review-change");

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    encoding: "utf8",
    ...options,
  });
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} failed:\n${result.stderr}`);
  }
  return result.stdout.trim();
}

function createRepository() {
  const sandbox = mkdtempSync(join(tmpdir(), "review-change-"));
  const repository = join(sandbox, "repo");
  run("git", ["init", "-q", "-b", "main", repository]);
  run("git", ["config", "user.email", "test@example.com"], { cwd: repository });
  run("git", ["config", "user.name", "Review Change Test"], { cwd: repository });
  run("git", ["config", "commit.gpgsign", "false"], { cwd: repository });
  writeFileSync(join(repository, "example.txt"), "base\n");
  writeFileSync(join(repository, ".gitignore"), ".agents/\n");
  run("git", ["add", "example.txt", ".gitignore"], { cwd: repository });
  run("git", ["commit", "-q", "-m", "base"], { cwd: repository });
  run("git", ["switch", "-q", "-c", "feature/review"], { cwd: repository });
  writeFileSync(join(repository, "example.txt"), "base\nchanged\n");
  run("git", ["add", "example.txt"], { cwd: repository });
  run("git", ["commit", "-q", "-m", "change"], { cwd: repository });
  return { sandbox, repository };
}

function prepareReview(repository, artifactRoot, env = {}) {
  return JSON.parse(run(publicBin, ["collect"], {
    cwd: repository,
    env: { ...process.env, ...env, AGENTS_ARTIFACTS_ROOT: artifactRoot },
  }));
}

function findContext(root) {
  for (const entry of readdirSync(root, { withFileTypes: true })) {
    const path = join(root, entry.name);
    if (entry.isDirectory()) {
      const found = findContext(path);
      if (found) return found;
    } else if (entry.name === "context.json" && path.includes(`${join("review-change", "context.json")}`)) {
      return path;
    }
  }
  return null;
}

function renderReview(repository, artifactRoot, env = {}) {
  const contextPath = findContext(artifactRoot);
  if (contextPath) {
    const context = JSON.parse(readFileSync(contextPath, "utf8"));
    if (context.passes.at(-1)?.status === "collected") summarizeReview(repository, artifactRoot, env, contextPath);
  }
  return JSON.parse(run(publicBin, ["render"], {
    cwd: repository,
    env: { ...process.env, ...env, AGENTS_ARTIFACTS_ROOT: artifactRoot },
  }));
}

function summaryFor(context) {
  let summary = existsSync(context.summary.data) ? JSON.parse(readFileSync(context.summary.data, "utf8")) : {
    version: 1,
    study: {
      revision: 1,
      writtenAtPass: 1,
      refreshReason: null,
      oneSentence: "The change adds one observable line.",
      purpose: "Exercise the review workflow with a small behavior change.",
      claimedIntent: ["Change the example."],
      observedBehavior: ["The example gains a line."],
      before: ["The line is absent."],
      after: ["The line is present."],
      flow: [{ step: "Read the example", explanation: "The changed value is consumed.", evidence: ["example.txt:2"] }],
      components: [{ name: "example.txt", role: "Test fixture", reason: "It contains the changed behavior.", evidence: ["example.txt:2"] }],
      contracts: [],
      unknowns: [],
    },
    updates: [],
  };
  for (const pass of context.passes) {
    if (summary.updates.some((update) => update.pass === pass.number)) continue;
    summary.updates.push({
      pass: pass.number,
      kind: pass.kind,
      head: pass.head,
      summary: pass.kind === "full" ? "Initial change and full reach." : "Delta from the previous reviewed state.",
      changes: pass.changes,
      blastRadius: ["direct", "glue", "contract", "parallel", "integration", "operational"].map((ring) => ({
        ring,
        status: ring === "direct" ? "checked" : "not_applicable",
        scope: ring === "direct" ? ["example.txt"] : [],
        notes: ring === "direct" ? "The changed fixture was inspected." : "This ring does not apply to the fixture.",
        evidence: ring === "direct" ? ["example.txt:2"] : [],
      })),
      reviewTargets: [],
    });
  }
  return summary;
}

function summarizeReview(repository, artifactRoot, env = {}, contextPath = null) {
  contextPath ??= findContext(artifactRoot);
  const context = JSON.parse(readFileSync(contextPath, "utf8"));
  writeFileSync(context.summary.data, `${JSON.stringify(summaryFor(context), null, 2)}\n`);
  return JSON.parse(run(publicBin, ["render-summary"], {
    cwd: repository,
    env: { ...process.env, ...env, AGENTS_ARTIFACTS_ROOT: artifactRoot },
  }));
}

function approvalReview(summary = "Nothing consequential found.") {
  return {
    version: 1,
    summary,
    body: summary,
    verdict: { value: "approve", reason: "No blocking findings." },
    coverage: { reviewed: [], notReviewed: [], confidence: "high" },
    reconciliation: [],
    findings: [],
    tests: { run: [], gaps: [] },
  };
}

function readEmbeddedData(path, id) {
  const document = readFileSync(path, "utf8");
  const opening = `<script id="${id}" type="application/json">`;
  const start = document.indexOf(opening);
  const end = document.indexOf("</script>", start);
  assert.notEqual(start, -1);
  assert.notEqual(end, -1);
  return JSON.parse(document.slice(start + opening.length, end));
}

const readReportData = (path) => readEmbeddedData(path, "report-data");
const readIndexData = (path) => readEmbeddedData(path, "series-data");

test("the public bin collects and repeatably renders a review", () => {
  const { sandbox, repository } = createRepository();
  const artifacts = join(sandbox, "artifacts");
  const collected = JSON.parse(run(publicBin, ["collect"], {
    cwd: repository,
    env: { ...process.env, AGENTS_ARTIFACTS_ROOT: artifacts },
  }));
  writeFileSync(collected.review, `${JSON.stringify({
    version: 1,
    summary: "Ready to merge.",
    body: "Looks good.",
    verdict: { value: "approve", reason: "No blocking findings." },
    coverage: { reviewed: ["example.txt"], notReviewed: [], confidence: "high" },
    reconciliation: [],
    findings: [],
    tests: { run: [], gaps: [] },
  })}\n`);
  summarizeReview(repository, artifacts, {}, collected.context);

  const first = JSON.parse(run(publicBin, ["render"], {
    cwd: repository,
    env: { ...process.env, AGENTS_ARTIFACTS_ROOT: artifacts },
  }));
  const second = JSON.parse(run(publicBin, ["render"], {
    cwd: repository,
    env: { ...process.env, AGENTS_ARTIFACTS_ROOT: artifacts },
  }));
  const obsolete = spawnSync(publicBin, ["prepare"], { cwd: repository, encoding: "utf8" });

  assert.equal(collected.status, "ready");
  assert.equal(collected.context.startsWith(`${artifacts}/`), true);
  assert.equal(first.report, second.report);
  assert.equal(first.pass, 1);
  assert.equal(second.pass, 1);
  assert.equal(existsSync(first.index), true);
  assert.notEqual(obsolete.status, 0);
});

test("render enforces the verdict from blocking findings", () => {
  const { sandbox, repository } = createRepository();
  const artifacts = join(sandbox, "artifacts");
  const env = { ...process.env, AGENTS_ARTIFACTS_ROOT: artifacts };
  const collected = JSON.parse(run(publicBin, ["collect"], { cwd: repository, env }));
  const review = {
    version: 1,
    summary: "A merge-blocking issue remains.",
    body: "Please address the inline finding.",
    verdict: { value: "approve", reason: "Inconsistent on purpose." },
    coverage: { reviewed: ["example.txt"], notReviewed: [], confidence: "high" },
    reconciliation: [],
    findings: [{
      id: "C1",
      severity: "critical",
      blocking: true,
      title: "Preserve the value",
      location: { path: "example.txt", line: 2 },
      explanation: "The value is discarded.",
      impact: "User data is lost.",
      suggestion: "Preserve it.",
      comment: "Please preserve this value.",
      posting: "pending",
    }],
    tests: { run: [], gaps: [] },
  };
  writeFileSync(collected.review, `${JSON.stringify(review)}\n`);
  summarizeReview(repository, artifacts, {}, collected.context);

  const inconsistentApproval = spawnSync(publicBin, ["render"], { cwd: repository, env, encoding: "utf8" });
  assert.notEqual(inconsistentApproval.status, 0);
  assert.match(inconsistentApproval.stderr, /approve.*blocking finding/i);

  review.verdict = { value: "reject", reason: "The blocking finding must be fixed." };
  writeFileSync(collected.review, `${JSON.stringify(review)}\n`);
  const rendered = JSON.parse(run(publicBin, ["render"], { cwd: repository, env }));
  assert.equal(readReportData(rendered.report).review.verdict.value, "reject");
});

test("collect creates a JSON context and allocates an AI-owned review", () => {
  const { sandbox, repository } = createRepository();
  const prepared = prepareReview(repository, join(sandbox, "artifacts"));
  const context = JSON.parse(readFileSync(prepared.context, "utf8"));

  assert.equal(prepared.status, "ready");
  assert.equal(prepared.context.endsWith("/context.json"), true);
  assert.equal(context.version, 2);
  assert.equal(context.change.mode, "local");
  assert.equal(context.change.branch, "feature/review");
  assert.equal(context.passes.length, 1);
  assert.equal(context.passes[0].number, 1);
  assert.equal(context.passes[0].kind, "full");
  assert.equal(context.passes[0].status, "collected");
  assert.equal(prepared.summary.endsWith("/summary.json"), true);
  assert.equal(context.output, context.passes[0].review);
  assert.match(readFileSync(context.passes[0].diff, "utf8"), /\+changed/);
  assert.equal(existsSync(context.output), false);
});

test("render records AI-authored review JSON", () => {
  const { sandbox, repository } = createRepository();
  const artifacts = join(sandbox, "artifacts");
  const prepared = prepareReview(repository, artifacts);

  const unfinished = spawnSync(publicBin, ["render"], {
    cwd: repository,
    encoding: "utf8",
    env: { ...process.env, AGENTS_ARTIFACTS_ROOT: artifacts },
  });
  assert.notEqual(unfinished.status, 0);

  const review = approvalReview();
  review.body = "Safe text </script><script>alert('nope')</script>";
  review.arbitraryReviewerJudgment = { confidence: "considered" };
  writeFileSync(prepared.review, `${JSON.stringify(review, null, 2)}\n`);
  const finished = renderReview(repository, artifacts);
  const context = JSON.parse(readFileSync(prepared.context, "utf8"));

  assert.equal(finished.review, prepared.review);
  assert.equal(finished.summary.endsWith("/summary.html"), true);
  assert.equal(finished.report.endsWith("/01.report.html"), true);
  assert.equal(finished.pass, 1);
  assert.equal(context.passes[0].status, "complete");
  assert.equal(context.passes[0].report, finished.report);
  assert.equal(existsSync(finished.report), true);
  assert.equal(existsSync(finished.summary), true);
  assert.match(readFileSync(finished.summary, "utf8"), /Study the change/);
  assert.match(readFileSync(finished.report, "utf8"), /Terminal handoff/);
  assert.doesNotMatch(readFileSync(finished.report, "utf8"), /<script>alert\('nope'\)<\/script>/);
  assert.deepEqual(JSON.parse(readFileSync(prepared.review, "utf8")), review);
});

test("collect appends an incremental pass after a completed review", () => {
  const { sandbox, repository } = createRepository();
  const artifacts = join(sandbox, "artifacts");
  const first = prepareReview(repository, artifacts);
  writeFileSync(first.review, `${JSON.stringify({
    summary: "first pass",
    verdict: { value: "reject", reason: "The original issue remains." },
    findings: [{ id: "W1", severity: "warning", blocking: true, title: "Preserve the value", explanation: "The value is discarded.", posting: "pending" }],
  })}\n`);
  const firstFinished = renderReview(repository, artifacts);

  writeFileSync(join(repository, "example.txt"), "base\nchanged\nlater\n");
  const second = prepareReview(repository, artifacts);
  const context = JSON.parse(readFileSync(second.context, "utf8"));
  const incremental = readFileSync(second.diff, "utf8");
  const firstWhileSecondPending = readReportData(firstFinished.report);

  assert.equal(context.passes.length, 2);
  assert.equal(context.passes[0].status, "complete");
  assert.equal(context.passes[1].number, 2);
  assert.equal(context.passes[1].kind, "incremental");
  assert.equal(context.passes[1].status, "collected");
  assert.deepEqual(context.passes[1].changes, { code: true, activity: false });
  assert.equal(second.review.endsWith("/02.review.json"), true);
  assert.match(incremental, /\+later/);
  assert.doesNotMatch(incremental, /\+changed/);
  assert.equal(existsSync(second.review), false);
  assert.equal(firstWhileSecondPending.historical, true);
  assert.equal(firstWhileSecondPending.submit, null);

  writeFileSync(second.review, `${JSON.stringify({
    summary: "second pass",
    verdict: { value: "approve", reason: "Only the carried-over note remains." },
    findings: [{
      id: "W1",
      severity: "warning",
      blocking: false,
      title: "Preserve the value",
      explanation: "The value is still discarded.",
      posting: "pending",
      carriedFrom: { pass: 1, findingId: "W1" },
    }],
  })}\n`);
  const secondFinished = renderReview(repository, artifacts);
  const firstReport = readReportData(firstFinished.report);
  const secondReport = readReportData(secondFinished.report);
  const index = readIndexData(secondFinished.index);
  const summary = readEmbeddedData(secondFinished.summary, "summary-data");

  assert.equal(existsSync(secondFinished.index), true);
  assert.deepEqual(firstReport.navigation, { index: "index.html", summary: "summary.html#pass-01", previous: null, next: "02.report.html" });
  assert.equal(firstReport.historical, true);
  assert.equal(firstReport.submit, null);
  assert.deepEqual(secondReport.navigation, { index: "index.html", summary: "summary.html#pass-02", previous: "01.report.html", next: null });
  assert.equal(secondReport.historical, false);
  assert.equal(secondReport.display.verdict, "Approve");
  assert.deepEqual(secondReport.carryOvers.W1, {
    pass: 1,
    findingId: "W1",
    href: "01.report.html#finding-W1",
    title: "Preserve the value",
    explanation: "The value is discarded.",
  });
  assert.deepEqual(index.passes.map((pass) => pass.href), ["01.report.html", "02.report.html"]);
  assert.deepEqual(index.passes.map((pass) => pass.summaryHref), ["summary.html#pass-01", "summary.html#pass-02"]);
  assert.equal(index.latest, "02.report.html");
  assert.equal(summary.summary.study.revision, 1);
  assert.equal(summary.summary.updates.length, 2);
  assert.equal(summary.summary.updates[1].kind, "incremental");
});

test("summary checkpoint publishes context while findings remain in progress", () => {
  const { sandbox, repository } = createRepository();
  const artifacts = join(sandbox, "artifacts");
  const prepared = prepareReview(repository, artifacts);
  const summarized = summarizeReview(repository, artifacts, {}, prepared.context);
  const context = JSON.parse(readFileSync(prepared.context, "utf8"));
  const summary = readEmbeddedData(summarized.report, "summary-data");
  const index = readIndexData(summarized.index);

  assert.equal(summarized.status, "summarized");
  assert.equal(context.passes[0].status, "summarized");
  assert.equal(existsSync(summarized.report), true);
  assert.equal(summary.summary.study.oneSentence, "The change adds one observable line.");
  assert.equal(summary.change.mode, "local");
  assert.equal(summary.summary.updates[0].blastRadius.length, 6);
  assert.equal(index.summary.href, "summary.html");
  assert.equal(index.passes[0].status, "summarized");
  assert.equal(index.passes[0].href, null);
  assert.equal(index.passes[0].summaryHref, "summary.html#pass-01");

  const prematureCollect = spawnSync(publicBin, ["collect"], {
    cwd: repository,
    encoding: "utf8",
    env: { ...process.env, AGENTS_ARTIFACTS_ROOT: artifacts },
  });
  assert.notEqual(prematureCollect.status, 0);
  assert.match(prematureCollect.stderr, /complete pass 1/i);
});

test("collect exits early when code and PR activity are unchanged", () => {
  const { sandbox, repository } = createRepository();
  const artifacts = join(sandbox, "artifacts");
  const first = prepareReview(repository, artifacts);
  writeFileSync(first.review, `${JSON.stringify(approvalReview("first pass"))}\n`);
  renderReview(repository, artifacts);

  const unchanged = prepareReview(repository, artifacts);
  const context = JSON.parse(readFileSync(unchanged.context, "utf8"));

  assert.equal(unchanged.status, "unchanged");
  assert.equal(unchanged.pass, 1);
  assert.equal(context.passes.length, 1);
  assert.equal(existsSync(join(first.context, "..", "02.diff")), false);
});

test("collect records raw pull request activity when one exists", () => {
  const { sandbox, repository } = createRepository();
  const bin = join(sandbox, "bin");
  mkdirSync(bin);
  run("git", ["remote", "add", "origin", "https://github.com/acme/widgets.js.git"], { cwd: repository });
  const fakeGh = join(bin, "gh");
  writeFileSync(fakeGh, `#!/usr/bin/env bash
if [[ "$1 $2" == "--version " ]]; then
  printf 'gh version test\\n'
elif [[ "$1 $2" == "pr view" ]]; then
  head=$(git rev-parse HEAD)
  printf '{"number":42,"title":"Improve widgets","body":"PR intent","url":"https://github.com/acme/widgets/pull/42","baseRefName":"main","headRefName":"feature/review","headRefOid":"%s","state":"OPEN"}\\n' "$head"
elif [[ "$1 $2" == "api user" ]]; then
  printf 'owner\\n'
elif [[ "$1" == "api" && "$2" == */issues/*/comments ]]; then
  printf '[{"id":1,"user":{"login":"reviewer"},"body":"Conversation note"}]\\n'
elif [[ "$1" == "api" && "$2" == */pulls/*/comments ]]; then
  printf '[{"id":2,"html_url":"https://github.com/acme/widgets/pull/42#discussion_r2","user":{"login":"reviewer"},"path":"example.txt","line":2,"body":"Existing concern"}]\\n'
elif [[ "$1" == "api" && "$2" == */reviews ]]; then
  printf '[{"body":"Existing review"}]\\n'
else
  exit 1
fi
`);
  chmodSync(fakeGh, 0o755);

  const artifacts = join(sandbox, "artifacts");
  const prepared = JSON.parse(run(publicBin, ["collect"], {
    cwd: repository,
    env: {
      ...process.env,
      PATH: `${bin}:${process.env.PATH}`,
      AGENTS_ARTIFACTS_ROOT: artifacts,
    },
  }));
  const context = JSON.parse(readFileSync(prepared.context, "utf8"));
  const activity = JSON.parse(readFileSync(context.passes[0].activity, "utf8"));

  assert.equal(context.change.mode, "pr");
  assert.equal(context.change.repository, "acme/widgets.js");
  assert.equal(activity.metadata.number, 42);
  assert.equal(activity.comments.conversation[0].body, "Conversation note");
  assert.equal(activity.comments.inline[0].body, "Existing concern");
  assert.equal(activity.comments.reviews[0].body, "Existing review");

  writeFileSync(prepared.review, `${JSON.stringify({
    version: 1,
    summary: "One concern was already raised.",
    body: "The existing nit is already covered.",
    verdict: { value: "approve", reason: "No blocking findings." },
    coverage: { reviewed: ["example.txt"], notReviewed: [], confidence: "high" },
    reconciliation: [],
    findings: [{
      id: "N1",
      severity: "nit",
      blocking: false,
      title: "Existing concern",
      posting: "duplicate",
      duplicateOf: { kind: "inline", id: 2 },
    }],
    tests: { run: [], gaps: [] },
  }, null, 2)}\n`);
  const finished = renderReview(repository, artifacts, { PATH: `${bin}:${process.env.PATH}` });
  assert.deepEqual(readReportData(finished.report).duplicates.N1, {
    kind: "inline",
    id: 2,
    author: "reviewer",
    body: "Existing concern",
    url: "https://github.com/acme/widgets/pull/42#discussion_r2",
  });
});

test("collect opens an activity-only pass for a new reviewer comment", () => {
  const { sandbox, repository } = createRepository();
  const bin = join(sandbox, "bin");
  const activityFile = join(sandbox, "conversation.json");
  const artifacts = join(sandbox, "artifacts");
  mkdirSync(bin);
  run("git", ["remote", "add", "origin", "https://github.com/acme/widgets.git"], { cwd: repository });
  writeFileSync(activityFile, "[]\n");
  const fakeGh = join(bin, "gh");
  writeFileSync(fakeGh, `#!/usr/bin/env bash
if [[ "$1 $2" == "--version " ]]; then
  printf 'gh version test\\n'
elif [[ "$1 $2" == "pr view" ]]; then
  head=$(git rev-parse HEAD)
  printf '{"number":42,"title":"Improve widgets","body":"PR intent","url":"https://github.com/acme/widgets/pull/42","baseRefName":"main","headRefName":"feature/review","headRefOid":"%s","state":"OPEN"}\\n' "$head"
elif [[ "$1 $2" == "api user" ]]; then
  printf 'owner\\n'
elif [[ "$1" == "api" && "$2" == */issues/*/comments ]]; then
  cat "$FAKE_GH_ACTIVITY"
elif [[ "$1" == "api" && "$2" == */pulls/*/comments ]]; then
  printf '[]\\n'
elif [[ "$1" == "api" && "$2" == */reviews ]]; then
  printf '[]\\n'
else
  exit 1
fi
`);
  chmodSync(fakeGh, 0o755);
  const env = { PATH: `${bin}:${process.env.PATH}`, FAKE_GH_ACTIVITY: activityFile };

  const first = prepareReview(repository, artifacts, env);
  writeFileSync(first.review, `${JSON.stringify(approvalReview("first pass"))}\n`);
  renderReview(repository, artifacts, env);

  const unchanged = prepareReview(repository, artifacts, env);
  assert.equal(unchanged.status, "unchanged");

  writeFileSync(activityFile, '[{"id":6,"user":{"login":"owner"},"body":"Our submitted review"}]\n');
  const ownActivity = prepareReview(repository, artifacts, env);
  assert.equal(ownActivity.status, "unchanged");

  writeFileSync(activityFile, '[{"id":6,"user":{"login":"owner"},"body":"Our submitted review"},{"id":7,"user":{"login":"review-bot[bot]"},"body":"New concern"}]\n');

  const second = prepareReview(repository, artifacts, env);
  const context = JSON.parse(readFileSync(second.context, "utf8"));
  const activity = JSON.parse(readFileSync(second.activity, "utf8"));

  assert.equal(second.status, "ready");
  assert.equal(readFileSync(second.diff, "utf8"), "");
  assert.deepEqual(context.passes[1].changes, { code: false, activity: true });
  assert.equal(activity.comments.conversation.some((comment) => comment.user.login === "review-bot[bot]"), true);
});

test("the report command submits selected findings and records the result", () => {
  const { sandbox, repository } = createRepository();
  const bin = join(sandbox, "bin");
  const headFile = join(sandbox, "head.txt");
  const payloadFile = join(sandbox, "payload.json");
  const artifacts = join(sandbox, "artifacts");
  mkdirSync(bin);
  run("git", ["remote", "add", "origin", "https://github.com/acme/widgets.git"], { cwd: repository });
  const reviewedHead = run("git", ["rev-parse", "HEAD"], { cwd: repository });
  writeFileSync(headFile, `${reviewedHead}\n`);
  const fakeGh = join(bin, "gh");
  writeFileSync(fakeGh, `#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then
  printf 'gh version test\\n'
elif [[ "$1 $2" == "pr view" ]]; then
  head=$(cat "$FAKE_GH_HEAD")
  printf '{"number":42,"title":"Improve widgets","body":"PR intent","url":"https://github.com/acme/widgets/pull/42","baseRefName":"main","headRefName":"feature/review","headRefOid":"%s","state":"OPEN"}\\n' "$head"
elif [[ "$1 $2" == "api user" ]]; then
  printf 'owner\\n'
elif [[ "$1" == "api" && "$*" == *"--method POST"* ]]; then
  cat > "$FAKE_GH_PAYLOAD"
  printf '{"html_url":"https://github.com/acme/widgets/pull/42#pullrequestreview-9"}\\n'
elif [[ "$1" == "api" && "$2" == */comments ]]; then
  printf '[]\\n'
elif [[ "$1" == "api" && "$2" == */reviews ]]; then
  printf '[]\\n'
else
  exit 1
fi
`);
  chmodSync(fakeGh, 0o755);
  const env = {
    PATH: `${bin}:${process.env.PATH}`,
    FAKE_GH_HEAD: headFile,
    FAKE_GH_PAYLOAD: payloadFile,
    AGENTS_ARTIFACTS_ROOT: artifacts,
  };
  const prepared = prepareReview(repository, artifacts, env);
  const review = {
    version: 1,
    summary: "One blocking issue.",
    body: "Please address the inline finding before merge.",
    verdict: { value: "reject", reason: "The failure path loses data." },
    coverage: { reviewed: ["example.txt"], notReviewed: [], confidence: "high" },
    reconciliation: [],
    findings: [{
      id: "C1",
      severity: "critical",
      blocking: true,
      title: "Preserve the input",
      location: { path: "example.txt", line: 2 },
      explanation: "The new path drops the value.",
      impact: "User data can be lost.",
      suggestion: "Carry the original value forward.",
      comment: "This drops the original value; please preserve it here.",
      posting: "pending",
    }],
    tests: { run: [], gaps: [] },
  };
  writeFileSync(prepared.review, `${JSON.stringify(review, null, 2)}\n`);
  const finished = renderReview(repository, artifacts, env);
  const reportBefore = readFileSync(finished.report, "utf8");
  assert.deepEqual(readReportData(finished.report).submit.tokens, [publicBin, "submit"]);
  assert.match(reportBefore, /Terminal handoff/);
  assert.match(reportBefore, /Top-level review message/);
  assert.match(reportBefore, /Reset message/);
  assert.doesNotMatch(reportBefore, /__REVIEW_CHANGE_(?:PASS|DATA)__/);
  assert.equal(reportBefore.includes(prepared.context), false);

  writeFileSync(headFile, `${"0".repeat(40)}\n`);
  const stale = spawnSync(publicBin, ["submit", "C1", "--message", "Good job, here is the blocking feedback."], {
    cwd: repository,
    encoding: "utf8",
    env: { ...process.env, ...env },
  });
  assert.notEqual(stale.status, 0);
  assert.match(stale.stderr, /pull request HEAD changed/);

  writeFileSync(headFile, `${reviewedHead}\n`);
  const submitted = JSON.parse(run(publicBin, ["submit", "C1", "--message", "Good job, here is the blocking feedback."], {
    cwd: repository,
    env: { ...process.env, ...env },
  }));
  const savedReview = JSON.parse(readFileSync(prepared.review, "utf8"));
  const payload = JSON.parse(readFileSync(payloadFile, "utf8"));

  assert.equal(submitted.status, "submitted");
  assert.equal(submitted.event, "REQUEST_CHANGES");
  assert.equal(savedReview.findings[0].posting, "posted");
  assert.equal(savedReview.submissions[0].url, submitted.url);
  assert.equal(payload.commit_id, reviewedHead);
  assert.equal(payload.body, "Good job, here is the blocking feedback.");
  assert.equal(payload.comments[0].body, review.findings[0].comment);
  assert.match(readFileSync(finished.report, "utf8"), /"posting":"posted"/);
});

test("collect archives invalid history and restarts with a full pass", () => {
  const { sandbox, repository } = createRepository();
  const artifacts = join(sandbox, "artifacts");
  const first = prepareReview(repository, artifacts);
  writeFileSync(first.review, `${JSON.stringify(approvalReview("reviewed before rebase"))}\n`);
  renderReview(repository, artifacts);

  run("git", ["switch", "-q", "main"], { cwd: repository });
  writeFileSync(join(repository, "base.txt"), "new base\n");
  run("git", ["add", "base.txt"], { cwd: repository });
  run("git", ["commit", "-q", "-m", "move base"], { cwd: repository });
  run("git", ["switch", "-q", "feature/review"], { cwd: repository });
  run("git", ["rebase", "-q", "main"], { cwd: repository });

  const restarted = prepareReview(repository, artifacts);
  const context = JSON.parse(readFileSync(restarted.context, "utf8"));
  const archiveRoot = join(restarted.context, "..", "archive");
  const archivedSeries = readdirSync(archiveRoot);

  assert.equal(context.passes.length, 1);
  assert.equal(context.passes[0].number, 1);
  assert.equal(context.passes[0].kind, "full");
  assert.equal(restarted.diff.endsWith("/01.diff"), true);
  assert.equal(archivedSeries.length, 1);
  assert.equal(existsSync(join(archiveRoot, archivedSeries[0], "01.review.json")), true);
});

test("the public entrypoint explains the Node.js dependency", () => {
  const result = spawnSync("/bin/bash", [publicBin, "collect"], {
    encoding: "utf8",
    env: { ...process.env, PATH: "/usr/bin:/bin" },
  });

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /requires Node\.js 18 or newer/);
});
