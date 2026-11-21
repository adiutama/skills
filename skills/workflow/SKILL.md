---
name: workflow
description: "Use at the start of every task, before the first tool call, even when it looks small or is a follow-up, and whenever you do hands-on work with or without a `Role:` brief. Classifies the work, picks the model and effort, decides whether to delegate, and gives each role its method; loading it costs less than it saves."
metadata:
  version: "2.1.0"
  related: "throwaway-services, evidence, pr-review"
---

## Goal

The user should be able to hand you work and come back to it finished: verified, reviewed, and ready to merge. Everything in this skill serves that. Ask the user only about what is truly theirs to decide, like merging, anything that can't be undone, or a question of taste. Make every other call yourself and tell them what you chose when you report. If a call is hard, get another model's view before deciding rather than handing it back to the user. And when doing it right, keeping the user out, and saving quota pull against each other, choose them in that order.

## Loop

Every task goes around this loop, whether it takes a minute or a week; what grows with the stakes is the care you put into each step. The slowest part is usually a question, because the work stops until the user answers, so ask only about what the Goal leaves to them.

When the user replies, go around again. The reply might be a question, a small fix, or a whole new job; classifying it tells you how much to redo, and everything else stays as it is. If they overrule one of your calls, write it down so a later pass doesn't undo it. The loop is over when the user says so: they accept the work, drop it, or move it to another thread. You can tell them it looks done and what's left, but that call is theirs.

```text
detect runtime, once                         → Runtime
loop:
    classify the reply, pick the model       → Classify and route   (restate only if it changed)
    delegate, or do it yourself              → Delegate or do it yourself
    verify: a council of 2+ other models reviews
            (other families first), fix blocking only,
            at most 2 rounds                 → Verify
    one-way door → ask; anything else → decide and log
    report                                   → Report
    wait for the reply; accepted, dropped or moved → end
```

## Runtime

You may be running inside an agent IDE, a CLI agent, or something else, and each offers different things: threads or subagents, storage, model choices. `scripts/runtime.sh` next to this file knows which one you are in ([runtimes.md](references/runtimes.md)). Ask it instead of guessing, and never translate one of its terms yourself. For the flags of any command, run `runtime.sh help <command>`.

