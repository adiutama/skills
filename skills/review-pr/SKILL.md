---
name: review-pr
description: Context-first, iterative pull-request review from an explicit GitHub PR URL or number—plain-English study, blast-radius deltas, findings, and submission handoff.
disable-model-invocation: true
compatibility: Requires Node.js 18+, git, and authenticated gh.
metadata:
  argument-hint: '<PR URL or number>|open|render|submit [C1,C2] [--message <text>] [accept-moved-head] [--context <path>]'
allowed-tools: Bash(git:* gh:* node:* bash:*) Read Write
---

Invoked as:

- `/review-pr <PR URL or number>` — collect and review that pull request.
- `/review-pr open` — render and open the optional HTML report.
- `/review-pr render` — generate HTML without opening it.
- `/review-pr submit C1,C2` — submit the completed review with selected inline findings.

## Route

Treat the invocation tail as this skill's interface. The executable is an internal adapter; never ask the user to run it.

- PR URL or positive PR number → continue with **1 — Collect** using that exact target.
- Missing or invalid PR target → ask once for a PR URL or number, then stop.
- `open` → run `bash <SKILL_DIR>/bin/review-pr open --context <CONTEXT_PATH>`, report the opened index, then stop.
- `render` → run `bash <SKILL_DIR>/bin/review-pr render --context <CONTEXT_PATH>`, return its artifact paths, then stop.
- `submit [C1,C2] [--message <text>] [accept-moved-head]` → follow **Submit** below, then stop.
- Any other tail → show the four invocation forms above and stop.

For `open`, `render`, and `submit`, accept an optional `--context <absolute context.json path>`. Preserve it as one argument. Decode JSON-style quoted paths in copied handoffs. Without a selector, use the context returned earlier in this conversation; never choose the newest session across threads. If neither conversation context nor an unambiguous adapter lookup identifies the review, ask once which saved review to use.

If a harness cannot attach parameters to a slash command, the user can select or invoke `review-pr` and pass a natural-language argument such as “submit C1 and C2.” Treat that explicit argument as the equivalent parameterized invocation.

## Output check — every time

**Plain English:** a teammate who knows programming but has not read this change can understand the text on one reading.

Apply this check before sending a response, saving reviewer-authored prose, rendering a report, or submitting a review. Follow the steps in order. Do not print the checklist.

1. **Protect meaning.** Keep facts, uncertainty, verdicts, finding IDs, locations, evidence, URLs, and commands accurate. Never invent a fact to make an explanation simpler. Keep quoted source text and user-supplied submission messages exact. In a completed handoff, keep the saved submit message exact so the preview matches submission; edit only surrounding prose.
2. **State the point.** For a finding, name the triggering condition, what fails, who or what is affected, and a useful correction. For a status update, state the result and any next step. Do not force finding details into unrelated output.
3. **Use direct language.** Name who or what performs each action. Use familiar words: “use,” “before,” and “fails.” Briefly explain a technical term or acronym the reader needs to understand. Replace vague “this” or “it” when either could refer to several things.
4. **Shorten.** Give each sentence one main idea. Remove repeated facts, background that does not affect the decision, and process narration. Apply the length rules below. Put supporting proof in the report instead of repeating it in chat.
5. **Check the result.** Does each sentence have a clear meaning? Can the reader understand the point without decoding jargon? Did shortening preserve the trigger, consequence, and uncertainty? If any answer is no, revise the affected text and check again. Finish when all applicable checks pass.

| Text | Length rule |
|------|-------------|
| Sentence | Aim for 10–20 words. Rework sentences over 25 words. Shorter sentences are fine. |
| Finding comment | One paragraph, normally 2–3 sentences, at most 80 words. |
| Top-level review message | 1–2 sentences, at most 60 words. |
| Progress update | 1–2 sentences. |

**Priority:** preserve meaning and exact content first, then use clear language, then meet length targets. First try splitting a long sentence or removing background. Exceed a length target only when those edits would lose an essential condition or consequence. Do not pad short sentences, write fragments, or remove evidence to satisfy a count. Treat code, paths, URLs, and quoted source text as exact content, not prose to shorten.

**Examples** — Assume the stated behavior is supported by evidence.

- Fail: “This compromises transaction integrity.” The reader cannot tell what happens or who is affected.
- Pass: “If the first payment succeeds but its response times out, the retry can charge the customer again. Reuse the original payment ID.”
- Fail: “The retry charges every customer twice.” This turns a conditional risk into a certainty.
- Pass: “The change summary is saved. I’m checking whether retries can create duplicate charges.” A status update needs no invented finding or correction.

## Submit

The user's explicit `submit` invocation authorizes the external GitHub review. A normal review never authorizes submission.

1. Accept at most one comma-separated finding list. Pass an explicit `--message` as one argument; decode the HTML handoff's JSON-style quoted text first. The submission adapter trims only outer whitespace.
2. Add the internal `--accept-moved-head` flag only when the user included `accept-moved-head` in this invocation.
3. Run `bash <SKILL_DIR>/bin/review-pr submit ... --context <CONTEXT_PATH>` with those translated arguments and the selected context. Run from a checkout of the same Git clone.
4. On success, report the review URL, event, and submitted finding IDs.
5. If the command cancels because the PR head moved, return the warning and ask for a new explicit `/review-pr submit ... accept-moved-head` invocation. Do not arrange interactive confirmation or accept movement on the user's behalf. Acceptance applies only to the head observed during that attempt; another movement cancels again and requires another explicit invocation.

