import assert from "node:assert/strict";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, realpathSync, writeFileSync } from "node:fs";
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

test("the skill exposes parameterized chat invocations", () => {
  const instructions = readFileSync(join(skillDir, "SKILL.md"), "utf8");
  const executable = readFileSync(join(skillDir, "scripts", "review-change.mjs"), "utf8");
  assert.match(instructions, /argument-hint:.*review.*open.*render.*submit/i);
  assert.match(instructions, /\/review-change submit C1,C2/);
  assert.match(instructions, /accept-moved-head/);
  assert.match(instructions, /explicit.*authoriz/i);
  assert.doesNotMatch(executable, /Submit against .*anyway|process\.stdin\.isTTY/);
});

function createRepository({ ignoreAgents = true } = {}) {
  const sandbox = mkdtempSync(join(tmpdir(), "review-change-"));
  const repository = join(sandbox, "repo");
  run("git", ["init", "-q", "-b", "main", repository]);
  run("git", ["config", "user.email", "test@example.com"], { cwd: repository });
  run("git", ["config", "user.name", "Review Change Test"], { cwd: repository });
  run("git", ["config", "commit.gpgsign", "false"], { cwd: repository });
  writeFileSync(join(repository, "example.txt"), "base\n");
  writeFileSync(join(repository, ".gitignore"), ignoreAgents ? ".agents/\n" : "# Keep repository artifacts visible.\n");
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
    const refreshed = JSON.parse(readFileSync(contextPath, "utf8"));
    if (refreshed.passes.at(-1)?.status === "summarized") completeReview(repository, artifactRoot, env);
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
  return JSON.parse(run(publicBin, ["checkpoint"], {
    cwd: repository,
    env: { ...process.env, ...env, AGENTS_ARTIFACTS_ROOT: artifactRoot },
  }));
}

