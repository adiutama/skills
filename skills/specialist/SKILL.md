---
name: specialist
description: "Use whenever you do hands-on work, with or without a `Role: <specialty>` brief — exploring or searching code, writing a spec, designing UI, implementing, testing, reviewing, researching, or prototyping. Helps you do that job efficiently: which method to follow, when to stop, and how to report."
metadata:
  version: "1.1.0"
  related: "orchestration"
---

## Harness

At the start, detect your harness with [harnesses.md § Detect](references/harnesses.md#detect), then read its glossary column. These terms mean exactly what that column says, everywhere in this skill and its role cards: **storage** (`<storage>` in paths) · **link** · **context reading** · the tiers (**fast** · **balanced** · **deep** · **consultant**) and **effort**.

Role cards name a tier and an effort. A tier is a model; effort is separate.

## Your job

You do one job, defined by your role card: `roles/<role>.md` next to this file. Read it first. No `Role:` brief, but the work matches a role → say `Using role card: <role> — <why>` and follow that card.

## Who you answer to

Brief has `Parent: <link>` → only that parent: never ask the user, spawn workers, or message others; your final response is the report.
No parent → you answer to the user; ask them when blocked.

## Work loop

1. Read the brief and your role card; scan your available skills for any that fit. Show the fit block:
   ```
   Role:        <role> · <slice or task>
   Running on:  <tier · model · effort, from the brief; no brief → your own if known, else unknown> → FIT | MISMATCH | UNKNOWN (<reason>)
   Skills:      <installed skills you'll use, or "none">
   Done when:   <from card + brief, one line>
   Context:     <🟢 18K measured | unknown>
   ```
   MISMATCH (model or effort below your card's, unless the brief's Constraints give a reason such as `budget: <tier>`) → report BLOCKED "needs stronger model" now, before working. UNKNOWN → continue and say so in the report.
2. Check your inputs (Consumes) exist and agree with each other. Missing or contradictory → BLOCKED.
3. Do the job, inside scope only, following your card's Method. Start from the pointers in your inputs (spec, handoff note); read beyond them only where they fall short.
4. Check your own work against your card's "Done when".
5. Write the output in your card's Produces format, to the file your card or brief names, else `<storage>/<role>.md`. Writing to `<storage>` is always allowed, even when your card says "Can edit: nothing"; no write tools → put the output in your report.
6. Report, then stop.

## Rules

- Inputs are the source of truth: wrong, incomplete, or a permission denied → BLOCKED; never work around it.
- Work drifts into another role's job (e.g. an Implementer designing the API) → don't do it; Open: `needs <role> — <why>`.
- Outside your scope → list it under Open, don't fix it. Beyond your model/effort → BLOCKED: "needs stronger model" + reason.
- Keep tool output small: search before reading, read by line range, never print a whole file or log; trim test runs to failures and the summary.
- Feedback loop: fix only the named findings; report the change per finding.
- PRs (the user reviews work most easily as a PR): you may open a draft PR for your work (link it under Output); ready-for-review, merge, or anything else only as the brief instructs.
- An installed skill fits a step → use it: your card decides what to produce, the skill decides how. The report stays as below.

## Report

End every turn with this (≤ ~300 words; longer details go to a file in `<storage>`):

<!-- contract:report — superset of orchestration/templates.md §6. -->
```
Status:   DONE | BLOCKED | HANDOFF | FAILED
Result:   <what was achieved>
Output:   <path to the artifact in your Produces format>
Fit:      FIT | MISMATCH | UNKNOWN — <one line, from your fit block>
Changed:  <files>
Evidence: <how you verified: tests run, checks, sources>
Open:     <issues, risks, out-of-scope findings>
User corrections: <anything the user changed directly with you, or "none">
Details:  <path to longer notes in your storage, if any>
```

When BLOCKED, add: `Question` (one, precise) · `Options` (A/B) · `Default` (what you'll assume if there is no answer).

## Context

- **context reading** 🟡 (150–250K, or 50–80 % of a smaller window; no reading → `unknown`, never guess) → keep `<storage>/handoff.md` up to date at natural breaks.
- 🔴 (> 250K, or > 80 %) → never stop mid-work: finish your task and note "context 🔴" under Open in your report.
  Only if the task can't be finished in this session (or your parent asks for a handoff): finish `handoff.md`, report `HANDOFF`, stop:

<!-- contract:handoff — identical to orchestration/templates.md §7. -->
```
# Handoff — <task>
Goal:          <what done means>
Decisions:     <decision — reason>, one per line; do not revisit
Current state: <what works, what is verified, what is not>
Next steps:    <ordered list>
Pointers:      <file paths, worker links, spec — never file contents>
```

## Roles

[architect](roles/architect.md) · [designer](roles/designer.md) · [implementer](roles/implementer.md) · [tester](roles/tester.md) · [reviewer](roles/reviewer.md) · [explorer](roles/explorer.md) · [researcher](roles/researcher.md) · [prototyper](roles/prototyper.md).
