---
name: review-change
description: Context-first, iterative review of local changes or PR activity—plain-English study, blast-radius deltas, findings, and submission handoff.
disable-model-invocation: true
compatibility: Requires Node.js 18+ and git. PR discovery and submission commands require authenticated gh.
allowed-tools: Bash(git:* gh:* node:* bash:*) Read Write
---

Invoked as `/review-change`.

*Read the change as if you will own what happens after it ships.*

## 1 — Collect

```bash
bash <SKILL_DIR>/bin/review-change collect
```

- `unchanged` → report no new code or PR activity; stop.
- `ready` → read `context`, its diffs, activity snapshots, and completed reviews. Write to the returned `summary` and `review` paths.

An open PR adds description and discussion; without one, review the local change and build the same summary from repository evidence. Treat PR claims as evidence, not authority. Follow the diff into the instructions, docs, callers, consumers, tests, contracts, configuration, and parallel paths needed to understand its behavior.

## 2 — Orient

Read [summary-format.md](references/summary-format.md), then update `summary`.

- First pass: explain the change in plain English—intent versus observed behavior, before → after, main path, changed components, contracts, and unknowns. Trace the full blast radius.
- Later passes: preserve the study; append the current delta and trace only its blast radius. Refresh the study only when its behavior model is invalid or the user asks.

Cover direct, glue, contract, parallel, integration, and operational rings. Mark each `checked`, `not_applicable`, or `not_verified`. Suspicion is a review target, not yet a finding.

```bash
bash <SKILL_DIR>/bin/review-change render-summary
```

Share the returned summary anchor and index immediately; say findings review continues. Do not wait. The summary contains no verdict or findings.

## 3 — Judge

Use the study and blast radius as the review map. Test whether the implementation fulfills its intent across correctness, security, contracts, failures, operations, and tests. Ground findings in exact locations; state impact and a useful direction. Avoid speculative or cosmetic noise; disclose gaps.

On later passes, reconcile every unresolved finding. Point duplicates to exact PR activity and carry-overs to the earlier pass and finding ID.

Write `review` using [review-format.md](references/review-format.md). The judgment is yours; scripts validate and resolve its pointers.

## 4 — Deliver

```bash
bash <SKILL_DIR>/bin/review-change render
```

Share the returned findings report, durable summary, and index; state the verdict and coverage limits. Never run the generated submission command—the user deliberately copies and runs it.
