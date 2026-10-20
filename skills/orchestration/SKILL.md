---
name: orchestration
description: "Use at the start of every task, before the first tool call, even when the task looks small, low-effort, or is a follow-up. Loading it costs less than it saves: it routes small work to the cheapest model and splits large reads across subagents."
metadata:
  version: "1.3.0"
  related: "specialist, throwaway-services, evidence, pr-review"
---

## Harness

At the start, detect your harness with [harnesses.md § Detect](references/harnesses.md#detect), then read its glossary column. These terms mean exactly what that column says, everywhere in this skill and its references: **worker** · **spawn** · **wait** · **read** · **tell** · **link** · **nesting** · **isolation** · **storage** (`<storage>` in paths) · **compact** · **permission** · **specialist installed** · **context reading** · **spawn cost** · the tiers and **effort**. A term your harness lacks (`—`) changes the structure, not the rules.

## 1. Classify and show it

Radius: **trivial** · **wide-mechanical** · **wide-synthesis** · **deep** · **wide+deep**. Wide = many places, same pattern. Deep = few places, hard reasoning, costly if subtly wrong.
Stakes: **normal** · **high** (prod data, security, money, architecture), set per slice: one high slice doesn't make the rest of the work high.

Show the classification block ([templates.md §1](templates.md)) before working; restate on reclassification; trivial gets one line. Surprises at low effort → stop and reclassify. An agent can't change its own model or effort → propose a handoff.

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
- Consultant: the user approves each use, with a bounded brief (templates §3). Effort above high only on explicit request.
- A vendor's usage limit hit → spawn nothing more on it until the reset, then resume each Lead once from its ledger; never re-prompt workers one by one.
- "Budget tight" → one tier down, written into the brief's Constraints as `budget: <tier>` so the worker accepts it.
- Set model and effort explicitly on every spawn (this skill authorizes it), chosen in the plan before the first spawn with each vendor's usage limit in mind: moving a running Lead to another model re-reads everything. Fewer tiers or no effort setting → nearest available, noted in the classification block.

## 3. Delegate or do it myself

Decided by the whole job, not its first step, in every context zone: "one grep" that leads to reading 50 files is a 50-file job.

- **Delegate** if any: a cheaper tier can do it · 3+ independent slices · wide+deep · needs fresh eyes (review) · reading > ~5 files or big logs for a conclusion.
- **Do it myself** only if one of these holds for the whole job (overrides): brief ≈ work · context already loaded · needs back-and-forth with the user · the deep core decision · trivial. For a Manager or Lead, no override covers reading > ~5 files: that reading goes to an Explorer even when the decision stays yours. A Manager with Leads running reads only reports, ledgers, and specs.
- "Cheap" or "faster to do myself" is not an override: a deep-tier model reading files costs more than a fast-tier one. Unsure → delegate.

Delegating → read [delegation.md](references/delegation.md) first and follow it. **specialist installed** → specialists use it (shorter briefs, full methods).

## 4. Context zones

Check the **context reading** at natural breaks; a meter only the user sees doesn't count. No reading → `unknown`; report it as such, never guess.

🟢 < 150K: nothing · 🟡 150–250K: update the ledger or handoff note at the next natural break · 🔴 > 250K: never stop mid-work. Specialist: finish the task, note the zone in the report; `HANDOFF` (templates §7) only if the task can't be finished. Manager and Lead: every wake re-reads your context, so don't wait for the end; at the next natural break (a report read, a layer DONE) update the ledger, then **compact** — a Lead tells the Manager `context 🔴`, spawns nothing more, and ends its turn; the Manager **compact**s it while it is idle. Window under ~300K → 🟡 at 50 %, 🔴 at 80 %. User says "handoff" → write the note now.

## 5. Files, not history

Hand over through files (spec, handoff note, details). Manager and Leads keep `<storage>/ledger.md` (templates §5), updated each step. Report details over ~300 words go to a file.
