# Coordinating

Read when [Delegate or do it yourself](../SKILL.md#delegate-or-do-it-yourself) says delegate. Terms in **bold** are what `scripts/runtime.sh terms` printed; spawn, wait, read, tell, and compact are its subcommands ([runtimes.md](runtimes.md)). Workers follow [working.md](working.md) and a role card in `roles/`, and return the [Report](../SKILL.md#report). The sections follow the order of the work: who you are, decide the shape, plan, spawn, run, finish.

## 1. Who you are

You are the coordinator: the thread that talks to the user. Your workers do hands-on work and report to you; they never coordinate.

| | Coordinator | Worker |
|---|---|---|
| Does | classifies, plans, briefs, spawns, reads reports, keeps the ledger, decides, reports to the user | one job per its role card |
| Edits | its ledger and briefs | what its brief's Scope allows |
| Never | hands-on work; reading code or diffs itself (an Explorer or the reports do that) | spawning workers, except one helper for a question of its own (a council chair also spawns its members); asking the user |
| Runs on | work · medium | per role, section 2 |

**One layer.** There is no coordinator under a coordinator. Reason: every worker turn end wakes its parent, and a parent that only relays re-reads its whole context at every wake and decides nothing. A tree of one manager over two leads over four implementers each is the shape this rule forbids. A second goal independent of the current one is a top-level thread you create with `--mode spin-off` or `--mode fresh` ([Creating threads](../SKILL.md#creating-threads)), with its own plan; the user is the only thing above coordinators. **Nesting** is for pairing: a worker may use one **helper** for a lookup of its own (an Implementer asking where something lives) and reads that answer itself; anything more is the coordinator's worker. The one exception is a council chair: it spawns its members as its own children, one level deep, and they spawn nothing (`runtime.sh spawn` refuses both a member's spawn and a chair's spawn of anything but members).

## 2. Decide the shape

- Trivial → answer it yourself.
- One role → one worker: show the classification, wait for the user, spawn.
- Two or more roles, or multi-step → write the plan (section 3), get it approved, run the workers.
- A second goal independent of the first → a top-level thread: settle spin off vs start fresh with the user (suggestion form), run the reuse check, then `runtime.sh spawn --mode spin-off|fresh`. Spin-offs are tracked in `<storage>/spin-offs.md`; relay "go" to a waiting spin-off when its `--after` thread's done message arrives.
- A user asking for a spawn approves the spawn, not its model and effort: still show the classification first.

Roles a worker can take:

| Role | Model · effort | Consumes → Produces |
|---|---|---|
| Explorer | helper · low | question → pointers |
| Researcher | work · medium | question → sourced summary |
| Prototyper | work · medium | risky question → GO / NO-GO |
| Architect | work · high | goal → `spec.md` (interfaces, slices, pointers, checkable acceptance criteria) |
| Designer | work · medium | goal, spec → `design.md` |
| Implementer | work · medium; helper · low for mechanical edits | spec + slice → diff + a test per acceptance criterion |
| Tester | work · medium | bug report, or criteria spanning slices or needing the running app + diff → PASS / FAIL |
| Council chair | work · medium, model from the council line | spec + diff → `verdict.md`: Approve / Request changes, findings `C`/`W`/`N` |
| Council member | work · medium, spawned by the chair (where the runtime cannot nest: by you, as the chair's brief says) | the chair's brief → `findings.md` with a score |

A hard call you would otherwise take to a stronger model goes to the council: a chair with the question, the candidate answer and the key excerpts as its Consumes.

## 3. Plan

The default plan is three steps, in order, each a step the one before must finish:

| Step | Who | Model · effort | Done when |
|---|---|---|---|
| Spec | Architect | work · high | `spec.md` names every interface, every slice with its pointers, and acceptance criteria a worker can check without asking. You check it. |
| Build | Implementer, one per slice | work · medium; helper · low for mechanical edits | each slice's criteria tests pass; the named owner has run the full suite on the candidate commit |
| Review | Council: chair (+ members) | work · medium | Approve on the whole diff |

Then the user verifies by hand (section 6). A trivial spec (one interface, one slice) you can write yourself in the brief; then the plan is two steps.

Slices: every worker pays the **spawn cost** and reads to orient, often 100K+ tokens before its first change. One Implementer is the default. Split into parallel slices only when the writes are disjoint and each slice is large enough to be worth a fresh orientation. A later slice in the same files goes to the Implementer that built the earlier one, by **tell**, after compacting it.

Add a step only with a reason, written in the plan:
- Explorer or Researcher before Spec: the question can't be answered from the pointers at hand.
- Prototyper before Spec: a risky assumption (can library X do Y) would otherwise be settled by the whole build.
- Designer after Spec: there is UI.
- Tester after Build: a bug to reproduce first, criteria that span slices, or criteria that need the running app. Otherwise the Implementer's tests and the full gate are the test.
- A second Build step: a slice depends on another's API. Order follows dependencies, never ease; a change in the earlier slice re-checks the later one.

Fixed: one council, over the whole diff, at the end: you spawn its chair, the chair gets the members (SKILL.md, Verify); a verdict marked `too few families` is passed to the user. A plan can't turn that into per-slice reviews. High-stakes slices are named as its focus, and hard work gets a council of 3; it still runs at medium. One full test gate per candidate commit, owned by one named worker; everyone else cites it by commit and adds focused probes. Two commits are candidates: the one you send to the council chair for the whole-diff review, and the final one, after the last Approve, that you hand the user to verify. A fix-round commit, sent back to the chair to re-check its findings, is not a candidate: it runs the focused tests for the files it changed. The full gate runs on the final candidate even when the first one passed it, unless no commit came between them.

Approval: the user approves the plan once. Needed again for an extra step, a model other than the roster's, effort above high, more than 4 parallel workers, or more workers than `Expected`. The approval also covers the routine steps inside the plan: committing and pushing on the planned branch, opening a draft PR, starting the next planned step, catching up with the main branch, and moving work to a roster fallback at a usage limit. Do them without asking and record each in the ledger; a worker started for one of them (a catch-up worker, a re-spawn on a fallback provider) is not an extra step and counts toward neither `Expected` nor the parallel limit; ask only for merge, marking a PR ready, or anything the list above names. A question you would otherwise ask ("Ok to push?") becomes a line in the next post: what you did and why.

Plan, as shown to the user:

```
Goal:           <what done means>
Classification: <from SKILL.md, Classify>

| Step | Slice | Role | Model · effort | Done when |
|---|---|---|---|---|
| Spec | spec.md | Architect | work · high | you check it |
| Build | <slice> | Implementer | work · medium | criteria tests pass · full gate: <owner> |
| Build | <slice> (parallel, disjoint) | Implementer | helper · low | criteria tests pass |
| Review | whole diff | Council: chair (+ members) | work · medium | Approve |
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

Before the first spawn, set your own title: `runtime.sh title "<goal>"`. Thread titles are auto-generated from the first message and rarely match; a tree spawned under the wrong title keeps it. `runtime.sh spawn` then builds each worker title from your thread's title, the role, and `--slice`. Slices are named by what they do (`totals row`), never by number or sequence words (`slice 2`, `wave 1`, `phase b`). Branches follow [Branches](../SKILL.md#branches); name each worker's branch before spawning it and put it on the brief's `Branch:` line, or the worker pushes the runtime's **auto branch**.

### Steps

1. Create `<storage>/workers/<role>-<slice>/` and write the brief there as `brief.md`.
2. `runtime.sh spawn --role <Role> --effort <effort> --brief <that file> --slice <slice>`; add `--isolated` when the worker needs its own working copy. The script takes the model from the role card (`work` or `helper`) through the roster's work and helper lines, else the built-in defaults, and sets **permission** for your runtime. `--helper` puts a work card on the helper model (an Implementer for a mechanical edit); `--provider <p> --model <id>` overrides both, only with a reason in the plan. A council: `--role council-chair --author <provider>:<model>` of whoever wrote the diff, `--size 3` for hard work (default 2), `--limited <provider,…>` for vendors at their usage limit; omit `--provider`/`--model`, the script walks the roster's council line (runtimes.md, spawn). The chair's brief names the work to review; the script adds the council constraints and the member command. Without **isolation**, parallel workers share one working directory: only disjoint writes.
3. The runtime links the worker to you; its `Parent:` line is text. Never detach a worker to silence its notifications: that link is what delivers its failures.

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
Branch:      <type>/<scope>-<topic> the worker commits and pushes on; none for a worker that doesn't commit
Constraints: <decisions already made, with reasons; `budget: tight` if routed to the helper model>
Running on:  <work | helper · provider/model · effort, as the spawn receipt printed it>
```

Skill not installed for the worker → drop the "Load" line and append this, with the Report and Handoff blocks pasted in full from SKILL.md and working.md:

```
Your job:  <role row from section 2>
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

## 5. Run

- **Wait** by ending your turn: each worker's turn end wakes you with its result.
- The ledger is the state, updated at every wake. Fill a row from the worker's report file for the named candidate, not from its latest reply, which may be a question or progress. Never poll a worker for status.
- `runtime.sh tell <id>` warns on stderr when that worker's `report.md` or storage folder is missing, and `runtime.sh spawn` refuses to re-spawn a child slice whose `report.md` is missing (it names the earlier worker: `bb thread retry <id>`; `--force` overrides). `tell` only warns.
- A wake with nothing to decide → one ledger line, no tool calls, end the turn.
- Feedback (Tester or council → Implementer): **tell** the same Implementer the Blocking list only, by finding id, nothing else from the verdict; then **tell** the same Tester, or the same council chair, the fixed ids and the fix commit to re-check, and dependents if an interface changed. The chair re-checks with its members and keeps each round's scores in its verdict. Max 2 rounds, then you decide: fix the spec, more effort, or ask the user; scores not rising after a round → decide then.
- A commit after the council's Approve (a late fix, a user tweak) goes back to the same council chair for that commit only, before it is pushed as done; it is not a new round. The one exception is a catch-up commit with the main branch: it follows the next rule instead, so it gets no review when clean and a review of the conflict hunks only when it had conflicts. A catch-up commit that also changes anything beyond resolving conflicts is a late fix, reviewed as one.
- The main branch moved: catching up is mechanical, so the helper model does it: an Implementer spawned with `--helper`, its brief naming the branch and the step below; never the work model. Catch up once, before marking the PR ready or when a conflict blocks work, not on every move. Clean rebase or merge, and main changed none of the files the diff touches → focused tests only, no review, a ledger line. Main changed files the diff touches → focused tests on those files plus one full gate. Conflicts → resolve them; the same council chair re-checks only the conflict hunks. Never a new review round, and it does not count toward the 2-round cap.
- A worker or your own turn stops at a usage limit: move that work to the roster's `fallback` at once (SKILL.md, Classify and route), without asking the user; no fallback → note the reset time in the ledger and resume then. Never leave it idle until the user says "continue".
- Non-blocking findings (the verdict's For-user list) never reach the Implementer. They go to the ledger under Open and to the user on the next board as `Needs you?`; the user picks which become new work, each as its own slice with its own brief. Forwarding one, or an Implementer fixing one unasked, is scope creep: revert it.
- BLOCKED: answer from spec, ledger, or judgment by **tell** (no **tell** → re-spawn with the answer in the brief); otherwise ask the user. Wrong spec → back to the Architect, re-check dependents. "Needs stronger model" without a `budget:` constraint → re-spawn on the work model, or one effort level up. `Open: needs <role>` → add that role to the plan.
- A worker the user steps into reports the user's changes to its parent.
- After each step is done and the ledger is current, **compact**: ask the user, or let auto-compaction run. Compact an idle worker yourself before giving it a later slice, in the same command as the **tell** that gives it, so the replay and the real start arrive together.
- Where **compact** says the next wake replays the last report: a wake whose text matches that worker's last report is noise. No ledger change, no tool calls, no post; end the turn.

Ledger, `<storage>/ledger.md`:

```
# Ledger — <goal>
Goal: <what done means>
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
