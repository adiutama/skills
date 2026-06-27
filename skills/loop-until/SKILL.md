---
name: loop-until
description: >-
  Exit-driven subagent loop — like /loop, but until a condition is met. Session
  handoff docs span iterations and conversations. Say "resume" to continue on this
  branch (with confirmation). Not for timed /loop schedules.
disable-model-invocation: true
compatibility: Requires git for artifact paths; jq and bash for session scripts.
metadata:
  argument-hint: "<until-condition> in natural language; or "resume" / "resume <hint>"
allowed-tools: Task Read Write Bash
---

Invoked as **`/loop-until <condition>`** in natural language — e.g. “lint is clean in src/”, or **`resume`** (works in a new conversation).

Parent orchestrates only. Work runs in **subagents**. Continuity lives in **session artifacts** ([session-layout.md](references/session-layout.md)), not parent context.

## Step 1 — Parse intent

| Field | Required | Notes |
|-------|----------|-------|
| Until (exit) | yes* | *from session when resuming |
| Goal | yes* | *skip when resuming |
| Instructions | no | defaults to goal |
| Max | no | default `10` |
| Mode | no | `auto` or `human-gate` |
| Recon | no | iteration 0 read-only map before fixes |

### Resume

Triggers: `resume`, `/loop-until resume`, `continue`, `resume <hint>` (no new until-clause).

```bash
bash <SKILL_DIR>/scripts/resolve-resume.sh [hint]
```

1. No sessions → stop.
2. Show one recommendation: session id, goal, until/exit, status, iteration count, path.
3. **Wait for yes / pick / cancel** — never auto-loop.
4. **yes** → load `master.md` + `meta.md`; Step 3 from `iteration_count + 1`.
5. **pick** → up to 5 candidates; confirm again.
6. Resume + new goal → new session unless user says otherwise.

Named session: `list-sessions.sh 5` → match id/slug/goal; same confirm block.

### New loop — until gate

Vague until (`when done`, `until good`) → ask once; do not start. See [exit-examples.md](references/exit-examples.md).

### Confirm before first iteration

≤5 lines: until/exit, goal, max, mode, recon, **session id + path**, new vs resume. Risky goals (prod, mass delete, auth) → explicit confirmation.

## Step 2 — Session

**New:** `bash <SKILL_DIR>/scripts/init-session.sh [kebab-slug]` → fill `meta.md` + `master.md` ([master-template.md](references/master-template.md)).

**Resume:** see Step 1.

## Step 2b — Recon (optional)

When user wants a map first, or scope is unfamiliar: `explore` + `readonly: true`, [recon-template.md](references/recon-template.md) → validate → merge → iteration 1 from `Recommended next`. Skip for narrow scope (single file, single command exit).

## Step 3 — Iteration loop

For `i` from start to `max`:

1. `compact-master.sh <session_dir>/master.md 150`
2. Write `handoff.md` ([handoff-template.md](references/handoff-template.md))
3. Launch one subagent (`run_in_background: false`) — see subagent table below
4. Prompt: [worker-template.md](references/worker-template.md)
5. `validate-report.sh <session_dir>/report.md` — invalid → retry once; stop
6. Merge into `master.md`: log row, Attempts, Decisions; `meta.md` → `active`; archive → `reports/<NN>.md`
7. Exit check:
   - `done` → [verify](references/exit-examples.md#verification). Pass → `meta.md` `done`; finish. Fail → next iteration.
   - `blocked` → `meta.md` `blocked`; stop.
   - `continue` → stall check; else loop.
   - `i == max` → `meta.md` `max-reached`; stop.

**Human-gate:** after merge, stop until user replies (continue, redirect, ship-it).

**Stall:** same blocker/`Recommended next` twice, or two `continue` with no file changes + same evidence → `blocked`.

**Parent tokens:** read validated report + `master.md` (merge); write `handoff.md`. No workspace re-reads except exit verify.

## Step 4 — Finish

≤25 lines. Always include session id and path. End with: *Continue later: `resume` or `resume <slug>`*

```markdown
## Loop until: <condition>
**Session:** `<id>` · **Path:** `~/.agents/artifacts/.../loop-until/sessions/...`
| # | Status | Summary |
**Outcome:** done | blocked | max reached | stalled
**Until met:** yes/no — one line
**Next:** if blocked, stalled, or max reached
```

## Subagent selection

| Situation | Type |
|-----------|------|
| Recon (iter 0) | `explore`, `readonly: true` |
| Edits, fixes | `generalPurpose` |
| Read-only audit | `explore`, `readonly: true` |
| Tests, lint, CLI | `shell` |

## Anti-patterns

Auto-resume · shared mutable state across sessions · child edits `master.md` · new loop without until-clause · parent does iteration work · auto-loop in human-gate · timed polling (use `/loop`)

## References

[session-layout.md](references/session-layout.md) · [worker-template.md](references/worker-template.md) · [recon-template.md](references/recon-template.md) · [exit-examples.md](references/exit-examples.md) · [examples.md](references/examples.md)