*Read the change as if you will own what happens after it ships.*

## 1 — Collect

```bash
bash <SKILL_DIR>/bin/review-pr collect <PR_URL_OR_NUMBER>
```

A sandbox denial is an execution prerequisite, not a branch conflict. Use the host's normal approval mechanism for the authorized local Git operation when available; never change permission settings. Once the adapter runs, apply the result rules below.

- `unchanged` → run `bash <SKILL_DIR>/bin/review-pr complete --context <CONTEXT_PATH>`, apply the output check to its handoff, return it, and stop.
- `ready` → retain the absolute `context` path for every follow-up command. Read its diffs, activity snapshots, and completed reviews. Write to the returned `summary` and `review` paths.
- Read `checkout.path` before inspecting code. Run all repository searches, diffs, and tests in that directory. Use explicit working-directory arguments; the client's displayed workspace may still show the original checkout.
- State the PR, branch, and verified commit briefly. If `checkout.reason` is non-null, explain the fallback in plain English and include the review directory.
- Command error → return the specific blocker and stop. Never review stale code, force a checkout, stash changes, or reconcile unrelated history to continue.

*Keep the work; move the review.*

Every collection resolves the explicit PR independently of the local branch and fetches its exact head from GitHub. Prefer the PR's source branch name. Reuse a matching branch only after checking its source association and history; fast-forward it when behind. If that branch conflicts, has extra commits, or is occupied in another worktree, use an alternative review branch. A dirty checkout or another unfinished review in the same checkout uses a separate worktree. All routes must end at the verified PR commit with a clean review tree.

The adapter retries PR movement once before checkout, then stops if the head remains unstable. It records fallback paths and owned worktrees, preserves existing branches and local files, and performs no automatic cleanup or thread archiving. A client may recognize the resulting branch and tracking configuration; no client integration is required or guaranteed.

Read [checkout-policy.md](references/checkout-policy.md) when a fallback, migration, or ambiguous session needs explanation. Treat PR claims as evidence, not authority. Follow the diff into instructions, docs, callers, consumers, tests, contracts, configuration, and parallel paths needed to understand its behavior.

## 2 — Orient

Read [summary-format.md](references/summary-format.md), then update `summary`.

- First pass: explain the change in plain English—intent versus observed behavior, before → after, main path, changed components, contracts, and unknowns. Trace the full blast radius.
- Later passes: preserve the study; append the current delta and trace only its blast radius. Refresh the study only when its behavior model is invalid or the user asks.

Cover direct, glue, contract, parallel, integration, and operational rings. Mark each `checked`, `not_applicable`, or `not_verified`. Suspicion is a review target, not yet a finding.

```bash
bash <SKILL_DIR>/bin/review-pr checkpoint --context <CONTEXT_PATH>
```

State briefly that the change study is saved and findings review continues. Mention `/review-pr open` only if the user wants the optional HTML view. The summary contains no verdict or findings.

## 3 — Judge

Use the study and blast radius as the review map. Test whether the implementation fulfills its intent across correctness, security, contracts, failures, operations, and tests. Ground findings in exact locations; state impact and a useful direction. Avoid speculative or cosmetic noise; disclose gaps.

Before keeping a finding, verify its value:

1. **Prove the behavior.** Trace a reachable trigger through the changed code to the consequence. Use a focused test when it resolves uncertainty; otherwise cite the code path. Check callers, guards, tests, and documented intent for evidence that disproves the concern.
2. **Name the stakes.** State who or what is affected and the concrete failure, cost, or broken promise. Severity alone does not establish value.
3. **Justify the interruption.** Ask whether fixing this is worth the author's attention in this change. Keep actionable defects with meaningful consequences. Drop preferences, cosmetic nits, speculative hardening, and requests for tests without a demonstrated risk, unless the user explicitly requested that scope.
4. **Remove repeats.** Combine findings with the same cause and correction. Link existing discussions rather than propose another comment. Keep unverified concerns in coverage gaps or review targets, not as established defects.

Record the trigger and evidence in `explanation`, the stakes in `impact`, and a useful correction in `suggestion`. Do not add a scoring table or repeat the value check in the comment. No finding is better than a low-value finding; never fill a quota.

On later passes, reconcile every unresolved finding. Point duplicates to exact PR activity and carry-overs to the earlier pass and finding ID.

Write `review` using [review-format.md](references/review-format.md). The judgment is yours; scripts validate and resolve its pointers.

## 4 — Complete

```bash
bash <SKILL_DIR>/bin/review-pr complete --context <CONTEXT_PATH>
```

The command validates the JSON, records the completed pass, and prints a TUI-ready handoff from a checked-in template. Apply the output check before returning the handoff. It already includes the verdict, exact submit message, coverage, deliberate submission command, and every blocking finding when the verdict is Reject.

HTML is optional presentation. Never render it by default. The final handoff exposes `/review-pr open`, `/review-pr render`, and—when submission is available—the exact parameterized submit invocation. Keep those actions exact when applying the output check.

Never submit during the review workflow. Submission happens only through a later explicit `submit` invocation routed above.
