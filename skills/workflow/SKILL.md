---
name: workflow
description: "Use at the start of every task, before the first tool call, even when it looks small or is a follow-up, and whenever you do hands-on work with or without a `Role:` brief. Classifies the work, routes it to a model tier, decides whether to delegate, and gives each role its method; loading it costs less than it saves."
metadata:
  version: "1.7.0"
  related: "throwaway-services, evidence, pr-review"
---

## Harness

The rules here are the same in every harness, but the user wants the most out of the one you are running in: its real spawn mechanism, its own storage, its context reading, its cheapest adequate model. Generic behaviour wastes what the harness offers. So the harness is a script, `scripts/harness.sh` next to this file, documented in [harnesses.md](references/harnesses.md). Run it; never translate a harness term yourself:

```
harness.sh terms                       at the start, once: what each term means here
harness.sh storage                     your storage directory
harness.sh context                     your context reading, or unknown
harness.sh model <tier>                the built-in model id for a tier
harness.sh providers                   enabled providers and their model ids
harness.sh roster                      the user's agent roster, or `none` (then built-in defaults)
harness.sh roster-save                 save the agreed roster rules from stdin
harness.sh title "<goal>"              before the first spawn: name your thread by the goal
harness.sh spawn --role R --effort E --brief FILE --slice S [--isolated] [--provider P --model ID]   tier from the role card; above it: --tier T --why "<reason>"
harness.sh spawn --mode spin-off|fresh --goal G --tier T|--provider P --model ID --effort E --brief FILE [--wait-go] [--after ID] [--context none|this|ID] [--report-after-merge]   top-level thread (Creating threads)
harness.sh wait | read | compact <id> · harness.sh tell <id> "<message>"
```

Under bb each command performs the action; under Claude Code or Codex it prints the exact tool call to make. A term in **bold** means what `terms` says; one reported as none changes the structure, not the rules.

## Which reference to read

