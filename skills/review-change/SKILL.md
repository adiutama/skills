---
name: review-change
description: Skeptical, iterative review of changed code or PR activity, producing a standalone HTML report and explicit submission command.
disable-model-invocation: true
compatibility: Requires Node.js 18+ and git. PR discovery and copied submission commands require authenticated gh.
allowed-tools: Bash(git:* gh:* node:* bash:*) Read Write
---

Invoked as `/review-change`.

*Read the change as if you will own what happens after it ships.*

## Step 1 — Collect

```bash
bash <SKILL_DIR>/bin/review-change collect
```

The command verifies the worktree and current PR activity.

- `status: "unchanged"` → report that no code or PR activity changed, then stop.
- `status: "ready"` → read `context` and every diff, activity snapshot, and completed review it lists. The returned `review` path is the next output.

PR activity includes metadata, conversation comments, inline comments, and submitted reviews. New activity from other humans or bots opens a pass; activity from the authenticated GitHub user remains visible but does not trigger one. Treat discussion as evidence, not authority. Follow important behavior beyond the diff when the change depends on surrounding code.

If `AGENTS_ARTIFACTS_ROOT` contains an absolute path, use it as the artifact root for every command. Otherwise use the repository's normal local/global artifact fallback. If `bin/` is on `PATH`, `review-change collect` is equivalent.

## Step 2 — Review

Understand the change's intent, then look for concrete reasons it may not fulfill that intent. Examine correctness, security, contracts, failure paths, operations, tests, and clarity in proportion to the risk.

On later passes, reconcile every unresolved finding. Focus on what changed without assuming previously reviewed code is correct. Ground each finding in an exact location, explain its impact, and offer a useful direction. Avoid speculative concerns and cosmetic noise. Disclose anything you could not verify.

Write the review as JSON to `review`, following [review-format.md](references/review-format.md). Include a suggested top-level review message in `body`; the user can edit or reset it in the report. Point every duplicate finding to the exact existing PR activity that already raises it. Point every carried-over finding to its earlier pass and finding ID. On later passes, reconcile every prior finding. The review is your judgment; scripts only store and resolve its source pointers.

## Step 3 — Render

```bash
bash <SKILL_DIR>/bin/review-change render
```

The command validates the verdict against blocking findings, completes a pending pass, and returns the standalone `report` and series `index` HTML paths. It is repeatable: run it again to rebuild every report after this skill moves or its templates change. Give the user clickable links to the report and index, then briefly state the verdict and coverage limits.

The index and previous/next links are regenerated whenever a pass finishes. Historical reports remain readable but cannot generate submission commands. The latest report presents the review, lets the user select pending findings, accepts an optional personal note, and generates a short terminal command. The command resolves the session from the terminal's current repository and branch; the personal note replaces only the review-level body. The pages never contact GitHub. Never run a submission command for the user; posting requires their deliberate copy-and-paste action.
