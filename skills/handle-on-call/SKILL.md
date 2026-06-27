---
name: handle-on-call
description: On-call from Slack paste—ack thread, triage, confirm, fix or skip, push, close loop. Session under .agents/artifacts/.../handle-on-call/ (project-local; global fallback). Posts via Slack MCP.
disable-model-invocation: true
compatibility: Slack MCP enabled on the agent; jq; git for code fixes.
metadata:
  argument-hint: "<pasted Slack alert or permalink> | resume [incident-id]"
allowed-tools: Bash(bash:* git:*) Read Write CallMcpTool
---

Invoked as `/handle-on-call <pasted Slack alert>` or `/handle-on-call resume [incident-id]`.

*Silence kills trust on-call—**ack** fast, **triage** honest, **close the loop**.*

Full loop: [workflow.md](references/workflow.md).

## Step 1 — Mode

| Input | Mode |
|-------|------|
| `resume` / `resume <id>` | Resume |
| pasted alert / permalink | Full workflow |

Empty input (non-resume) → ask once; stop.

## Step 2 — Session

**Resume:** `bash <SKILL_DIR>/scripts/resolve-session.sh [incident-id]` — null → stop; show path + timeline; confirm before work.

**New:** `bash <SKILL_DIR>/scripts/start-session.sh '<paste>'` → JSON paths + `has_thread`. Include Slack permalink in paste when you have it.

## Step 3 — Slack MCP

Per [slack-mcp.md](references/slack-mcp.md). Find Slack MCP in enabled servers; read tool schemas.

**Not present** → ask user to enable/connect Slack MCP for this agent; stop. Continue only after MCP is available or user explicitly chooses manual paste.

## Step 4 — Ack

Per [ack.md](references/ack.md). Post via MCP **before** deep triage. Update tracker **ack** → done.

## Step 5 — Triage

Read `alert_path`; investigate (logs, code, runbooks). Write `report_path` per [output.md](references/output.md). Update tracker **triage** → done.

## Step 6 — Confirm

Present report. Ask once: **fix** \| **skip** \| **need-info**. Record in tracker. Do not execute until confirmed.

## Step 7 — Execute

| Choice | Action |
|--------|--------|
| **fix** | Minimal fix and/or runbook steps; summarize in tracker |
| **skip** | Record reason; no code changes |
| **need-info** | Jump to Step 9 with need-info reply; stop |

## Step 8 — Push

Skip if no code changes. Commit + push per [push.md](references/push.md). Update tracker **push**.

## Step 9 — Reply

Closing thread message per [reply.md](references/reply.md) via Slack MCP. Update tracker **reply** → done; `meta.md` status → `closed`.

Manual paste fallback only if user chose it in Step 3. End with session path.

Missing `jq` → offer install.
