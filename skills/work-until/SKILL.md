---
name: work-until
description: Work until a condition holds—handoff, subagents, verify. Parent holds the clause; workers hold the work. Resume with confirmation; not for timed schedules.
disable-model-invocation: true
compatibility: Requires git for artifact paths; jq and bash for session scripts.
metadata:
  argument-hint: '<until-condition> in natural language; or "resume" / "resume <hint>"'
allowed-tools: Task Read Write Bash
---

Invoked as **`/work-until <condition>`** — e.g. “lint is clean in src/”, or **`resume`** (new chat OK).

*Parent keeps the **until** and the ledger; subagents keep the sweat. **Handoff** lives in **session** files—not in a bloated parent window.*

Layout: [session-layout.md](references/session-layout.md).

## Step 1 — Parse intent

| Field | Required | Notes |
|-------|----------|-------|
| Until | yes* | *from session when resuming |
| Goal | yes* | *skip when resuming |
| Instructions | no | defaults to goal |
| Max | no | default `10` |
| Mode | no | `auto` or `human-gate` |
| Recon | no | iter 0 read-only map |

### Resume

`resume`, `/work-until resume`, `continue`, `resume <hint>` — no new until-clause.

```bash
bash <SKILL_DIR>/scripts/resolve-resume.sh [hint]
```

No sessions → stop. Recommend one (id, goal, until, status, iter, path). **Wait yes / pick / cancel**—never auto-continue. **yes** → `master.md` + `meta.md`; Step 3 from `iteration_count + 1`. **pick** → ≤5 candidates; confirm again. New goal on resume → new session unless user says otherwise.

### Until gate

Vague **until** → ask once; do not start. [exit-examples.md](references/exit-examples.md).

### Confirm (first iteration)

≤5 lines: until, goal, max, mode, recon, session id + path, new vs resume. Risky goals → explicit confirm.

## Step 2 — Session

**New:** `bash <SKILL_DIR>/scripts/init-session.sh [kebab-slug]` → `meta.md` + `master.md` ([master-template.md](references/master-template.md)). **Resume:** Step 1.

## Step 2b — Recon (optional)

Unfamiliar scope or user asks map: `explore` readonly, [recon-template.md](references/recon-template.md) → validate → merge → iter 1 from `Recommended next`. Skip for narrow scope.

## Step 3 — Iteration

For `i` from start to `max`:

1. `compact-master.sh <session_dir>/master.md 150`
2. `handoff.md` ([handoff-template.md](references/handoff-template.md))
3. One subagent (`run_in_background: false`) — table below
4. [worker-template.md](references/worker-template.md)
5. `validate-report.sh <session_dir>/report.md` — invalid → retry once; stop
6. Merge `master.md`; `meta.md` → `active`; archive → `reports/<NN>.md`
7. Exit: `done` → **verify** ([exit-examples.md](references/exit-examples.md#verification)); pass → `done` / fail → next · `blocked` → stop · `continue` → **stall** check · `i == max` → `max-reached`

**Human-gate:** stop after merge until user replies. **Stall:** same blocker twice or two empty **continue** → `blocked`. **Parent tokens:** report + merge only; write `handoff`; no re-reads except **verify**.

## Step 4 — Finish

≤25 lines; session id + path. End: *Continue later: `resume` or `resume <slug>`*

## Subagents

| Situation | Type |
|-----------|------|
| Recon (0) | `explore`, `readonly: true` |
| Edits | `generalPurpose` |
| Audit | `explore`, `readonly: true` |
| CLI/tests | `shell` |

## Anti-patterns

Auto-resume · shared mutable state · child edits `master.md` · until-less start · parent does worker work · auto-continue in human-gate · timed polling

## References

[worker-template.md](references/worker-template.md) · [recon-template.md](references/recon-template.md) · [exit-examples.md](references/exit-examples.md) · [examples.md](references/examples.md)
