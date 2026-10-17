---
name: orchestration
description: Use at the start of every task, before the first tool call, even when the task looks small or is a follow-up in the same conversation. Helps you work faster and cheaper — size the task, pick the right model and effort, decide whether to hand parts to subagents, and keep context small.
metadata:
  version: "1.0.1"
  related: "specialist, throwaway-services, evidence, pr-review"
---

## Harness

At the start, detect your harness with [harnesses.md § Detect](references/harnesses.md#detect), then read its glossary column. These terms mean exactly what that column says, everywhere in this skill and its references: **worker** · **spawn** · **wait** · **read** · **tell** · **link** · **nesting** · **isolation** · **storage** (`<storage>` in paths) · **compact** · **permission** · **specialist installed** · **context reading** · **spawn cost** · the tiers and **effort**. A term your harness lacks (`—`) changes the structure, not the rules.

## 1. Classify and show it

Radius: **trivial** · **wide-mechanical** · **wide-synthesis** · **deep** · **wide+deep**. Wide = many places, same pattern. Deep = few places, hard reasoning, costly if subtly wrong.
Stakes: **normal** · **high** (prod data, security, money, architecture).

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
- "Budget tight" → one tier down, written into the brief's Constraints as `budget: <tier>` so the worker accepts it.
- Set model and effort explicitly on every spawn (this skill authorizes it). Fewer tiers or no effort setting → nearest available, noted in the classification block.

## 3. Delegate or do it myself

Decided by the work, in every context zone.

- **Delegate** if any: a cheaper tier can do it · 3+ independent slices · wide+deep · needs fresh eyes (review) · reading > ~5 files or big logs for a conclusion.
- **Do it myself** if any (overrides): brief ≈ work · context already loaded · needs back-and-forth with the user · the deep core decision · trivial.

Delegating → read [delegation.md](references/delegation.md) first and follow it. **specialist installed** → specialists use it (shorter briefs, full methods).

## 4. Context zones

Check the **context reading** at natural breaks; a meter only the user sees doesn't count. No reading → `unknown`; report it as such, never guess.

🟢 < 150K: nothing · 🟡 150–250K: update the ledger or handoff note at the next natural break · 🔴 > 250K: never stop mid-work; finish the task, note the zone in the report, then — Manager: update the ledger, **compact** · Lead: update the ledger, **compact**, or hand over if a phase just finished · Specialist: report; `HANDOFF` (templates §7) only if the task can't be finished. Window under ~300K → 🟡 at 50 %, 🔴 at 80 %. User says "handoff" → write the note now.

## 5. Files, not history

Hand over through files (spec, handoff note, details). Manager and Leads keep `<storage>/ledger.md` (templates §5), updated each step. Report details over ~300 words go to a file.