- A brief starting `Role: <specialty>`, or hands-on work that matches a role card (exploring, researching, spec, design, implementing, testing, reviewing, prototyping) → [working.md](references/working.md) and your card in `references/roles/`. Nothing else.
- [Delegate or do it myself](#3-delegate-or-do-it-myself) says delegate → [coordinating.md](references/coordinating.md). You are then the coordinator; there is no coordinator under a coordinator.
- Everything else here applies to everyone.

## 1. Classify and show it

Radius: **trivial** · **wide-mechanical** · **wide-synthesis** · **deep** · **wide+deep**. Wide = many places, same pattern. Deep = few places, hard reasoning, costly if subtly wrong.
Stakes: **normal** · **high** (prod data, security, money, architecture), set per slice: one high slice doesn't make the rest of the work high.

Show the classification as your first text, before any tool call other than loading skills; it starts with `Classification:`, so a missing one is visible. Restate on reclassification. Surprises at low effort → stop and reclassify. An agent can't change its own model or effort → propose a handoff. A briefed **worker** shows none: its brief is its classification.

```
Classification: <radius> · stakes <normal | high>
Plan:           <tier · model · effort> · <myself in this thread | delegate to a child thread: <role> on <provider/model>> · context <62K measured | unknown>
```

Deep or high stakes adds:
```
Why:            <the hard reasoning, or what breaks if wrong>
Verify:         <steps from the ladder>
Escalate if:    <the signal that would change this classification>
```

## 2. Routing

Tiers: **fast** (cheapest, mechanical) · **balanced** · **deep** (strongest everyday model) · **consultant** (rare, expensive second opinion); your harness maps them to models.

| Category | Tier · effort |
|---|---|
| Trivial | fast · low |
| Wide, mechanical | fast · low (balanced if it needs judgment) |
| Wide, synthesis | balanced · medium |
| Deep, normal | deep · medium → high if needed |
| Deep, high stakes | deep · high + verification ladder (reproduce → regression test → complementary review → consultant) |
| Wide + deep | split: deep spec first, then wide; per part |

- High stakes = more verification, not a bigger model.
- Consultant is a **worker** with a bounded brief that the user approves each time (coordinating.md). Effort above high only on explicit request.
- A vendor's usage limit hit → move that work to the roster's `fallback` provider for it, re-spawned once from your ledger; no fallback → spawn nothing more on it until the reset, then resume once; never re-prompt workers one by one.
- "Budget tight" → one tier down, written into the brief's Constraints as `budget: <tier>` so the worker accepts it.
- Set model and effort explicitly on every spawn (this skill authorizes it), chosen in the plan before the first spawn with each vendor's usage limit in mind: moving a running worker to another model re-reads everything. Fewer tiers or no effort setting → nearest available, noted in the classification.

## Roster

The user's agent roster says which provider and model each tier, role and Reviewer uses ([format](references/harnesses.md#roster-memory)). Without it, spawns use the built-in Claude Code and Codex defaults.

- Planning a delegation: run `harness.sh roster`. `none` → no roster here: spawn with the built-in defaults (`harness.sh model <tier>`), and do not ask the user to create one.
- Check each provider the roster names against `harness.sh providers`, and each model against that provider's listed ids. `reviewer.never` entries are exclusions, not providers: do not check them.
- Stale, or missing where `providers` discovers providers: suggest a roster with a recommended default ("I suggest … ok?"). Save it with `harness.sh roster-save` (rules on stdin) only after the user agrees; until then use the built-in defaults.
- Pick provider and model from the roster and pass them to `spawn` as `--provider` and `--model`.

## 3. Delegate or do it myself

One question, asked about the whole job (not its first step; "one grep" that leads to reading 50 files is a 50-file job): **does this work strengthen my context or pollute it?** It strengthens when I need what I'd read for the decisions still ahead. It pollutes when I'd pay for it on every later turn and never use it again. Pollution goes to a **worker** that returns a conclusion; the rest I do myself.

What pollutes:
- Reading for a conclusion: > ~5 files, big logs, a wide sweep (many places, same pattern) when my thread is deep.
- A shape change: a deep question that comes up inside a wide job, or a wide sweep inside a deep one. A thread keeps the shape it was classified with.
- Work a cheaper tier can do · 3+ independent slices · wide+deep · a review (needs fresh eyes).

What strengthens, so I do it myself:
- The brief would be as long as the work · the context is already loaded · it needs back-and-forth with the user · it is the deep core decision · it is trivial.
- Not a reason: "cheap" or "faster myself" (a deep-tier model reading files costs more than a fast-tier one). Unsure → delegate.

A coordinator has no override for reading > ~5 files: that goes to an Explorer even when the decision stays its own. A coordinator with workers running reads only reports, ledgers, and specs.

Delegating → read [coordinating.md](references/coordinating.md) first and follow it. Doing it myself and it matches a role → [working.md](references/working.md) and that card.

## Creating threads

Every new thread is one of three verbs, which fix where it sits and whether it reports back. Create it only with `harness.sh spawn --mode child|spin-off|fresh`; never a raw thread-creation command, and never set `WORKFLOW_SPAWN=1` yourself (it is for the harness script only).

| Verb | `--mode` | Placement | Tells this thread |
|---|---|---|---|
| delegate | `child` (default) | child of this thread, brief starts `Role:` | one final report, plus failures |
| spin off | `spin-off` | top-level, own worktree | one message each on DONE, BLOCKED, FAILED; nothing else |
| start fresh | `fresh` | top-level, own worktree | never; this thread is re-parented under the new one, silenced |

- **Settle both questions:** top-level or child, and whether it reports back. Plain wording that settles both is accepted ("work on issue x on a top-level thread so we can wrap this thread up" = start fresh). If either is open, ask in suggestion form: "I suggest spin off because <reason> — ok?". Never guess.
- **Modifiers**, combinable with any verb: `--wait-go` (read and plan only until the user says "go" in that thread, or this thread relays it) · `--after <thread id>` (same, released when that thread is done: this thread relays "go" when it receives that thread's done message if it is in your `spin-offs.md`, else the script tells that thread once to send "go") · `--context none|this|<thread id>` (the brief carries only the goal | goal plus relevant context, the default | goal plus a pointer to that thread; reviews and risk checks the user calls objective or fresh use `none`) · `--report-after-merge` (spin off only: DONE is sent after the PR merges) · a named model or effort, else the roster and tier rules.
- **Reuse check, before a top-level thread:** search threads (use the harness's thread search) and list the open ones in the target project. A clear open match → offer it: "@thread:X already works on this — I suggest telling it instead — ok?". Not needed for delegate.
- **Receipt:** `spawn` prints one line, `<Delegated|Spun off|Started fresh> → @thread:<id> · <child|top-level> · <provider/model · effort> · <reporting rule> [· waiting for your go | after @thread:X] · context: …`. Copy it to the user; never compose it from memory.
- **Spin-off ledger:** each spin off adds a row to `<storage>/spin-offs.md`. "How are the spin-offs?" → one table, thread (link) | status | last milestone, what the user should look at first on top, no description column; status from the thread's status plus its latest milestone message. A spin-off that crashed without sending FAILED shows as `error` there.
- **A child slice that failed is retried, not re-spawned:** `spawn` refuses a slice that has no `report.md` and names the earlier worker; retry that one, or pass `--force`.

## Branches

Name the branch when you classify the work, before the first commit: `<type>/<scope>-<topic>`, from what the work does (`feat/skills-project-kickoff`). If the name depends on something not yet settled (a new package, skill, or feature name), settle it with the user before the first push; a pushed branch with an open PR can't be renamed without closing the PR. Never push a branch name the harness generated (**auto branch**): rename it locally before its first push. A worker uses the `Branch:` line of its brief.

## 4. Context and files

Everything that must outlive a context lives in a file in **storage**, never in chat history: the spec, the ledger, the handoff note, the report, details over ~300 words. Check the **context reading** at natural breaks (a meter only the user sees doesn't count); no reading → `unknown`, reported as such, never guessed. Context is managed by shape and slicing (section 3), not by thresholds:

- Coordinator: every wake re-reads your whole context. Keep `<storage>/ledger.md` current (coordinating.md, Run); after each step is done, **compact**. A worker is compacted by its parent while idle; the top-level agent asks the user.
- Worker: the job turns out bigger than briefed → keep `<storage>/handoff.md` current at natural breaks ([Handoff](references/working.md#handoff)). Never stop mid-work; finish, and report `HANDOFF` only if you can't.
- User says "handoff" → write the note now.

## Report

Written once, when the job ends: as the final message and to `<storage>/report.md`, the path a coordinator keeps in its ledger. A reply to a parent's question is a plain answer, no block. A coordinator reports to its own parent the same way.

```
Status:   DONE | BLOCKED | HANDOFF | FAILED — <one line>
Output:   <artifact path, or the commit of the diff>
Evidence: <how verified: tests run on <commit>, checks, sources>
Open:     <issues, risks, out-of-scope findings; anything the user changed with you>
```

BLOCKED adds: `Question` (one, precise) · `Options` (A/B) · `Default` (what you'll assume if there is no answer). Notes over ~300 words go to a file in **storage**, linked from Output.