| When | Command | What it gives you |
|---|---|---|
| Starting out | `terms` | what each term in this skill means in this runtime; run once |
| | `storage` · `context` | your storage directory · your context reading, or `unknown` |
| Picking a model | `roster` · `providers` | the user's roster, or `none` · the providers and model ids available here |
| | `model work\|helper` | the built-in work or helper model, when there is no roster |
| | `roster-save` | save a roster the user agreed to |
| Making threads | `title "<goal>"` | name your thread by its goal, before the first spawn |
| | `spawn` | a child worker (the role card names the model; `--helper` for mechanical edits), a council chair (`--role council-chair --author P:ID`), or with `--mode spin-off\|fresh` a top-level thread ([Creating threads](#creating-threads)) |
| | `adopt <id>` · `release <id>` | make a thread your child · make a child top-level again |
| Working with workers | `wait` · `read` · `tell` · `compact` | wait for a result · read it · send a message · shrink an idle worker's context |
| | `council-stop [<chair id>]` | end a council's members ([Verify](#verify)) |

Where the runtime has a CLI each command performs the action; elsewhere it prints the exact tool call to make. A term in **bold** means what `terms` says; one reported as none changes the structure, not the rules.

## Classify and route

Knowing the task will save you a lot of effort and time. Begin the work by deciding what kind it is, because that sets the model, the effort, and how much checking follows. Most work is normal: the work model at medium effort. Hard work is easy to get subtly wrong, or costly when it is (production data, security, money, architecture): the work model at high effort, and a council of three. Mechanical work is a lookup or one simple edit repeated: a lookup goes to a **helper**, an edit to a worker on the helper model. Don't hunt for a better model per task; the gain comes from another model family checking the work.

Make it your first text, before any tool call except loading skills:

```
Classification: <mechanical | normal | hard> · <myself | delegate: <role> on <model> · <effort>> · context <62K | unknown>
```

Hard work adds `Risk: <what breaks if it's wrong> · Verify: <your steps>`. If the work turns out different, say so and reclassify; a surprise in "mechanical" work is the usual sign. A worker with a `Role:` brief skips this, since its brief already classifies it. A model can't switch itself, so if the work needs another one, propose a handoff.

Choose the model and effort for every spawn up front, because moving a running worker makes it re-read everything. Go above high effort only when the user asks. If the user says the budget is tight, use the helper model wherever it can cope and put `budget: tight` in the brief's Constraints. If a usage limit stops work, re-spawn it once on the roster's fallback; with no fallback, wait for the reset and resume once.

### Roster

The roster names the models you use: `work` does the work, `helper` takes lookups and mechanical edits, `council` lists the reviewers in order of preference, `never` names vendors that never review, and `fallback` says where work goes when a subscription runs out ([format](references/runtimes.md#roster-memory)). Read it with `runtime.sh roster` when you plan. `none` means use the built-in defaults; don't ask the user to make one. If it names a model that `runtime.sh providers` doesn't list, suggest a fix ("I suggest … ok?") and save it with `runtime.sh roster-save` only after the user agrees.

## Delegate or do it yourself

Most work goes better in a fresh context, as long as the brief is good. So delegate freely: a new worker costs a little more up front, but a bloated context costs you on every turn after. To decide, ask one question about the whole job, not just its first step ("one grep" that leads to reading 50 files is a 50-file job): **will this strengthen your context or pollute it?** It strengthens your context when you'll need what you read for the decisions still ahead; it pollutes it when you'd pay for it on every later turn and never use it again. Send pollution to a **worker** that returns a conclusion, and do the rest yourself.

A **helper** (an in-process subagent) is only for a read-only lookup on the helper model. Every other delegated job, any edit included, is a **worker**, made only with `runtime.sh spawn`.

Delegate when the job means:
- reading for a conclusion: more than ~5 files, big logs, or a wide sweep (many places, one pattern) while your thread is deep;
- a change of shape: a deep question inside a wide job, or a wide sweep inside a deep one, since a thread keeps the shape it was classified with;
- work the helper model can do, three or more independent slices, a job that is both wide and deep, or a review, which needs fresh eyes.

Do it yourself when the brief would be as long as the work, the context is already loaded, it needs back-and-forth with the user, it is the core decision, or it is trivial. "It's cheaper" or "I'm faster" is not a reason: the work model reading files costs more than the helper model doing it. When unsure, delegate.

A coordinator never reads more than ~5 files itself, even when the decision stays its own; that goes to an Explorer. While workers run, it reads only reports, ledgers, and specs.

### What else to read

What you read next depends on the part you play. If your brief starts with `Role:`, or you're about to do hands-on work that matches a role card (exploring, researching, writing a spec, designing, implementing, testing, reviewing, prototyping), read [working.md](references/working.md) and your card in `references/roles/`, and no other reference. If you decide to delegate, you become the coordinator: read [coordinating.md](references/coordinating.md) before the first spawn. Coordinators don't nest, so a worker never takes that role; the one exception is a council chair, which gets its members as the runtime's **spawn** term says (see Verify). The rest of this file applies to everyone.

## Verify

Nothing reaches the user until someone other than its author has checked it. Verification grows with the stakes, not the model: reproduce the problem, add a regression test, then put the work before a council.

A council is at least two reviewers on different models, none of them the author's; hard work gets three. Prefer different model families, because they catch different things; when the runtime has only one family, different models of it still make a council, and the verdict says so. The main thread spawns only the chair, the first eligible model on the roster's council line, and the chair spawns the other members as its own children. Everyone reviews alone first, so no one anchors on another, and writes findings with a score from 1 to 10. Then the chair puts the findings side by side, and the members agree, dispute with evidence, or add what was missed. A finding blocks when one member shows it and no one refutes it. The chair sends back one verdict; the main thread never hears the debate. Where the runtime cannot nest, the main thread spawns the members the chair's brief names, and with fewer than two eligible families the chair still rules, marking its verdict `council: <n> of <size>, too few families`, which the main thread tells the user.

Keep the council from spreading. Only a chair nests, one level deep, and its members never spawn; the script refuses them. The chair passes its constraints to the members unchanged: the author's model, vendors at their limit, the round cap, and that only blocking findings go back. If a member fails, the chair retries it once on the fallback, otherwise rules without it and says so in the verdict. Fix rounds go back to the same chair, re-check only the named findings, and stop after two; if the scores aren't rising, stop and decide, or ask the user if the call is theirs. The rules for candidates and the test gate are in [coordinating.md](references/coordinating.md#5-run).

## Report

Written once, when the job ends: as the final message and to `<storage>/report.md`, the path a coordinator keeps in its ledger. A reply to a parent's question is a plain answer, no block. A coordinator reports to its own parent the same way.

```
Status:   DONE | BLOCKED | HANDOFF | FAILED — <one line>
Output:   <artifact path, or the commit of the diff>
Evidence: <how verified: tests run on <commit>, checks, sources>
Open:     <issues, risks, out-of-scope findings; anything the user changed with you>
```

BLOCKED adds: `Question` (one, precise) · `Options` (A/B) · `Default` (what you'll assume if there is no answer). Notes over ~300 words go to a file in **storage**, linked from Output.

## Reference

Looked up when a step needs it, not read in order.

### Creating threads

Every thread you create is one of three verbs, which fix where it sits and whether it reports back; two more, adopt and release, move an existing thread and create none. Create threads only with `runtime.sh spawn --mode child|spin-off|fresh`; never a raw thread-creation command, and never set `WORKFLOW_SPAWN=1` yourself (it is for the runtime script only).

| Verb | `--mode` | Placement | Tells this thread |
|---|---|---|---|
| delegate | `child` (default) | child of this thread, brief starts `Role:` | one final report, plus failures |
| spin off | `spin-off` | top-level, own workspace | one message each on DONE, BLOCKED, FAILED; nothing else |
| start fresh | `fresh` | top-level, this thread's workspace by default | never; this thread is re-parented under the new one, silenced |
| adopt | `runtime.sh adopt <id> [--quiet]` | an existing thread becomes a child of this thread; it keeps its project, workspace and history | like a child: wakes this thread on every outcome; `--quiet` ("adopt quietly") sets notifications off |
| release | `runtime.sh release <id>` | a child thread becomes top-level again; it keeps its project, workspace and history | nothing: it no longer has a parent |

- **Settle both questions:** top-level or child, and whether it reports back. Plain wording that settles both is accepted ("work on issue x on a top-level thread so we can wrap this thread up" = start fresh). If either is open, ask in suggestion form: "I suggest spin off because <reason> — ok?". Never guess.
- **Modifiers**, combinable with any verb: `--wait-go` (read and plan only until the user says "go" in that thread, or this thread relays it) · `--after <thread id>` (same, released when that thread is done: this thread relays "go" when it receives that thread's done message if it is in your `spin-offs.md`, else the script tells that thread once to send "go") · `--context none|this|<thread id>` (the brief carries only the goal | goal plus relevant context, the default | goal plus a pointer to that thread; reviews and risk checks the user calls objective or fresh use `none`) · `--report-after-merge` (spin off only: DONE is sent after the PR merges) · a named model or effort, else the roster ([Classify and route](#classify-and-route)).
- **Adopt** is the reverse of start fresh and the only verb that creates no thread: "make that thread a child of this thread" = adopt. It is not "absorb" (copying a thread's findings into this one and archiving it), which is a different verb that this skill does not define. Copy the receipt it prints ([format](references/runtimes.md#links-and-receipts)); the reuse check, modifiers and spin-off ledger do not apply.
- **Release** is the reverse of adopt: "make that thread top-level again" = release. Copy the receipt it prints.
- **Workspace (`--env this|new|<environment id>`, spin off and start fresh):** ask whether this thread keeps editing. Start fresh defaults to `this`: this thread goes silent, so the new one carries on in the same branch with any uncommitted work. Spin off defaults to `new`: both threads keep working, and one workspace would collide. Spin off with `--env this` only when the user says this thread stops editing ("spin off here, I'll wrap this one up"); otherwise ask. Delegate does not take `--env`: a child shares this workspace, `--isolated` gives it its own. The receipt adds `env: reused|new|<id>`.
- **Machine:** `spawn --host <id-or-name>` runs the new thread on that machine (needed when the target project's only source is on another one).
- **Reuse check, before a top-level thread:** search threads (use the runtime's thread search) and list the open ones in the target project. A clear open match → offer it in suggestion form, naming it by its **link** ([example](references/runtimes.md#links-and-receipts)). Not needed for delegate.
- **Receipt:** `spawn` prints one line ([format](references/runtimes.md#links-and-receipts)). Copy it to the user; never compose it from memory.
- **Spin-off ledger:** each spin off adds a row to `<storage>/spin-offs.md`. "How are the spin-offs?" → one table, thread (link) | status | last milestone, what the user should look at first on top, no description column; status from the thread's status plus its latest milestone message. A spin-off that crashed without sending FAILED shows as `error` there.
- **A child slice that failed is retried, not re-spawned:** `spawn` refuses a slice that has no `report.md` and names the earlier worker; retry that one, or pass `--force`.

#### Candidate verbs (not yet implemented)

Named so the user's wording is recognised; until implemented, do them by hand with the verbs above, or say the skill has no command for them.

- **gather**: adopt every open thread on one topic at once.
- **relay**: context nearly full → continue in a sibling thread (not a parent) from a handoff note.
- **queue**: children run one at a time, each spawned `--after` the previous one.
- **rescue**: copy the files worth keeping out of **storage** before archiving deletes them.
- **side room**: a quiet child the user talks to directly, for a discussion whose history should survive; a throwaway question goes to the runtime's side chat, which keeps no history.
- **move house**: spin off, adopt it, wait for go; a combination the user already runs with the verbs above.

"Wrap up" is not a verb: it is the user's everyday phrase for finishing this conversation, with no fixed routine.

### Branches

Name the branch when you classify the work, before the first commit: `<type>/<scope>-<topic>`, from what the work does (`feat/skills-project-kickoff`). If the name depends on something not yet settled (a new package, skill, or feature name), settle it with the user before the first push; a pushed branch with an open PR can't be renamed without closing the PR. Never push a branch name the runtime generated (**auto branch**): rename it locally before its first push. A worker uses the `Branch:` line of its brief.

### Context and files

Everything that must outlive a context lives in a file in **storage**, never in chat history: the spec, the ledger, the handoff note, the report, details over ~300 words. Check the **context reading** at natural breaks (a meter only the user sees doesn't count); no reading → `unknown`, reported as such, never guessed. Context is managed by shape and slicing ([Delegate or do it yourself](#delegate-or-do-it-yourself)), not by thresholds:

- Coordinator: every wake re-reads your whole context. Keep `<storage>/ledger.md` current (coordinating.md, Run); after each step is done, **compact**. A worker is compacted by its parent while idle; the top-level agent asks the user.
- Worker: the job turns out bigger than briefed → keep `<storage>/handoff.md` current at natural breaks ([Handoff](references/working.md#handoff)). Never stop mid-work; finish, and report `HANDOFF` only if you can't.
- User says "handoff" → write the note now.
