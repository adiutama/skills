---
name: address-pr-feedback
description: Triage PR feedback until clear—fetch, select, fix, push, notify humans, refresh. Session under ~/.agents/artifacts/.../address-pr-feedback/. --fetch-only for verify-only.
disable-model-invocation: true
compatibility: Requires gh CLI authenticated to GitHub, and jq.
metadata:
  argument-hint: "<PR URL or number> [--fetch-only] | resume [pr-number]"
allowed-tools: Bash(gh:* git:* bash:*) Read Write
---

Invoked as `/address-pr-feedback <PR URL or number> [--fetch-only]` or `/address-pr-feedback resume [pr-number]`.

*Every thread earns **triage**—fix, push, notify humans, defer, stale. Stop when **clear**, not when tired.*

Default: **until-clear** ([workflow.md](references/workflow.md)). `--fetch-only` → present only.

## Step 1 — Mode

| Input | Mode |
|-------|------|
| `resume` / `resume <pr>` | Resume |
| `<pr> --fetch-only` / `--list` | Fetch only |
| `<pr>` | Full workflow |

No PR (non-resume) → ask once; stop.

## Step 2 — Session

**Resume:** `bash <SKILL_DIR>/scripts/resolve-session.sh [pr-number]` — null → stop; show path + **pending** IDs; confirm before work.

**Fetch:** `bash <SKILL_DIR>/scripts/start-session.sh <PR>` → JSON paths + `total_count`. Zero → merge-ready; stop.

## Step 3 — Present

`findings_path` → IDs per [output.md](references/output.md) → `report_path`; print index.

## Step 4 — Triage

Skip if `--fetch-only` or unconfirmed resume. Ask once: IDs / all / none ([workflow.md](references/workflow.md)). Update `tracker.md`. `none` → stop with path.

## Step 5 — Address

Each **pending** ID: read → minimal fix → summarize; OK before **addressed** unless batch approved.

## Step 6 — Push

Skip if `--fetch-only` or no file changes from the address pass.

Commit addressed fixes and `git push` the PR branch per [push.md](references/push.md). Stop on push failure — do not notify until remote has the commit.

## Step 7 — Notify

Skip if `--fetch-only`, nothing **addressed**, no human feedback in the batch (all bot-sourced or bot-only PR), or push failed.

For each **addressed** **human** finding: draft reply (what changed, where) → user confirms batch → post per [notify.md](references/notify.md). No human items → skip straight to refresh. Bots re-check alone.

## Step 8 — Refresh

Re-fetch same PR; reconcile [workflow.md#refresh-reconciliation](references/workflow.md#refresh-reconciliation). Print pending + `total_count`.

## Step 9 — Loop or stop

| When | Then |
|------|------|
| `total_count == 0` | **Clear** |
| Pending IDs | User confirms → Step 5 |
| New unresolved | Step 4 |
| User done | Stop + `resume` hint |

Full turns end with session path. Legacy: `.../fetch-outstanding-pr-feedback/` — migrate or full path.

Missing `gh`/`jq` or auth → offer install/login; ask first.
