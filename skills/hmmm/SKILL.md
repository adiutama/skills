---
name: hmmm
description: Durable thinking session—frame, delegated discovery, synthesis, options. Parent holds the question and ledger; subagents hold codebase reads and web research. Use when the user says hmmm followed by a question, or needs to think through a design without bloating chat.
disable-model-invocation: true
compatibility: Requires git for artifact paths; jq and bash for session scripts.
metadata:
  argument-hint: '<your question or problem>; or "resume"'
allowed-tools: Task Read Write Bash
---

Invoked as **`/hmmm <your question>`** — say it like you'd ask a colleague. Or **`/hmmm resume`** (new chat OK).

Examples:

- `/hmmm should we use OAuth or magic link for orgs?`
- `/hmmm where should rate limiting live — edge or Convex?`
- `/hmmm is it worth migrating notifications to push before mobile v2?`

Bare **`/hmmm`** with no question → ask once: *"What's on your mind?"* — then stop.

*Discovery belongs in subagents; the parent holds the **question** and the **ledger**. Chat stays conversational—synthesis, not grep dumps.*

Layout: [session-layout.md](references/session-layout.md).

## Step 1 — Parse intent

Everything after `/hmmm` (before any flags) is the **question** — keep the user's words; don't rewrite into spec-speak.

| Field | Required | Notes |
|-------|----------|-------|
| Question | yes* | *verbatim from invocation, or session when resuming |
| Constraints | no | from question or follow-up |
| Mode | no | `rapid` (default) or `deep` |
| Lanes | no | auto from question |

**Bare `/hmmm`:** one line — *"What's on your mind?"* — stop. No session until they answer.

### Resume

`resume`, `/hmmm resume`, `continue`, `resume <hint>` — no new question.

```bash
bash <SKILL_DIR>/scripts/resolve-resume.sh [hint]
```

No sessions → stop. Recommend one (id, question, phase, path). **Wait yes / pick / cancel**—never auto-continue. **yes** → load `meta.md` + `master.md`; jump to saved **phase**. **pick** → ≤5 candidates; confirm again.

### Frame gate

Too vague to act on (e.g. "make it better") → one conversational follow-up; do not spawn discovery. [frame-examples.md](references/frame-examples.md).

### Confirm (new session)

Mirror the question back in plain language (1–2 sentences), then: planned lanes, mode, session path. Ask *"Sound right?"* — broad scope needs explicit yes before subagents.

## Step 2 — Session

**New:** `bash <SKILL_DIR>/scripts/init-session.sh [kebab-slug]` → skeleton ([master-template.md](references/master-template.md)). Fill `meta.md` `problem:` with the **verbatim question**, mode, phase=`frame`. **Resume:** Step 1.

## Step 3 — Frame (parent)

Write to `master.md`: question (user's words), constraints, success criteria, open questions, non-goals. Set `meta.md` phase=`discover` when frame is solid.

Talk like a colleague—short sentences, no report voice. **Parent does not** codebase-wide search or web fetch here—only clarify with the user.

## Step 4 — Discover (subagents, parallel)

Run only lanes the problem needs. Skip when scope is narrow and user already supplied context.

| Lane | When | Subagent | Output |
|------|------|----------|--------|
| **codebase** | repo patterns, prior art, blast radius | `explore`, `readonly: true` | `discovery/codebase.md` |
| **external** | libs, docs, industry patterns | `docs-researcher` or `generalPurpose` | `discovery/external.md` |
| **compare** | evaluate 2+ approaches against repo | `explore`, `readonly: true` | `discovery/compare.md` |

Prompt from [discovery-prompt.md](references/discovery-prompt.md). Launch **in parallel** when multiple lanes apply. Each child: read `master.md`; write **only** its output file; chat reply = one line.

After all finish:

```bash
bash <SKILL_DIR>/scripts/validate-discovery.sh <session_dir>/discovery/<lane>.md
```

Invalid → retry that lane once; then mark partial in `meta.md` and continue.

**Parent reads:** validation JSON + each report's `## Summary` and `## Findings` only—not full tool traces. Distill into `brief.md` ([brief-template.md](references/brief-template.md)), ≤80 lines. Set phase=`synthesize`.

## Step 5 — Synthesize (parent)

From `brief.md` + user constraints, draft 2–4 options → `options.md` ([options-template.md](references/options-template.md)). Each option: approach, pros, cons, fits repo because, risks, effort (S/M/L).

Present options conversationally—≤15 lines in chat; full detail stays on disk. Set phase=`ideate`.

## Step 6 — Ideate (parent + user)

| Mode | Behavior |
|------|----------|
| **rapid** | Present options; user picks, combines, or rejects—one round unless they ask to dig |
| **deep** | One decision fork at a time; wait for answer before next ([deep-forks.md](references/deep-forks.md)) |

Log each resolved fork to `master.md` **Decisions** and `decisions.md`. Unknowns → back to Step 4 (targeted lane only) or ask user once.

When user picks a direction (or session goal met): phase=`outcome`.

## Step 7 — Outcome

Write `recommendation.md` ([recommendation-template.md](references/recommendation-template.md)): chosen approach, rationale, evidence pointers (`discovery/*`, `decisions.md`), open risks, suggested next step (spike, ADR, implementation—no code unless asked).

Set `meta.md` status=`done`. Close with a short conversational summary (≤20 lines) + session path.

## Context budget (parent)

| Do in parent | Delegate to subagent |
|--------------|---------------------|
| Frame, questions, synthesis, options | Codebase search/read |
| Read `brief.md`, `options.md` summaries | Web/docs research |
| Merge decisions | Directory walks, large file reads |
| `compact-master.sh` before long ideate | Comparing patterns across many files |

Before ideate rounds beyond 3: `bash <SKILL_DIR>/scripts/compact-master.sh <session_dir>/master.md 120`

## Voice

- User's question → stored and echoed **verbatim** in `master.md` / `meta.md`.
- Replies: colleague at the whiteboard—not a spec, not a ticket description.
- One question at a time in **deep** mode; in **rapid**, still readable, not a wall of bullets.
- Discovery and files stay structured; **chat** stays human.

## Anti-patterns

Parent greps/reads codebase during discover · dumping discovery files into chat · skipping session files · discovery before frame · rewriting the user's question into jargon · multiple questions at once in **deep** mode · auto-resume · child edits `master.md` or `brief.md`

## References

[session-layout.md](references/session-layout.md) · [discovery-prompt.md](references/discovery-prompt.md) · [brief-template.md](references/brief-template.md) · [options-template.md](references/options-template.md) · [recommendation-template.md](references/recommendation-template.md) · [frame-examples.md](references/frame-examples.md) · [deep-forks.md](references/deep-forks.md)