function completeReview(repository, artifactRoot, env = {}) {
  return run(publicBin, ["complete"], {
    cwd: repository,
    env: { ...process.env, ...env, AGENTS_ARTIFACTS_ROOT: artifactRoot },
  });
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

function installPullRequestHarness({ sandbox, repository }) {
  const bin = join(sandbox, "bin");
  const headFile = join(sandbox, "head.txt");
  const payloadFile = join(sandbox, "payload.json");
  mkdirSync(bin);
  run("git", ["remote", "add", "origin", "https://github.com/acme/widgets.git"], { cwd: repository });
  writeFileSync(headFile, `${run("git", ["rev-parse", "HEAD"], { cwd: repository })}\n`);
  const fakeGh = join(bin, "gh");
  writeFileSync(fakeGh, `#!/usr/bin/env bash
next_head() {
  if [[ -n "$FAKE_GH_HEAD_SEQUENCE" && -s "$FAKE_GH_HEAD_SEQUENCE" ]]; then
    head -n 1 "$FAKE_GH_HEAD_SEQUENCE"
    sed '1d' "$FAKE_GH_HEAD_SEQUENCE" > "$FAKE_GH_HEAD_SEQUENCE.next"
    mv "$FAKE_GH_HEAD_SEQUENCE.next" "$FAKE_GH_HEAD_SEQUENCE"
  else
    cat "$FAKE_GH_HEAD"
  fi
}
if [[ "$1" == "--version" ]]; then
  printf 'gh version test\\n'
elif [[ "$1 $2" == "pr view" ]]; then
  head=$(next_head)
  printf '{"number":42,"title":"Improve widgets","body":"PR intent","url":"https://github.com/acme/widgets/pull/42","baseRefName":"main","headRefName":"feature/review","headRefOid":"%s","state":"OPEN"}\\n' "$head"
elif [[ "$1 $2" == "api user" ]]; then
  printf 'owner\\n'
elif [[ "$1" == "api" && "$*" == *"--method POST"* ]]; then
  cat > "$FAKE_GH_PAYLOAD"
  head=$(cat "$FAKE_GH_HEAD")
  printf '{"html_url":"https://github.com/acme/widgets/pull/42#pullrequestreview-9","commit_id":"%s"}\\n' "$head"
elif [[ "$1" == "api" && "$2" == */comments ]]; then
  printf '[]\\n'
elif [[ "$1" == "api" && "$2" == */reviews ]]; then
  printf '[]\\n'
else
  exit 1
fi
`);
  chmodSync(fakeGh, 0o755);
  return {
    artifacts: join(sandbox, "artifacts"),
    headFile,
    payloadFile,
    env: {
      PATH: `${bin}:${process.env.PATH}`,
      FAKE_GH_HEAD: headFile,
      FAKE_GH_PAYLOAD: payloadFile,
    },
  };
}

test("artifact roots use override, ignored local storage, then home storage", () => {
  const explicit = createRepository();
  const explicitRoot = join(explicit.sandbox, "explicit-artifacts");
  const explicitResult = prepareReview(explicit.repository, explicitRoot);
  assert.equal(explicitResult.context.startsWith(`${explicitRoot}/`), true);

  const local = createRepository();
  const localResult = JSON.parse(run(publicBin, ["collect"], {
    cwd: local.repository,
    env: { ...process.env },
  }));
  assert.equal(localResult.context.startsWith(`${join(realpathSync(local.repository), ".agents", "artifacts")}/`), true);

  const global = createRepository({ ignoreAgents: false });
  const globalHome = join(global.sandbox, "home");
  const globalResult = JSON.parse(run(publicBin, ["collect"], {
    cwd: global.repository,
    env: { ...process.env, HOME: globalHome },
  }));
  assert.equal(globalResult.context.startsWith(`${join(globalHome, ".agents", "artifacts")}/`), true);
});

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
  completeReview(repository, artifacts);

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

  const inconsistentApproval = spawnSync(publicBin, ["complete"], { cwd: repository, env, encoding: "utf8" });
  assert.notEqual(inconsistentApproval.status, 0);
  assert.match(inconsistentApproval.stderr, /approve.*blocking finding/i);

  review.verdict = { value: "reject", reason: "The blocking finding must be fixed." };
  writeFileSync(collected.review, `${JSON.stringify(review)}\n`);
  completeReview(repository, artifacts);
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
  assert.match(readFileSync(finished.report, "utf8"), /Chat handoff/);
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

test("summary checkpoint saves JSON while HTML remains optional", () => {
  const { sandbox, repository } = createRepository();
  const artifacts = join(sandbox, "artifacts");
  const prepared = prepareReview(repository, artifacts);
  const summarized = summarizeReview(repository, artifacts, {}, prepared.context);
  const context = JSON.parse(readFileSync(prepared.context, "utf8"));

  assert.equal(summarized.status, "summarized");
  assert.equal(context.passes[0].status, "summarized");
  assert.equal(existsSync(context.summary.report), false);
  assert.equal(context.index, undefined);
  assert.match(summarized.next, /review-change render/i);

  const rendered = JSON.parse(run(publicBin, ["render"], {
    cwd: repository,
    env: { ...process.env, AGENTS_ARTIFACTS_ROOT: artifacts },
  }));
  const summary = readEmbeddedData(rendered.summary, "summary-data");
  const index = readIndexData(rendered.index);
  assert.equal(existsSync(rendered.summary), true);
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

test("complete prints a concise TUI handoff without rendering HTML", () => {
  const { sandbox, repository } = createRepository();
  const artifacts = join(sandbox, "artifacts");
  const prepared = prepareReview(repository, artifacts);
  summarizeReview(repository, artifacts, {}, prepared.context);
  writeFileSync(prepared.review, `${JSON.stringify({
    version: 1,
    summary: "Two unsafe paths remain.",
    body: "Two paths can lose the saved value. Please address C1 and C2 before merging.",
    verdict: { value: "reject", reason: "Two paths can lose saved data." },
    coverage: { reviewed: ["example.txt"], notReviewed: ["Production retry behavior"], confidence: "medium" },
    reconciliation: [],
    findings: [
      { id: "C1", severity: "critical", blocking: true, title: "Save before success", location: { path: "example.txt", line: 2 }, impact: "The caller may report success after losing data.", posting: "pending" },
      { id: "C2", severity: "critical", blocking: true, title: "Keep the retry value", location: { path: "example.txt", line: 3 }, impact: "A retry may store an empty value.", posting: "pending" },
    ],
    tests: { run: [], gaps: [] },
  }, null, 2)}\n`);

  const handoff = completeReview(repository, artifacts);
  const context = JSON.parse(readFileSync(prepared.context, "utf8"));

  assert.match(handoff, /Review complete — Reject/);
  assert.match(handoff, /C1 · Save before success/);
  assert.match(handoff, /C2 · Keep the retry value/);
  assert.match(handoff, /Two paths can lose the saved value/);
  assert.match(handoff, /Coverage: \*\*medium\*\* — Not verified: Production retry behavior/);
  assert.match(handoff, /Submission is unavailable.*not attached to an open pull request/);
  assert.match(handoff, /`\/review-change open`/);
  assert.match(handoff, /`\/review-change render`/);
  assert.equal(context.passes[0].status, "complete");
  assert.equal(existsSync(context.summary.report), false);
  assert.equal(context.index, undefined);
});

test("open renders the optional report and launches its index", () => {
  const { sandbox, repository } = createRepository();
  const artifacts = join(sandbox, "artifacts");
  const bin = join(sandbox, "bin");
  const openedPath = join(sandbox, "opened.txt");
  mkdirSync(bin);
  for (const name of ["open", "xdg-open", "explorer.exe"]) {
    const command = join(bin, name);
    writeFileSync(command, "#!/usr/bin/env bash\nprintf '%s' \"$1\" > \"$OPENED_PATH\"\n");
    chmodSync(command, 0o755);
  }
  const env = { PATH: `${bin}:${process.env.PATH}`, OPENED_PATH: openedPath };
  const prepared = prepareReview(repository, artifacts, env);
  summarizeReview(repository, artifacts, env, prepared.context);
  writeFileSync(prepared.review, `${JSON.stringify(approvalReview("Ready to merge."))}\n`);
  completeReview(repository, artifacts, env);

  const opened = JSON.parse(run(publicBin, ["open"], {
    cwd: repository,
    env: { ...process.env, ...env, AGENTS_ARTIFACTS_ROOT: artifacts },
  }));

  assert.equal(opened.status, "opened");
  assert.equal(readFileSync(openedPath, "utf8"), opened.index);
  assert.equal(existsSync(opened.index), true);
});

test("collect exits early when code and PR activity are unchanged", () => {
  const { sandbox, repository } = createRepository();
  const artifacts = join(sandbox, "artifacts");
  const first = prepareReview(repository, artifacts);
  writeFileSync(first.review, `${JSON.stringify(approvalReview("first pass"))}\n`);
  const finished = renderReview(repository, artifacts);

  const unchanged = prepareReview(repository, artifacts);
  const context = JSON.parse(readFileSync(unchanged.context, "utf8"));

  assert.equal(unchanged.status, "unchanged");
  assert.equal(unchanged.pass, 1);
  assert.equal(unchanged.index, finished.index);
  assert.equal(unchanged.report, finished.report);
  assert.equal(unchanged.summary, finished.summary);
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
  if [[ "$3" != "feature/review" || "$4" != "--repo" || "$5" != "acme/widgets.js" ]]; then
    printf 'unexpected pr view arguments: %s\\n' "$*" >&2
    exit 2
  fi
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

test("collect skips pull request discovery on detached HEAD", () => {
  const { sandbox, repository } = createRepository();
  const bin = join(sandbox, "bin");
  mkdirSync(bin);
  run("git", ["remote", "add", "origin", "https://github.com/acme/widgets.git"], { cwd: repository });
  run("git", ["switch", "-q", "--detach"], { cwd: repository });
  const fakeGh = join(bin, "gh");
  writeFileSync(fakeGh, `#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then
  printf 'gh version test\\n'
elif [[ "$1 $2" == "pr view" ]]; then
  head=$(git rev-parse HEAD)
  printf '{"number":42,"title":"Wrong PR","body":"","url":"https://github.com/acme/widgets/pull/42","baseRefName":"main","headRefName":"feature/review","headRefOid":"%s","state":"OPEN"}\\n' "$head"
elif [[ "$1 $2" == "api user" ]]; then
  printf 'owner\\n'
elif [[ "$1" == "api" ]]; then
  printf '[]\\n'
else
  exit 1
fi
`);
  chmodSync(fakeGh, 0o755);

  const prepared = prepareReview(repository, join(sandbox, "artifacts"), {
    PATH: `${bin}:${process.env.PATH}`,
  });
  const context = JSON.parse(readFileSync(prepared.context, "utf8"));

  assert.equal(context.change.mode, "local");
  assert.match(context.change.branch, /^detached-/);
  assert.equal(context.passes[0].activity, null);
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

test("pull request collection prefers the remote-tracking base", () => {
  const { sandbox, repository } = createRepository();
  const originalBase = run("git", ["rev-parse", "main"], { cwd: repository });
  const harness = installPullRequestHarness({ sandbox, repository });

  run("git", ["switch", "-q", "main"], { cwd: repository });
  writeFileSync(join(repository, "base-only.txt"), "already on the pull request base\n");
  run("git", ["add", "base-only.txt"], { cwd: repository });
  run("git", ["commit", "-q", "-m", "advance remote base"], { cwd: repository });
  const remoteBase = run("git", ["rev-parse", "HEAD"], { cwd: repository });
  run("git", ["update-ref", "refs/remotes/origin/main", remoteBase], { cwd: repository });
  run("git", ["switch", "-q", "feature/review"], { cwd: repository });
  run("git", ["rebase", "-q", "origin/main"], { cwd: repository });
  run("git", ["branch", "-f", "main", originalBase], { cwd: repository });
  writeFileSync(harness.headFile, `${run("git", ["rev-parse", "HEAD"], { cwd: repository })}\n`);

  const prepared = prepareReview(repository, harness.artifacts, harness.env);
  const context = JSON.parse(readFileSync(prepared.context, "utf8"));
  const diff = readFileSync(prepared.diff, "utf8");

  assert.equal(context.change.base, "origin/main");
  assert.equal(context.change.baseSha, remoteBase);
  assert.match(diff, /\+changed/);
  assert.doesNotMatch(diff, /base-only/);
});

test("clean pull request reviews follow the pull request head instead of local HEAD", () => {
  const { sandbox, repository } = createRepository();
  const pullRequestHead = run("git", ["rev-parse", "HEAD"], { cwd: repository });
  const harness = installPullRequestHarness({ sandbox, repository });

  run("git", ["reset", "--hard", "main"], { cwd: repository });
  const localHead = run("git", ["rev-parse", "HEAD"], { cwd: repository });
  assert.notEqual(localHead, pullRequestHead);

  const prepared = prepareReview(repository, harness.artifacts, harness.env);
  const context = JSON.parse(readFileSync(prepared.context, "utf8"));
  const pass = context.passes[0];

  assert.equal(pass.head, pullRequestHead);
  assert.equal(pass.pullRequestHead, pullRequestHead);
  assert.equal(pass.tree, pass.headTree);
  assert.deepEqual(prepared.branchUpdate, { from: localHead, to: pullRequestHead });
  assert.deepEqual(pass.branchUpdate, prepared.branchUpdate);
  assert.equal(run("git", ["rev-parse", "HEAD"], { cwd: repository }), pullRequestHead);
  assert.match(readFileSync(prepared.diff, "utf8"), /\+changed/);
});

test("pull request collection fetches a missing pull request head", () => {
  const { sandbox, repository } = createRepository();
  const remote = join(sandbox, "github.com", "acme", "widgets.git");
  const producer = join(sandbox, "producer");
  mkdirSync(join(sandbox, "github.com", "acme"), { recursive: true });
  run("git", ["clone", "-q", "--bare", repository, remote]);
  run("git", ["clone", "-q", remote, producer]);
  run("git", ["config", "user.email", "test@example.com"], { cwd: producer });
  run("git", ["config", "user.name", "Review Change Test"], { cwd: producer });
  run("git", ["config", "commit.gpgsign", "false"], { cwd: producer });
  writeFileSync(join(producer, "remote-only.txt"), "available only from origin\n");
  run("git", ["add", "remote-only.txt"], { cwd: producer });
  run("git", ["commit", "-q", "-m", "remote pull request head"], { cwd: producer });
  const pullRequestHead = run("git", ["rev-parse", "HEAD"], { cwd: producer });
  run("git", ["push", "-q", "origin", "HEAD:feature/review"], { cwd: producer });

  const harness = installPullRequestHarness({ sandbox, repository });
  run("git", ["remote", "set-url", "origin", remote], { cwd: repository });
  writeFileSync(harness.headFile, `${pullRequestHead}\n`);
  assert.notEqual(spawnSync("git", ["cat-file", "-e", `${pullRequestHead}^{commit}`], { cwd: repository }).status, 0);

  const prepared = prepareReview(repository, harness.artifacts, harness.env);
  const context = JSON.parse(readFileSync(prepared.context, "utf8"));

  assert.equal(context.passes[0].head, pullRequestHead);
  assert.equal(prepared.branchUpdate.to, pullRequestHead);
  assert.deepEqual(context.passes[0].branchUpdate, prepared.branchUpdate);
  assert.equal(spawnSync("git", ["cat-file", "-e", `${pullRequestHead}^{commit}`], { cwd: repository }).status, 0);
  assert.equal(run("git", ["rev-parse", "HEAD"], { cwd: repository }), pullRequestHead);
  assert.match(readFileSync(prepared.diff, "utf8"), /remote-only\.txt/);
});

test("a dirty worktree keeps local review mode even when the pull request head differs", () => {
  const { sandbox, repository } = createRepository();
  const pullRequestHead = run("git", ["rev-parse", "HEAD"], { cwd: repository });
  const harness = installPullRequestHarness({ sandbox, repository });
  run("git", ["reset", "--hard", "main"], { cwd: repository });
  const localHead = run("git", ["rev-parse", "HEAD"], { cwd: repository });
  writeFileSync(join(repository, "local-only.txt"), "uncommitted review target\n");

  const prepared = prepareReview(repository, harness.artifacts, harness.env);
  const context = JSON.parse(readFileSync(prepared.context, "utf8"));
  const pass = context.passes[0];

  assert.notEqual(localHead, pullRequestHead);
  assert.equal(pass.head, localHead);
  assert.equal(pass.pullRequestHead, pullRequestHead);
  assert.notEqual(pass.tree, pass.headTree);
  assert.equal(prepared.branchUpdate, null);
  assert.match(readFileSync(prepared.diff, "utf8"), /local-only\.txt/);
});

test("a clean diverged branch is preserved while the pull request head is reviewed", () => {
  const { sandbox, repository } = createRepository();
  const pullRequestHead = run("git", ["rev-parse", "HEAD"], { cwd: repository });
  const harness = installPullRequestHarness({ sandbox, repository });
  run("git", ["reset", "--hard", "main"], { cwd: repository });
  writeFileSync(join(repository, "diverged-local.txt"), "preserve this commit\n");
  run("git", ["add", "diverged-local.txt"], { cwd: repository });
  run("git", ["commit", "-q", "-m", "diverged local commit"], { cwd: repository });
  const localHead = run("git", ["rev-parse", "HEAD"], { cwd: repository });

  const prepared = prepareReview(repository, harness.artifacts, harness.env);
  const context = JSON.parse(readFileSync(prepared.context, "utf8"));

  assert.equal(run("git", ["rev-parse", "HEAD"], { cwd: repository }), localHead);
  assert.equal(context.passes[0].head, pullRequestHead);
  assert.match(readFileSync(prepared.diff, "utf8"), /\+changed/);
  assert.doesNotMatch(readFileSync(prepared.diff, "utf8"), /diverged-local/);
});

test("an empty pull request patch is rejected", () => {
  const { sandbox, repository } = createRepository();
  const harness = installPullRequestHarness({ sandbox, repository });
  run("git", ["reset", "--hard", "main"], { cwd: repository });
  writeFileSync(harness.headFile, `${run("git", ["rev-parse", "HEAD"], { cwd: repository })}\n`);

  const collected = spawnSync(publicBin, ["collect"], {
    cwd: repository,
    encoding: "utf8",
    env: { ...process.env, ...harness.env, AGENTS_ARTIFACTS_ROOT: harness.artifacts },
  });

  assert.notEqual(collected.status, 0);
  assert.match(collected.stderr, /nothing to review: the current change is empty/i);
});

test("pull request reviews with local-only changes cannot be submitted", async (t) => {
  const cases = {
    staged({ repository }) {
      writeFileSync(join(repository, "staged-only.txt"), "not pushed\n");
      run("git", ["add", "staged-only.txt"], { cwd: repository });
    },
    unstaged({ repository }) {
      writeFileSync(join(repository, "example.txt"), "base\nchanged\nnot committed\n");
    },
    untracked({ repository }) {
      writeFileSync(join(repository, "untracked-only.txt"), "not pushed\n");
    },
  };

  for (const [name, arrange] of Object.entries(cases)) {
    await t.test(name, () => {
      const { sandbox, repository } = createRepository();
      const harness = installPullRequestHarness({ sandbox, repository });
      arrange({ repository });

      const prepared = prepareReview(repository, harness.artifacts, harness.env);
      const context = JSON.parse(readFileSync(prepared.context, "utf8"));
      writeFileSync(prepared.review, `${JSON.stringify(approvalReview("Local changes were reviewed."), null, 2)}\n`);
      const finished = renderReview(repository, harness.artifacts, harness.env);
      const report = readReportData(finished.report);

      assert.notEqual(context.passes[0].tree, context.passes[0].headTree);
      assert.equal(report.submit, null);
      assert.match(report.submissionUnavailable, /local worktree changes/i);

      const submission = spawnSync(publicBin, ["submit"], {
        cwd: repository,
        encoding: "utf8",
        env: { ...process.env, ...harness.env, AGENTS_ARTIFACTS_ROOT: harness.artifacts },
      });
      assert.notEqual(submission.status, 0);
      assert.match(submission.stderr, /local worktree changes/i);
      assert.equal(existsSync(harness.payloadFile), false);
    });
  }
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
    }, {
      id: "W1",
      severity: "warning",
      blocking: false,
      title: "Explain the fallback",
      location: { path: "example.txt", line: 2 },
      explanation: "The fallback is surprising.",
      impact: "Future changes may remove it by mistake.",
      suggestion: "Add a short explanation.",
      comment: "Please explain why this fallback is needed.",
      posting: "pending",
    }],
    tests: { run: [], gaps: [] },
  };
  writeFileSync(prepared.review, `${JSON.stringify(review, null, 2)}\n`);
  const context = JSON.parse(readFileSync(prepared.context, "utf8"));
  context.passes[0].pullRequestHead = "f".repeat(40);
  writeFileSync(prepared.context, `${JSON.stringify(context, null, 2)}\n`);
  summarizeReview(repository, artifacts, env, prepared.context);
  const handoff = completeReview(repository, artifacts, env);
  assert.match(handoff, /`\/review-change submit C1,W1`/);
  const finished = renderReview(repository, artifacts, env);
  const reportBefore = readFileSync(finished.report, "utf8");
  assert.deepEqual(readReportData(finished.report).submit, { invocation: "/review-change submit" });
  assert.match(reportBefore, /Chat handoff/);
  assert.match(reportBefore, /Copy skill invocation/);
  assert.doesNotMatch(reportBefore, /Terminal handoff/);
  assert.match(reportBefore, /Top-level review message/);
  assert.match(reportBefore, /Reset message/);
  assert.doesNotMatch(reportBefore, /__REVIEW_CHANGE_(?:PASS|DATA)__/);
  assert.equal(reportBefore.includes(prepared.context), false);

  const spaced = spawnSync(publicBin, ["submit", "C1", "W1"], {
    cwd: repository,
    encoding: "utf8",
    env: { ...process.env, ...env },
  });
  assert.notEqual(spaced.status, 0);
  assert.match(spaced.stderr, /one comma-separated value/i);

  writeFileSync(headFile, `${"0".repeat(40)}\n`);
  const stopped = spawnSync(publicBin, ["submit", "C1,W1", "--message", "Good job, here is the blocking feedback."], {
    cwd: repository,
    encoding: "utf8",
    env: { ...process.env, ...env },
  });
  assert.equal(stopped.status, 2);
  assert.match(stopped.stderr, /warning: PR HEAD moved/i);
  assert.match(stopped.stderr, /inline comments were written against/i);
  assert.match(stopped.stderr, /recommended: cancel and run review-change again/i);
  assert.equal(JSON.parse(stopped.stdout).status, "cancelled");
  assert.equal(existsSync(payloadFile), false);

  const accepted = spawnSync(publicBin, ["submit", "C1,W1", "--message", "Good job, here is the blocking feedback.", "--accept-moved-head"], {
    cwd: repository,
    encoding: "utf8",
    env: { ...process.env, ...env },
  });
  assert.equal(accepted.status, 0);
  assert.match(accepted.stderr, /warning: PR HEAD moved/i);
  const submitted = JSON.parse(accepted.stdout);
  const savedReview = JSON.parse(readFileSync(prepared.review, "utf8"));
  const payload = JSON.parse(readFileSync(payloadFile, "utf8"));

  assert.equal(submitted.status, "submitted");
  assert.equal(submitted.event, "REQUEST_CHANGES");
  assert.match(submitted.warnings[0], /line locations may now be incorrect/i);
  assert.equal(savedReview.findings[0].posting, "posted");
  assert.equal(savedReview.findings[1].posting, "posted");
  assert.equal(savedReview.submissions[0].url, submitted.url);
  assert.equal(savedReview.submissions[0].reviewedHead, reviewedHead);
  assert.equal(savedReview.submissions[0].observedHead, "0".repeat(40));
  assert.equal(savedReview.submissions[0].submittedHead, "0".repeat(40));
  assert.equal(savedReview.submissions[0].headMoved, true);
  assert.equal(savedReview.submissions[0].confirmation, "flag");
  assert.deepEqual(savedReview.submissions[0].warnings, submitted.warnings);
  assert.equal("commit_id" in payload, false);
  assert.equal(payload.body, "Good job, here is the blocking feedback.");
  assert.equal(payload.comments[0].body, review.findings[0].comment);
  assert.equal(payload.comments[1].body, review.findings[1].comment);
  assert.match(readFileSync(finished.report, "utf8"), /"posting":"posted"/);
});

test("moved-head acceptance is one attempt and any second movement cancels", async (t) => {
  for (const scenario of ["another new head", "back to the reviewed head"]) {
    await t.test(scenario, () => {
      const { sandbox, repository } = createRepository();
      const harness = installPullRequestHarness({ sandbox, repository });
      const sequence = join(sandbox, "head-sequence.txt");
      const reviewedHead = run("git", ["rev-parse", "HEAD"], { cwd: repository });
      const prepared = prepareReview(repository, harness.artifacts, harness.env);
      writeFileSync(prepared.review, `${JSON.stringify(approvalReview("Ready to submit."), null, 2)}\n`);
      summarizeReview(repository, harness.artifacts, harness.env, prepared.context);
      completeReview(repository, harness.artifacts, harness.env);

      const secondHead = scenario === "another new head" ? "2".repeat(40) : reviewedHead;
      writeFileSync(sequence, `${"1".repeat(40)}\n${secondHead}\n`);
      const submission = spawnSync(publicBin, ["submit", "--accept-moved-head"], {
        cwd: repository,
        encoding: "utf8",
        env: {
          ...process.env,
          ...harness.env,
          AGENTS_ARTIFACTS_ROOT: harness.artifacts,
          FAKE_GH_HEAD_SEQUENCE: sequence,
        },
      });

      assert.equal(submission.status, 2);
      assert.equal(JSON.parse(submission.stdout).status, "cancelled");
      assert.equal((submission.stderr.match(/Warning: PR HEAD moved/g) || []).length, 2);
      assert.equal(existsSync(harness.payloadFile), false);
    });
  }
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
