---
name: workflow
description: "Use at the start of every task, before the first tool call, even when it looks small or is a follow-up, and whenever you do hands-on work with or without a `Role:` brief. Classifies the work, routes it to a model tier, decides whether to delegate, and gives each role its method; loading it costs less than it saves."
metadata:
  version: "1.1.0"
  related: "throwaway-services, evidence, pr-review"
---

## Harness

The rules here are the same in every harness, but the user wants the most out of the one you are running in: its real spawn mechanism, its own storage, its context reading, its cheapest adequate model. Generic behaviour wastes what the harness offers. So the harness is a script, `scripts/harness.sh` next to this file, documented in [harnesses.md](references/harnesses.md). Run it; never translate a harness term yourself:

```
harness.sh terms                       at the start, once: what each term means here
harness.sh storage                     your storage directory
harness.sh context                     your context reading, or unknown
harness.sh model <tier>                the model id for a tier
harness.sh title "<goal>"              before the first spawn: name your thread by the goal
harness.sh spawn --role R --tier T --effort E --brief FILE --slice S [--isolated]
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
Plan:           <tier · model · effort> · <myself | worker: role | plan with workers> · context <62K measured | unknown>
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
- A vendor's usage limit hit → spawn nothing more on it until the reset, then resume once from your ledger; never re-prompt workers one by one.
- "Budget tight" → one tier down, written into the brief's Constraints as `budget: <tier>` so the worker accepts it.
- Set model and effort explicitly on every spawn (this skill authorizes it), chosen in the plan before the first spawn with each vendor's usage limit in mind: moving a running worker to another model re-reads everything. Fewer tiers or no effort setting → nearest available, noted in the classification.

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
