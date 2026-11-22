# Templates

The shapes a coordinator writes ([delegating.md](delegating.md)). Fill them in; don't add sections.

## Plan

Shown to the user for approval.

```
Goal:           <what done means>
Classification: <from SKILL.md, Classify>

| Step | Slice | Role | Model · effort | Done when |
|---|---|---|---|---|
| Spec | spec.md | Architect | work · high | you check it |
| Build | <slice> | Implementer | work · medium | criteria tests pass · full gate: <owner> |
| Build | <slice> (parallel, disjoint) | Implementer | helper · low | criteria tests pass |
| Review | whole diff | Council: Reviewer (+ members) | work · medium | the target is met |
| Verify | <what the user can see> | user | — | user OK |

Target:    <the default target and cap ([Verify](../SKILL.md#verify)), or the user's in their place, e.g. rating 9, at most 10 fix rounds>
Expected:  <n> workers; max <n> parallel
Added steps and why: <none | step — reason>
```

## Brief

Written to `<storage>/workers/<slice>/brief.md` before the spawn, one folder per worker, named by what it does (`totals-row`, `review-totals-row`). The folder is the slice: `spawn` titles the worker with its name and looks for its `report.md` there, so the Storage line points at it and `--slice` is left out. The worker writes its output and `report.md` to that folder, not to what `runtime.sh storage` prints for it. It is the worker's only context, so it stands alone and starts with `Role:`. A worker that commits gets the branch it commits and pushes on; a read-only worker gets `none`, and a worker that finds it must push without a branch reports BLOCKED. `spawn` appends the `Running on` line with the model and effort it picked, so the brief doesn't carry one. A worker without write tools returns its artifact in its final message, so don't ask it for a file.

```
Role: <role>
Parent: <your link>
Storage: <absolute path of <storage>/workers/<slice>/, which holds this brief>
Load the `workflow` skill, read references/roles/worker.md, and follow role card: <role>.

Goal:        <what done means>
Inputs:      <file paths: spec, design, handoff note, relevant code>
Scope:       <files or areas it may change; what it must not touch — the "where" in roles/worker.md>
Branch:      <type>/<scope>-<topic> the worker commits and pushes on | none
Constraints: <decisions already made, with reasons; `budget: tight` if routed to the helper model>
Target:      <Reviewer and fix-round briefs only: the plan's Target line>
```

If the worker doesn't have the skill installed, drop the "Load" line and append this, with the Report and Handoff blocks pasted in full from SKILL.md and roles/worker.md:

```
Your job:  <the Job line of the role card>
Rules:     talk only to your parent; never ask the user or spawn workers.
           Inputs are the source of truth: wrong or missing → BLOCKED.
           Use any installed skill that fits a step; the report format stays.
           PRs: draft only, unless this brief says otherwise.
           Branch: commit and push only on the Branch line; rename a generated branch to it before the first push.
           Start from the pointers in your inputs. Keep tool output small: read by line range,
           never print whole files or logs, trim test runs to failures and the summary.
Output:    write your artifact to <storage>/<role>.md unless Goal names a file (<storage> = the Storage path above);
           no write tools → put it in your final message.
Report:    once, when the job ends, as your final message and to <storage>/report.md; a reply to a question is a plain answer:
           <Report block, with the BLOCKED fields>
Handoff:   the job turns out bigger than briefed → keep <storage>/handoff.md current; never stop mid-work.
           Can't finish here → report HANDOFF with the note in this shape:
           <Handoff block>
```

## Thread titles

`runtime.sh title` sets yours; `spawn` builds the rest from it, the role and `--slice`.

| Thread | Title | Example |
|---|---|---|
| Coordinator (yours) | the goal, as the user would say it | `cost sheet accuracy` |
| Worker | `<goal> › <Role> · <slice>` | `cost sheet accuracy › Implementer · totals row` |
| Helper a worker spawns for itself | `<goal> › <Role> · <slice> › Explorer · <question>` | `cost sheet accuracy › Implementer · totals row › Explorer · where is rounding` |

## Ledger

`<storage>/ledger.md`, updated at every wake.

```
# Ledger — <goal>
Goal: <what done means>
Target: <the plan's Target line; the user's change, when they make one>
Updated: <time>

## Board
| Worker | Role | Model · effort | Status | Candidate | Report | Last result |
|---|---|---|---|---|---|---|
(Candidate = commit the status refers to · Report = path of the report file for it)

## Decisions
- <decision> — because <reason> (<who decided>)

## Open
- <question or blocker> — waiting on <whom>

## Next
- <step>
```

## Board

What the user sees in each post.

```
| Worker | Goal | Status | Needs you? |
|---|---|---|---|
| <link> | auth migration | 🔄 2/3 implementers done | — |
| <link> | slow sync | ⛔ blocked | Keep old column for 1 release? (default: yes) |
```
