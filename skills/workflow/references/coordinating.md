# Coordinating

Read when [Delegate or do it myself](../SKILL.md#3-delegate-or-do-it-myself) says delegate. Terms in **bold** are what `scripts/harness.sh terms` printed; spawn, wait, read, tell, and compact are its subcommands ([harnesses.md](harnesses.md)). Workers follow [working.md](working.md) and a role card in `roles/`, and return the [Report](../SKILL.md#report). The sections follow the order of the work: who you are, decide the shape, plan, spawn, run, finish.

## 1. Who you are

You are the coordinator: the thread that talks to the user. Your workers do hands-on work and report to you; they never coordinate.

| | Coordinator | Worker |
|---|---|---|
| Does | classifies, plans, briefs, spawns, reads reports, keeps the ledger, decides, reports to the user | one job per its role card |
| Edits | its ledger and briefs | what its brief's Scope allows |
| Never | hands-on work; reading code or diffs itself (an Explorer or the reports do that) | spawning workers, except one helper for a question of its own; asking the user |
| Runs on | deep · medium | per role, section 2 |

**One layer.** There is no coordinator under a coordinator. Reason: every worker turn end wakes its parent, and a parent that only relays re-reads its whole context at every wake and decides nothing. A tree of one manager over two leads over four implementers each is the shape this rule forbids. A second goal independent of the current one is a second top-level thread the user starts, with its own plan; the user is the only thing above coordinators. **Nesting** is for pairing: a worker may spawn one helper for a question of its own (an Implementer asking an Explorer) and reads that answer itself.

## 2. Decide the shape

- Trivial → answer it yourself.
- One role → one worker: show the classification, wait for the user, spawn.
- Two or more roles, or multi-step → write the plan (section 3), get it approved, run the workers.
- A second goal independent of the first → ask the user to start it as its own thread with its own plan.
- A user asking for a spawn approves the spawn, not its tier and effort: still show the Plan line first.

Roles a worker can take:

| Role | Tier · effort | Consumes → Produces |
|---|---|---|
| Explorer | fast · low | question → pointers |
| Researcher | balanced · medium | question → sourced summary |
| Prototyper | balanced · medium | risky question → GO / NO-GO |
| Architect | deep · high | goal → `spec.md` (interfaces, slices, pointers, checkable acceptance criteria) |
| Designer | deep · medium | goal, spec → `design.md` |
| Implementer | fast · low; balanced · medium for judgment | spec + slice → diff + a test per acceptance criterion |
| Tester | fast · low; balanced · medium for tricky tests | bug report, or criteria spanning slices or needing the running app + diff → PASS / FAIL |
| Reviewer | deep · medium | spec + diff → Approve / Request changes, findings `C`/`W`/`N` |
| Consultant | consultant tier | one precise question → verdict (brief below, user approves each use) |

## 3. Plan

The default plan is three steps, in order, each a step the one before must finish:

| Step | Who | Tier · effort | Done when |
|---|---|---|---|
| Spec | Architect | deep · high | `spec.md` names every interface, every slice with its pointers, and acceptance criteria a worker can check without asking. You check it. |
| Build | Implementer, one per slice | fast · low; balanced · medium for judgment | each slice's criteria tests pass; the named owner has run the full suite on the candidate commit |
| Review | Reviewer, one | deep · medium | Approve on the whole diff |

Then the user verifies by hand (section 6). A trivial spec (one interface, one slice) you can write yourself in the brief; then the plan is two steps.

Slices: every worker pays the **spawn cost** and reads to orient, often 100K+ tokens before its first change. One Implementer is the default. Split into parallel slices only when the writes are disjoint and each slice is large enough to be worth a fresh orientation. A later slice in the same files goes to the Implementer that built the earlier one, by **tell**, after compacting it.

Add a step only with a reason, written in the plan:
- Explorer or Researcher before Spec: the question can't be answered from the pointers at hand.
- Prototyper before Spec: a risky assumption (can library X do Y) would otherwise be settled by the whole build.
- Designer after Spec: there is UI.
- Tester after Build: a bug to reproduce first, criteria that span slices, or criteria that need the running app. Otherwise the Implementer's tests and the full gate are the test.
- A second Build step: a slice depends on another's API. Order follows dependencies, never ease; a change in the earlier slice re-checks the later one.

Fixed: one Reviewer, over the whole diff, at the end. A plan can't turn that into per-slice reviews. High-stakes slices are named as its focus; it still runs at medium. One full test gate per candidate commit, owned by one named worker; everyone else cites it by commit and adds focused probes.

Approval: the user approves the plan once. Needed again for an extra step, a higher tier, a consultant, more than 4 parallel workers, or more workers than `Expected`.

Plan, as shown to the user:

```
Goal:           <what done means>
Classification: <from SKILL.md section 1>

| Step | Slice | Role | Tier · effort | Done when |
|---|---|---|---|---|
| Spec | spec.md | Architect | deep · high | you check it |
| Build | <slice> | Implementer | fast · low | criteria tests pass · full gate: <owner> |
| Build | <slice> (parallel, disjoint) | Implementer | balanced · medium | criteria tests pass |
| Review | whole diff | Reviewer | deep · medium | Approve |
| Verify | <what the user can see> | user | — | user OK |

Expected:  <n> workers; max <n> parallel
Added steps and why: <none | step — reason>
```

## 4. Spawn

### Thread titles

Every thread in a tree is titled so the sidebar, search, and notifications sort and read by goal:

| Thread | Title | Example |
|---|---|---|
| Coordinator (yours) | the goal, as the user would say it | `cost sheet accuracy` |
| Worker | `<goal> › <Role> · <slice>` | `cost sheet accuracy › Implementer · totals row` |
| Helper a worker spawns for itself | `<goal> › <Role> · <slice> › Explorer · <question>` | `cost sheet accuracy › Implementer · totals row › Explorer · where is rounding` |

Before the first spawn, set your own title: `harness.sh title "<goal>"`. Thread titles are auto-generated from the first message and rarely match; a tree spawned under the wrong title keeps it. `harness.sh spawn` then builds each worker title from your thread's title, the role, and `--slice`. Slices and branches are named by what they do (`totals row`, `fix/cost-sheet-rounding`), never by number or sequence words (`slice 2`, `wave 1`, `phase b`).

### Steps

1. Create `<storage>/workers/<role>-<slice>/` and write the brief there as `brief.md`.
2. `harness.sh spawn --role <Role> --tier <tier> --effort <effort> --brief <that file> --slice <slice>`; add `--isolated` when the worker needs its own working copy. The script sets the model and **permission** for your harness. Without **isolation**, parallel workers share one working directory: only disjoint writes.
3. The harness links the worker to you; its `Parent:` line is text. Never detach a worker to silence its notifications: that link is what delivers its failures.

A worker without write tools returns its artifact in its final message; never brief it to write a file. Spawn a whole step in one turn, then end the turn.

Brief, a self-contained file that always starts with `Role:`:

```
Role: <role>
Parent: <your link>
Storage: <absolute path you created for this worker>
Load the `workflow` skill, read references/working.md, and follow role card: <role>.

Goal:        <what done means>
Inputs:      <file paths: spec, design, handoff note, relevant code>
Scope:       <files or areas it may change; what it must not touch — the "where" in working.md>
Constraints: <decisions already made, with reasons; `budget: <tier>` if routed down>
Running on:  <tier · model · effort you spawned it with; model from harness.sh model <tier>>
```

Skill not installed for the worker → drop the "Load" line and append this, with the Report and Handoff blocks pasted in full from SKILL.md and working.md:

```
Your job:  <role row from section 2>
Rules:     talk only to your parent; never ask the user or spawn workers.
           Inputs are the source of truth: wrong or missing → BLOCKED.
           Use any installed skill that fits a step; the report format stays.
           PRs: draft only, unless this brief says otherwise.
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

Consultant brief, shown to the user with its size before every use:

```
Question:   <one precise question>
Context:    <the problem in ≤ 10 lines>
Candidate:  <the proposed solution>
Excerpts:   <only the key code, ≤ ~200 lines>
Answer in:  ≤ 300 words — verdict, risks missed, what to change
```

## 5. Run

- **Wait** by ending your turn: each worker's turn end wakes you with its result.
- The ledger is the state, updated at every wake. Fill a row from the worker's report file for the named candidate, not from its latest reply, which may be a question or progress. Never poll a worker for status.
- A wake with nothing to decide → one ledger line, no tool calls, end the turn.
- Feedback (Tester or Reviewer → Implementer): **tell** the same Implementer the Blocking list only, by finding id, nothing else from the review; the same Tester or Reviewer re-checks the fix, and dependents if an interface changed. Max 2 rounds, then you decide: fix the spec, a stronger tier, or ask the user.
- Non-blocking findings (the Reviewer's For-user list) never reach the Implementer. They go to the ledger under Open and to the user on the next board as `Needs you?`; the user picks which become new work, each as its own slice with its own brief. Forwarding one, or an Implementer fixing one unasked, is scope creep: revert it.
- BLOCKED: answer from spec, ledger, or judgment by **tell** (no **tell** → re-spawn with the answer in the brief); otherwise ask the user. Wrong spec → back to the Architect, re-check dependents. "Needs stronger model" without a `budget:` constraint → re-spawn one tier up. `Open: needs <role>` → add that role to the plan.
- A worker the user steps into reports the user's changes to its parent.
- After each step is done and the ledger is current, **compact**: ask the user, or let auto-compaction run. Compact an idle worker yourself before giving it a later slice, in the same command as the **tell** that gives it, so the replay and the real start arrive together.
- Where **compact** says the next wake replays the last report: a wake whose text matches that worker's last report is noise. No ledger change, no tool calls, no post; end the turn.

Ledger, `<storage>/ledger.md`:

```
# Ledger — <goal>
Goal: <what done means>
Updated: <time>

## Board
| Worker | Role | Tier · effort | Status | Candidate | Report | Last result |
|---|---|---|---|---|---|---|
(Candidate = commit the status refers to · Report = path of the report file for it)

## Decisions
- <decision> — because <reason> (<who decided>)

## Open
- <question or blocker> — waiting on <whom>

## Next
- <step>
```

## 6. Finish and report to the user

Post to the user at a milestone only: work DONE · a gate needing the user (plan, spec, verify) · BLOCKED beyond your judgment · a failed worker · non-blocking findings to decide. A wake without a milestone is a ledger line and nothing else. Each post is the board and only the decisions the user can make.

A Verify post says what to check, what is real versus placeholder, and the exact commands; it names the user's own skills when installed (a disposable environment for the case, evidence capture, PR review) with arguments filled in. Agents never run those skills.

PRs: any agent may open a draft PR for its work; ready-for-review or merge only as the user instructs, passed down in the brief.

Board:

```
| Worker | Goal | Status | Needs you? |
|---|---|---|---|
| <link> | auth migration | 🔄 2/3 implementers done | — |
| <link> | slow sync | ⛔ blocked | Keep old column for 1 release? (default: yes) |
```

When the whole job is DONE, end with the [Report](../SKILL.md#report) like any worker; the user is your parent.
