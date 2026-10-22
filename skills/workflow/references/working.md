# Working

Read when you do hands-on work: a `Role: <specialty>` brief, or work that matches a role card in `roles/`. Terms in **bold** are what `scripts/harness.sh terms` printed; `harness.sh storage` gives your storage directory ([harnesses.md](harnesses.md)). The report format is in [Report](../SKILL.md#report).

## Your job

You do one job, defined by your role card: `roles/<role>.md`. Read it first. No `Role:` brief, but the work matches a role → say `Using role card: <role> — <why>` and follow that card. Role cards name a tier and an effort; a tier is a model, effort is separate.

## Who you answer to

Brief has `Parent: <link>` → only that parent: never ask the user, spawn workers, or message others; your final response is the report.
No parent → you answer to the user; ask them when blocked.

## Work loop

1. Read the brief and your role card. The brief is your classification; show none. Its `Running on` line is the model and effort you were given: below your card's without a `budget:` reason in Constraints → BLOCKED "needs stronger model" before working.
2. Check your inputs (Consumes). They are the source of truth: missing, contradictory, wrong, or a permission denied → BLOCKED; never work around it.
3. Do the job with your card's Method. An installed skill fits a step → use it for the how; the card still says what to produce.
4. Check your own work against your card's "Done when".
5. Write the output in your card's Produces format, to the file your card or brief names, else `<storage>/<role>.md`. Writing to **storage** is always allowed, even when your card says "Can edit: nothing"; no write tools → put the output in your report.
6. Write the [Report](../SKILL.md#report), then stop.

## Turn ends

Every turn end wakes your parent, which re-reads its whole context. End a turn only with the Report, a plain answer to a question from your parent, or `HANDOFF`. Never end one to report progress ("still running", "gate in progress", "nothing new").

- A long check (test suite, CI gate, browser run) is awaited inside the turn: run it in the foreground with a timeout long enough, or poll it in a shell loop. Never wait with a **wake tool**: each firing ends your turn.
- Messages that arrive while you work: fold them into the job and answer them once, in the report. A message that asks for nothing gets no reply.

A feedback round from your parent repeats 3–6 for the findings it names, by id, and nothing else. A finding you noticed yourself, or one marked non-blocking or "for user", is not yours even if it is a one-line fix: list it under Open. Fixing it anyway is scope creep and gets reverted.

## Scope

Your scope is two things. **What**: your card's Job, and nothing another role does. **Where**: the brief's `Scope:` line, narrowed by your card's `Can edit:`. Outside the what (an Implementer designing the API) or the where (a bug in another slice) → don't do it; list it under Open as `needs <role> — <why>` or `outside scope — <what>`. Beyond your model or effort → BLOCKED "needs stronger model" + reason.

PRs: you may open a draft PR for your work (link it under Output); ready-for-review, merge, or anything else only as the brief instructs.

## Reading

Read what you need, nothing more: start from the pointers in your inputs and go beyond them only where they fall short. Search before reading, read by line range, never print a whole file or log, trim test runs to failures and the summary.

## Handoff

The job turns out bigger than briefed → keep `<storage>/handoff.md` up to date at natural breaks. Never stop mid-work. Only if the task can't be finished in this session (or your parent asks for a handoff): finish `handoff.md` in this shape, report `HANDOFF`, stop. Coordinators write the same note when the user says "handoff".

```
# Handoff — <task>
Goal:          <what done means>
Decisions:     <decision — reason>, one per line; do not revisit
Current state: <what works, what is verified, what is not>
Next steps:    <ordered list>
Pointers:      <file paths, worker links, spec — never file contents>
```

## Roles

[architect](roles/architect.md) · [designer](roles/designer.md) · [implementer](roles/implementer.md) · [tester](roles/tester.md) · [reviewer](roles/reviewer.md) · [explorer](roles/explorer.md) · [researcher](roles/researcher.md) · [prototyper](roles/prototyper.md). New card → copy [_template.md](roles/_template.md).
