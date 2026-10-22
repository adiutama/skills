---
name: pr-testing
description: Test open pull requests by hand, one at a time, in one disposable test checkout with fake integrations and synthetic data. Each PR gets its own checklist dashboard whose buttons reach the agent. Agreed fixes go to a fresh implementer on the PR branch, and merging happens only when the user authorizes it.
disable-model-invocation: true
argument-hint: '[start] [<PR number or URL>] | switch <PR> | status | stop'
compatibility: Needs git, authenticated gh, Node 18+, and the throwaway-services skill installed beside this one.
metadata:
  version: "1.0.0"
  related: "throwaway-services"
---

## Harness

Run `scripts/harness.sh terms` once at the start, then `scripts/harness.sh features`; [harnesses.md](references/harnesses.md) documents both. Terms in **bold** mean what `terms` says: **storage** · **invoke** · **notify** · **implementer** · **process** · **share** · **secret** · **link**. A feature reported as `no`, `none`, or `local` is unavailable here. Use its fallback and say so; never claim it works.

## Route

- No action, `start`, or `start <PR>` → steps 0–3. A PR given here counts as the selection in step 2.
- `switch <PR>` → [setup.md § Switch](references/setup.md#switch), then step 3.
- `status` → print the ledger's top block and `dashboard.mjs inbox`.
- `stop` → [setup.md § Stop](references/setup.md#stop).
- The user describes a problem, presses a dashboard button, or says "check the dashboard" → step 4.
- The user says the PR is good, or asks to merge → step 5.

**Session** `<S>` = `<storage>/pr-testing/`. It holds `ledger.md`, the test checkout `tree/`, the dashboard `checklist/`, the case files `cases/`, the env files `runtime/` and `secrets/`, the implementer briefs `briefs/`, and `logs/`. `<skill>` = this skill's folder. `<ts>` = the sibling `throwaway-services` folder; missing → stop and tell the user to install it.

## Rules

- **You never fix the tested project.** Do not edit its source, tests, migrations, docs, or tracked config, not even one character. You may reproduce problems, read logs, and report what you saw. You may change only the disposable runtime: `<S>/runtime/`, synthetic seeds, and stub servers. Fixes go to an **implementer**.
- **One test checkout, one service set, one app address per session.** Switching PRs changes `<S>/tree` in place. The app may restart, but its URL stays the same.
- **Never real data or real side effects by default.** Use only the synthetic seed and disposable stores. Every external integration starts as a fake, emulator, or stub. A missing fake is a reported limitation, never an implicit real call. A real integration runs only when the user enables it for this PR.
- **No secret in chat, logs, the ledger, the dashboard, or a brief.** Values reach the app only through **secret**; you see key names only.
- **Ask, then wait** at each gate: dirty workspace (0), PR selection (2), integrations (3), fix batch (4), merge (5). Anything else that is disposable, do without asking.
- **One writer per branch:** only the current implementer pushes to a PR branch.

## 0 — Workspace

Before anything else, run `git status --porcelain=v1 --untracked-files=all` in the checkout you were started in. Dirty → show the files grouped as staged, unstaged, and untracked, then ask: **reset** to the latest default branch or **keep** them. Wait. Before the user approves a reset, state its exact scope ([setup.md § Workspace](references/setup.md#workspace)). Keep → touch nothing; testing happens in `<S>/tree`, which is separate.

## 1 — Setup (before listing PRs)

Follow [setup.md § Setup](references/setup.md#setup). The result is the test checkout `<S>/tree` and one throwaway-services set (data services on loopback, with that skill's record). It also chooses a stable app port and starts the dashboard on its own port, with **notify** wired when available. Write `<S>/ledger.md` ([setup.md § Ledger](references/setup.md#ledger)).

## 2 — Pick a PR

List every open PR, drafts included, all pages: `gh pr list --state open --limit 1000 --json number,title,author,headRefName,baseRefName,isDraft,statusCheckRollup,url`. Show a table with number, title, author, head → base, draft, and CI. Flag real dependencies: a base that is another open PR's head, or a description naming one. Ask which PR to test, then wait.

Fetch the chosen PR's head into `<S>/tree` ([setup.md § Checkout](references/setup.md#checkout)) and record its SHA. Read the description, the diff, the docs it touches, and its checks. Then write its checklist ([checklist.md](references/checklist.md)): the cases come from what this PR changes, never from a template.

Test one PR at a time. When a PR depends on another, test the base first. Then update the dependent and test it again; never rewrite a branch silently. Combine PRs only when the user asks, and only on an unpushed throwaway integration branch. Fixes still go to the individual PRs, and each PR's own final head is validated alone.

## 3 — Integrations and start

Inventory this PR's integrations and extra infrastructure ([setup.md § Integrations](references/setup.md#integrations)). Show the table with the fake defaults, ask which external services to enable for real, and wait. For each real choice, state its target and what it can change. Start or adjust the services, then guard and seed the data ([setup.md § Data](references/setup.md#data)). Start the app and check it is ready at its stable URL. Then report:

```markdown
## ▶ Testing PR #<n> — <title>
**Open the app:** <app URL> · **Checklist:** <dashboard URL>
**Commit:** `<sha>` · **Log in as:** <synthetic user> / <synthetic password>
**Integrations:** <name: fake | emulator | stub | real (target)>, …
**Limitations:** <what cannot be tested here and why, or "none">
```

## 4 — Feedback and fixes

Listen first. Each dashboard submission and each chat report gets one reply ([checklist.md § Submissions](references/checklist.md#submissions)). **Send feedback** opens a discussion; reproduce the problem and agree on what to fix. **Request fixes**, or a fix batch the user explicitly agrees to in chat, authorizes exactly one fresh **implementer** for that batch. Never start speculative fix workers.

Brief and spawn it per [fixes.md](references/fixes.md). It works in its own new worktree, never in `<S>/tree`, and it updates the existing PR branch. It returns the new SHA and its check results. Then deploy that SHA to the test checkout ([setup.md § Revision](references/setup.md#revision)), mark the affected cases for retest, restart the app at the same URL, and ask the user to retest. Log each batch in the ledger.

## 5 — Merge

Merge only when the user authorizes it. Plain words count ("merge it", "ship it"), and so does authorization given earlier in this session. Before merging, check all of these:

1. The remote head equals the SHA the user tested (ledger). A different head → deploy it, ask for a retest, and stop.
2. Every required check is green; wait while checks are pending.
3. Repo policy is satisfied within your authority: reviews, draft status (mark ready only with the user's OK), merge method, and branch rules. You cannot satisfy one → report it as the blocker.

Then `gh pr merge <n> --match-head-commit <tested sha>` with the repo's method. Report the merge SHA or the blocker, and offer the next PR (step 2 → **Switch**). Leave the services running until the user asks to stop, and give the cleanup command: `<invoke> stop`.

**Testing complete** on the dashboard only tells you testing is done; it never authorizes a merge.
