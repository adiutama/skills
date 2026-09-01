---
name: review-change
description: Context-first, iterative review of local changes or PR activity—plain-English study, blast-radius deltas, findings, and submission handoff.
disable-model-invocation: true
compatibility: Requires Node.js 18+ and git. PR discovery and submission commands require authenticated gh.
metadata:
  argument-hint: '[review|open|render|submit [C1,C2] [--message <text>] [accept-moved-head]]'
allowed-tools: Bash(git:* gh:* node:* bash:*) Read Write
---

Invoked as:

- `/review-change` or `/review-change review` — review the current change.
- `/review-change open` — render and open the optional HTML report.
- `/review-change render` — generate HTML without opening it.
- `/review-change submit C1,C2` — submit the completed review with selected inline findings.

## Route

Treat the invocation tail as this skill's interface. The executable is an internal adapter; never ask the user to run it.

- No tail or `review` → continue with **1 — Collect**.
- `open` → run `bash <SKILL_DIR>/bin/review-change open`, report the opened index, then stop.
- `render` → run `bash <SKILL_DIR>/bin/review-change render`, return its artifact paths, then stop.
- `submit [C1,C2] [--message <text>] [accept-moved-head]` → follow **Submit** below, then stop.
- Any other tail → show the four invocation forms above and stop.

If a harness cannot attach parameters to a slash command, the user can select or invoke `review-change` and pass a natural-language argument such as “submit C1 and C2.” Treat that explicit argument as the equivalent parameterized invocation.

## Submit

The user's explicit `submit` invocation authorizes the external GitHub review. A normal review never authorizes submission.

1. Accept at most one comma-separated finding list. Pass an explicit `--message` as one argument; decode the HTML handoff's JSON-style quoted text first. The submission adapter trims only outer whitespace.
2. Add the internal `--accept-moved-head` flag only when the user included `accept-moved-head` in this invocation.
3. Run `bash <SKILL_DIR>/bin/review-change submit ...` with those translated arguments.
4. On success, report the review URL, event, and submitted finding IDs.
5. If the command cancels because the PR head moved, return the warning and ask for a new explicit `/review-change submit ... accept-moved-head` invocation. Do not arrange interactive confirmation or accept movement on the user's behalf. Acceptance applies only to the head observed during that attempt; another movement cancels again and requires another explicit invocation.

*Read the change as if you will own what happens after it ships.*

## 1 — Collect

```bash
bash <SKILL_DIR>/bin/review-change collect
```

- `unchanged` → run `bash <SKILL_DIR>/bin/review-change complete`, return its handoff verbatim, and stop.
- `ready` → read `context`, its diffs, activity snapshots, and completed reviews. Write to the returned `summary` and `review` paths.
- Non-null `branchUpdate` → state that collection safely fast-forwarded the clean checked-out branch from `from` to the verified PR head at `to`.

On a clean PR worktree, collection reviews the latest PR head. It fetches that exact commit when missing and safely fast-forwards a checked-out branch that is behind it. It preserves dirty or diverged branches. Without a PR, review the local change and build the same summary from repository evidence. Treat PR claims as evidence, not authority. Follow the diff into the instructions, docs, callers, consumers, tests, contracts, configuration, and parallel paths needed to understand its behavior.

## 2 — Orient

Read [summary-format.md](references/summary-format.md), then update `summary`.

- First pass: explain the change in plain English—intent versus observed behavior, before → after, main path, changed components, contracts, and unknowns. Trace the full blast radius.
- Later passes: preserve the study; append the current delta and trace only its blast radius. Refresh the study only when its behavior model is invalid or the user asks.

Cover direct, glue, contract, parallel, integration, and operational rings. Mark each `checked`, `not_applicable`, or `not_verified`. Suspicion is a review target, not yet a finding.

```bash
bash <SKILL_DIR>/bin/review-change checkpoint
```

State briefly that the change study is saved and findings review continues. Mention `/review-change open` only if the user wants the optional HTML view. The summary contains no verdict or findings.

## 3 — Judge

Use the study and blast radius as the review map. Test whether the implementation fulfills its intent across correctness, security, contracts, failures, operations, and tests. Ground findings in exact locations; state impact and a useful direction. Avoid speculative or cosmetic noise; disclose gaps.

On later passes, reconcile every unresolved finding. Point duplicates to exact PR activity and carry-overs to the earlier pass and finding ID.

Write `review` using [review-format.md](references/review-format.md). The judgment is yours; scripts validate and resolve its pointers.

## 4 — Complete

```bash
bash <SKILL_DIR>/bin/review-change complete
```

The command validates the JSON, records the completed pass, and prints a TUI-ready handoff from a checked-in template. Return that handoff verbatim. It already includes the verdict, exact submit message, coverage, deliberate submission command, and every blocking finding when the verdict is Reject.

HTML is optional presentation. Never render it by default. The final handoff exposes `/review-change open`, `/review-change render`, and—when submission is available—the exact parameterized submit invocation. Return it verbatim.

Never submit during the review workflow. Submission happens only through a later explicit `submit` invocation routed above.
