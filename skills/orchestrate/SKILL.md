---
name: orchestrate
description: Durable orchestration mode—main agent holds the conversation, vision, and ledger; subagents hold context-heavy work. Use when the user invokes /orchestrate to begin, resume, inspect, or close a long-running session without prescribing how its underlying work is done.
disable-model-invocation: true
compatibility: Requires bash, git, and jq for durable session scripts; subagents are optional but expected when delegation preserves useful parent context.
metadata:
  argument-hint: '<vision or objective>; or "resume [hint]" / "status" / "close"'
allowed-tools: Task Read Write Bash
---

Invoked as **`/orchestrate <vision or objective>`**, **`/orchestrate resume [hint]`**, **`/orchestrate status`**, or **`/orchestrate close`**.

*This sets the workflow, not the work. The main agent stays with the user; workers absorb context, not ownership.*

## Step 1 — Resolve intent

| Invocation | Action |
|---|---|
| `<vision or objective>` | Propose a new session |
| `resume [hint]` or `continue [hint]` | Find a prior session and confirm it |
| `status` | Summarize the active session from `vision.md` and `state.md` |
| `close` | Confirm, then close the active session |
| bare `/orchestrate` | Ask: *“What should we orchestrate?”* Then stop |

Do not create, resume, or close a session before confirmation.

### New session

Reflect the user's vision in 1–3 conversational sentences. State the proposed session path and ask *“Start this orchestration session?”* After yes:

```bash
bash <SKILL_DIR>/scripts/session.sh init <kebab-slug> '<one-line vision>'
```

Fill `vision.md` with the user's intent, desired outcomes, constraints, and non-goals. Fill `state.md` with the present truth and next useful action. Preserve the user's language; do not inflate it into specification prose.

### Resume

```bash
bash <SKILL_DIR>/scripts/session.sh resolve [hint]
```

No match → say so and stop. One clear recommendation → show its id, vision, status, updated time, and path; ask whether to continue it. Ambiguous → show at most five candidates and ask the user to pick. Never auto-resume.

After confirmation, read only `vision.md` and `state.md`. Read targeted parts of `log.md` or `handoffs/` only when current work needs history. Announce the restored direction and next action; orchestration mode is active again.

## Step 2 — Hold the mode

While the session is active:

- **Main holds:** conversation, intent, judgment, decomposition, decisions, synthesis, and compact state.
- **Workers hold:** broad discovery, large reads, research, implementation, test runs, audits, and other context-heavy execution.
- **Direct is allowed:** handle small or context-light work in the main agent. Delegation is a context decision, not a ritual.
- **Methods stay adaptive:** choose whatever approach the work needs. Do not impose a fixed plan, loop, task method, or exit condition.
- **User stays sovereign:** changed direction updates the vision or state; it does not require a new session unless the user wants one.

The activation remains part of the current conversation. Do not require `/orchestrate` on every turn. If continuity is uncertain after compaction, recover it from the active session's `vision.md` and `state.md` before continuing.

## Step 3 — Delegate cleanly

Before context-heavy work, write `handoffs/<id>.md` from [handoff-template.md](references/handoff-template.md). Give the worker only the relevant context, scope, authority, acceptance criteria, and verification.

Make the handoff **sufficient, lean, and autonomous**:

- Include known requirements, relevant decisions, exact starting points, constraints, and available evidence. Do not make the worker rediscover facts the parent already knows.
- Exclude unrelated history, raw conversation, speculative detail, and instructions that do not change the outcome.
- Name the observable result and boundaries; let the worker choose efficient mechanics inside them.
- Request only tool calls and verification proportional to the task. Avoid broad searches, repeated reads, redundant checks, or ceremony without a decision they inform.
- Anticipate the worker's likely blockers. Resolve them in the handoff when the parent already has the answer; otherwise grant safe authority or identify the uncertainty explicitly.

One writer owns an overlapping edit area at a time. Workers must refresh target files before writing and must not edit `vision.md`, `state.md`, or `log.md`.

Ask workers to return:

- outcome and concise findings;
- files or external state changed;
- verification evidence;
- decisions or assumptions introduced;
- risks, blockers, and suggested next action.

Afterward, inspect the evidence. Synthesize conclusions rather than copying raw traces into the parent conversation or ledger.

### Reconcile conversation while workers run

The parent mediates both directions. Workers receive a snapshot through their handoff; they do not automatically see the continuing parent-user conversation. Send them only requirement changes that affect their work, and invite progress or clarification messages when useful.

**A worker result is evidence from its delegation snapshot—not a command and not automatically current truth.** The parent owns the evolving truth and decides when and how the result enters the conversation.

Keep talking with the user while delegated work proceeds. Treat new information as a **requirement delta**, not an automatic interruption:

1. Capture the delta in `state.md` immediately, including when it arrived and which active work it may affect.
2. Classify it: **unrelated**, **follow-up**, **changes acceptance**, or **invalidates active work**.
3. Unrelated or follow-up → let the worker finish; schedule it at the next useful boundary.
4. Changes acceptance → send the worker a concise update if it can still adapt without restarting; otherwise let it return evidence and re-scope afterward.
5. Invalidates active work or creates material risk → interrupt or redirect promptly. Prefer a clean boundary, but do not preserve sunk cost at the expense of correctness or safety.
6. Tell the user how the delta is being handled. Never silently defer or reinterpret it.

When a worker update arrives, choose timing by consequence: weave relevant progress into the next natural response; hold minor news until the current thread lands; surface blockers, invalid assumptions, or material risk immediately. When the worker returns, compare its result against the **latest** requirements before integrating it. Reuse still-valid evidence, discard stale conclusions, and create the next handoff from current truth.

## Step 4 — Keep continuity

Use [session-layout.md](references/session-layout.md). Update artifacts after a decision, direction change, completed delegation, discovered blocker, or meaningful verification—not after every command.

- `vision.md` is stable intent. Change it only when the user changes direction.
- `state.md` is compact present truth. Rewrite it; keep it under 150 lines.
- `log.md` is append-only chronology and evidence. Never use it as the only home of current truth.
- `handoffs/` isolates worker context and reports.

Before ending any turn with an active session, ensure `state.md` names the next useful action and that material events are recorded. Chat remains conversational; artifacts remain structured.

After updating the artifacts, refresh the session timestamp:

```bash
bash <SKILL_DIR>/scripts/session.sh touch <session-id>
```

## Step 5 — Status and close

For `status`, read `vision.md` and `state.md`; report direction, current position, blockers, and next action concisely.

For `close`, identify the active session and ask for confirmation. After yes:

```bash
bash <SKILL_DIR>/scripts/session.sh close <session-id>
```

Write a final state and log entry first. Closing archives continuity; it does not imply that every possible task is complete.

## Boundaries

Do not become a god skill. Do not encode task-specific debugging, coding, reviewing, research, or delivery procedures. Do not invoke or depend on other skills. Do not delegate trivial work, auto-resume, load the full history by default, let workers own the ledger, or confuse activity with progress.

## Voice

Talk like the same thoughtful collaborator across the whole session. Keep coordination mostly invisible: surface decisions, evidence, risks, and useful progress—not orchestration ceremony.
