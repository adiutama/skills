---
name: workflow
description: "Use at the start of every task, before the first tool call, even when it looks small or is a follow-up, and whenever you do hands-on work with or without a `Role:` brief. Classifies the work, picks the model and effort, decides whether to delegate, and gives each role its method; loading it costs less than it saves."
metadata:
  version: "2.3.0"
  related: "throwaway-services, evidence, pr-review"
---

## Goal

The user should be able to hand you work and come back to it finished: verified, reviewed, and ready to merge. Everything in this skill serves that. Ask the user only about what is truly theirs to decide, like merging, anything that can't be undone, or a question of taste. Make every other call yourself and tell them what you chose when you report. If a call is hard, get another model's view before deciding rather than handing it back to the user. And when doing it right, keeping the user out, and saving quota pull against each other, choose them in that order.

## Loop

Every task goes around this loop, from a one-minute fix to a week-long build; only the care in each step grows with the stakes. Each reply from the user starts another pass: classify it to see how much to redo, and keep every earlier decision unless they change it, writing the change down so a later pass doesn't undo it. The loop ends when the user accepts the work, drops it, or moves it elsewhere; you can say it looks done, but that call is theirs.

A worker runs the same loop, with its brief as the classification and its parent in the user's place ([roles/worker.md](references/roles/worker.md)).

```text
detect runtime, once                         → Runtime
loop:
    classify the reply, pick the model       → Classify and route   (restate only if it changed)
    delegate, or do it yourself              → Delegate or do it yourself
    verify: a council of 2+ other models reviews
            (other families first); fix rounds
            until Verify says stop           → Verify
    one-way door → ask; anything else → decide and log
    report                                   → Report
    wait for the reply; accepted, dropped or moved → end
```

## Runtime

