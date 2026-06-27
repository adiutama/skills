---
name: address-pr-feedback
description: Address unresolved PR review feedback — triage which items to fix and loop until clear. Saves session artifacts under ~/.agents/artifacts/<owner>/<repo>/<branch-slug>/address-pr-feedback/. Use --fetch-only to list only (e.g. loop-until verify).
disable-model-invocation: true
compatibility: Requires gh CLI authenticated to GitHub, and jq.
metadata:
  argument-hint: "<PR URL or number> [--fetch-only] | resume [pr-number]"
allowed-tools: Bash(gh:*) Read Write
---

Invoked as `/address-pr-feedback <PR URL or number> [--fetch-only]` or `/address-pr-feedback resume [pr-number]`.

Default mode runs the full **address-until-clear** workflow ([workflow.md](references/workflow.md)). `--fetch-only` stops after present (no triage).

## Step 1 — Parse intent

| Input | Mode |
|-------|------|
| `resume`, `resume <pr-number>` | Resume existing session |
| `<pr> --fetch-only` or `--list` | Fetch + present only |
| `<pr>` | Full workflow |

If PR identity missing (non-resume), ask once and stop.

## Step 2 — Session

**Resume:**

```bash
bash <SKILL_DIR>/scripts/resolve-session.sh [pr-number]
```

If `session_dir` is null → stop. Show PR title, session path, pending IDs from `tracker.md`. **Wait for confirm** before address or refresh.

**Fetch (new or refresh):**

```bash
bash <SKILL_DIR>/scripts/start-session.sh <PR_URL_OR_NUMBER>
```

Parse JSON: `session_dir`, `findings_path`, `tracker_path`, `report_path`, `total_count`, `url`, `title`.

If `total_count == 0`, print merge-ready message and stop (skip triage).

## Step 3 — Present

Read `findings_path`. Assign severity IDs per [output.md](references/output.md). Save formatted report to `report_path`. Print summary + findings index.

## Step 4 — Triage (full workflow only)

Skip when `--fetch-only` or resume not yet confirmed.

Ask once ([workflow.md](references/workflow.md)):

```text
Which findings should we address this round? (IDs, all, none)
```

Update `tracker.md`: **Selected this workflow**, **Progress** rows (`pending`), append **Rounds** row when starting a round.

If `none` → stop with session path for later `resume`.

## Step 5 — Address

For each selected **pending** ID:

1. Read finding from `report_path` / `findings.json`.
2. Implement minimal fix.
3. Summarize change per ID; wait for user OK before marking **addressed** unless they said to batch.

Do not mark addressed until fix is confirmed or refresh drops the item.

## Step 6 — Refresh

Re-run Step 2 (`start-session.sh` same PR). Reconcile `tracker.md` per [workflow.md](references/workflow.md#refresh-reconciliation).

Print: pending count, newly stale IDs, remaining `total_count`.

## Step 7 — Continue or finish

| Condition | Action |
|-----------|--------|
| `total_count == 0` | Done — PR merge-ready |
| Pending selected IDs | User confirms → Step 5 |
| New unresolved not in tracker | Step 4 triage |
| User says done | Stop; print session path + `resume` hint |

Always end full-workflow turns with session path: `~/.agents/artifacts/.../address-pr-feedback/pr-<N>/`.

Sessions created before the rename may live under `.../fetch-outstanding-pr-feedback/`. Resume by full session path or migrate the folder to `address-pr-feedback/`.

## Notes

- Missing `gh` / `jq` → offer install; ask before running.
- `gh` auth fails → offer `gh auth login`.