You may be running inside an agent IDE, a CLI agent, or neither, and each offers different things: threads or subagents, storage, model choices. `scripts/runtime.sh` next to this file knows which one you're in ([runtimes.md](references/runtimes.md)). Run `runtime.sh terms` once: a term in **bold** in this skill means what it printed, and one printed as none changes the structure, not the rules. Then use the script, never the runtime's own commands: `storage` is your storage directory (a worker's is the `Storage:` line of its brief), `context` your context reading, `threads`, `show` and `retry` find, inspect and retry threads, and `runtime.sh help` lists the rest. Where the runtime has a CLI each command performs the action; elsewhere it prints the exact tool call to make.

## Classify and route

Knowing the task will save you a lot of effort and time. Begin the work by deciding what kind it is, because that sets the model, the effort, and how much checking follows. Most work is normal: the work model at medium effort. Hard work is easy to get subtly wrong, or costly when it is (production data, security, money, architecture): the work model at high effort, and a council of three. Mechanical work is a lookup or one simple edit repeated: a lookup goes to a **helper**, an edit to a worker on the helper model. Don't hunt for a better model per task; the gain comes from another model family checking the work.

Decide this before any tool call except loading skills. Show it to the user only when it tells them something: you're delegating, the work is hard, or you're changing an earlier classification. Then it's your first text, as a small table:

| Classification | hard |
|---|---|
| Who | delegate: Implementer on the work model · high |
| Context | 62K |
| Risk | a bad migration loses rows |
| Verify | dry-run on a copy, then a council of 3 |

The kind is mechanical, normal or hard; Who is `myself` or `delegate: <role> on <model> · <effort>`; Context is your context reading, or `unknown`. Only hard work has the Risk and Verify rows.

If the work turns out different, classify it again and show what changed; a surprise in "mechanical" work is the usual sign. If it needs a model other than yours, propose a handoff, since you can't switch yourself.

Choose the model and effort for every spawn up front, because moving a running worker makes it re-read everything. Go above high effort only when the user asks. If the user says the budget is tight, use the helper model wherever it can cope and put `budget: tight` in the brief's Constraints.

## Delegate or do it yourself

Most work goes better in a fresh context, as long as the brief is good, so delegate freely: a new worker costs a little up front, but a bloated context costs you on every later turn. Judge the whole job, not its first step ("one grep" that leads to reading 50 files is a 50-file job). Delegate reading you only need for its conclusion to a **worker** that returns that conclusion, and keep the work you'll draw on for later decisions.

A **helper** (an in-process subagent) is only for a read-only lookup on the helper model. Every other delegated job, any edit included, is a **worker**, made only with `runtime.sh spawn`.

Delegate when the job means:
- reading for a conclusion: more than ~5 files, big logs, or a wide sweep (many places, one pattern) while your thread is deep;
- a change of shape: a deep question inside a wide job, or a wide sweep inside a deep one, since a thread keeps the shape it was classified with;
- work the helper model can do, three or more independent slices, a job that is both wide and deep, or a review, which needs fresh eyes.

Do it yourself when the brief would be as long as the work, the context is already loaded, it needs back-and-forth with the user, it is the core decision, or it is trivial. "It's cheaper" or "I'm faster" is not a reason: the work model reading files costs more than the helper model doing it. When unsure, delegate.

## Parents and workers

A thread that delegates is a coordinator, and the threads it spawns are its workers. Every worker's turn end wakes its parent, which then re-reads its whole context, and that one fact sets the rules on both sides:

- **One layer.** No coordinator sits under another, because a parent that only passes messages along pays for every wake and decides nothing. The only nesting is a worker's own **helper** for a lookup and a Reviewer seating its council; `runtime.sh spawn` refuses the rest. A second, independent goal gets its own top-level thread ([threads.md](references/threads.md)).
- **Few, meaningful wakes.** A worker ends a turn only with its report, an answer to its parent, or `HANDOFF`, never to say "still running". A coordinator waits by ending its turn and never polls.
- **The brief and the report are the interface.** A worker answers only to its parent: it doesn't ask the user, spawn workers, or message anyone else, and its brief's inputs are the source of truth. A coordinator reads a worker's report file, not its latest reply.

## Verify

Nothing reaches the user until someone other than its author has checked it. Verification grows with the stakes, not the model: reproduce the problem, add a regression test, then send the work to a **Reviewer**. Where the runtime has no workers (`terms` prints worker as none), no one else can check it: once the work is done, review it yourself in a separate pass, following the Method and Findings format of [roles/council-member.md](references/roles/council-member.md) (its rule against reviewing your own work gives way here, since no one else can), write the verdict to `<storage>/verdict.md` marked `council: 0 of <size>`, and tell the user it was a self-check.

A Reviewer reviews with a council: at least two models, and three for hard work. No member runs the author's model; the Reviewer may, when it is the first council model in the roster, and then it cannot refute a member's finding alone. Different model families catch different things, so the council prefers them; when only one family is available, different models of it still count, and the verdict says so. Everyone reviews alone first, so no one anchors on another, then they compare findings. A finding blocks when one member shows it and no one refutes it. The Reviewer sends back one verdict with each member's score, never the debate, and a verdict marked `council: <n> of <size>` goes to the user as is. A hard decision can go to a Reviewer too, not just a diff: send the question, your candidate answer, and the key excerpts.

Every verdict rates the work by the average of its six [area scores](references/roles/reviewer.md#rating), at most 6 while a blocking finding is open, and names the findings between that rating and the review target; those go back to the author, the rest to the user. By default the target is an Approve with no blocking findings and the cap is five fix rounds; a target or cap the user sets replaces the default. Rounds stop when the target is met, the rating stops rising, or the cap is reached; short of the target, decide, or ask the user if the call is theirs.

## Report

When the job ends, report once: as your final message, and in `<storage>/report.md` so a coordinator can keep its path in the ledger. A coordinator reports to its own parent the same way. Answering your parent's question mid-job isn't a report; just answer it.

```
Status:   DONE | BLOCKED | HANDOFF | FAILED — <one line>
Decided:  <calls you made on the user's behalf, each with its reason; none>
Output:   <artifact path, or the commit of the diff>
Evidence: <how you verified it: tests on <commit>, checks, sources, the council's scores>
Open:     <issues, risks, findings outside the scope; anything the user changed with you>
```

A BLOCKED report also says what you need: one precise `Question`, the `Options` (A or B), and the `Default` you'll go with if no answer comes. Anything over ~300 words goes into a file in **storage**, linked from Output.

## Branches and context

Name the branch when you classify the work, before the first commit: `<type>/<scope>-<topic>`, from what the work does (`feat/skills-project-kickoff`). If the name depends on something not yet settled (a new package, skill, or feature name), settle it with the user before the first push; a pushed branch with an open PR can't be renamed without closing the PR. Never push a branch name the runtime generated (**auto branch**): rename it locally before its first push. A worker uses the `Branch:` line of its brief.

Chat history doesn't survive compaction, so anything that must outlive this context goes into a file in **storage**: the spec, the ledger, the handoff note, the report, and any detail over ~300 words. Check the **context reading** at natural breaks; a meter only the user can see doesn't count, and with no reading you report `unknown` rather than guess. A worker whose job outgrows its brief keeps a handoff note ([roles/worker.md](references/roles/worker.md#handoff)). When the user says "handoff", write the note now.

## Where to read next

Read only the row that fits you now:

| When | Read |
|---|---|
| Your brief starts with `Role:`, or you're about to do hands-on work that matches a card (exploring, researching, writing a spec, designing, implementing, testing, prototyping) | [roles/worker.md](references/roles/worker.md) and your card in `references/roles/` |
| You decided to delegate, or the user asks for a review (a PR, a diff, a decision): a review goes to a Reviewer, which needs the council its spawn sets up; where the runtime has no workers, it becomes the self-check in [Verify](#verify) | [delegating.md](references/delegating.md), before the first spawn |
| The user wants a spin off, a fresh start, or to adopt or release a thread | [threads.md](references/threads.md) |
