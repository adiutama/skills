# Worker

These rules hold for every role card in this folder, whether a `Role:` brief sent you here or your work matches a card. **Bold** terms mean what `runtime.sh terms` printed.

Your storage, written `<storage>` in the cards, is the folder on your brief's `Storage:` line: your output and `report.md` go there, because that is where your parent looks. Only without that line is it what `runtime.sh storage` prints. The two can differ: under some runtimes `runtime.sh storage` is your own thread's storage, which the script uses for state it keeps about you (a Reviewer's council log and markers), so leave that to the script and don't write your output there. The one exception is a Reviewer's member briefs, which go in the folder its Council block names.

## Your job

Your card, `<role>.md` next to this file, defines one job; read it first. If no brief named a role but the work matches one, say `Using role card: <role> — <why>` and follow it. The card's sections are your steps, in order: check what it Consumes, follow its Method, test yourself against "Done when", and write what it Produces, to the file the card or brief names, else `<storage>/<role>.md`. Then report and stop. You may always write to **storage**, even when the card says "Can edit: nothing"; with no write tools, the output goes in your report.

Before starting, check the model and effort on your `Running on` line and the inputs you need. Report BLOCKED when an input is missing or contradicts another, access is denied, or the assignment is below your card's with no reason in Constraints such as `budget: tight` (say "needs stronger model"). Your inputs are the source of truth, so never work around a blocker.

With a parent, you answer only to it (SKILL.md, Parents and workers); with none, you answer to the user and ask them when you're blocked. Load only the skills your brief names.

A fix round covers only the findings it names, by id. Anything else you notice, even a one-line fix, goes under Open; fixing it is scope creep and gets reverted.

## Turn ends

End a turn only with the report, an answer to your parent, or `HANDOFF` (SKILL.md, Parents and workers). Wait for long checks (tests, CI, a browser run) inside the turn, in the foreground or a shell loop, never with a **wake tool**, since each firing ends your turn. Fold messages that arrive while you work into the job and answer them once, in the report.

## Scope

Do the job your card names, and edit only where both the brief's `Scope:` and the card's `Can edit:` allow. Anything else you find (an API to design, a bug in another slice) goes under Open as `needs <role> — <why>` or `outside scope — <what>`, not into your diff.

Commit and push only on the brief's `Branch:` line. Rename a runtime-generated **auto branch** to it before the first push, and never push the generated name; if the line is `none` or missing and you need to push, report BLOCKED. You may open a draft PR for your work and link it under Output; marking it ready, merging, or anything else needs the brief to say so.

## Reading

Read only what you need: start from your inputs' pointers, search before reading, read by line range, and trim logs and test output to the failures and the summary.

## Handoff

If the job outgrows the brief, keep `<storage>/handoff.md` current at natural breaks and keep going. Only when it can't be finished in this session, or your parent asks, finish the note in this shape, report `HANDOFF`, and stop. Coordinators write the same note when the user says "handoff".

```
# Handoff — <task>
Goal:          <what done means>
Decisions:     <decision — reason>, one per line; do not revisit
Current state: <what works, what is verified, what is not>
Next steps:    <ordered list>
Pointers:      <file paths, worker links, spec — never file contents>
```

## Roles

[architect](architect.md) · [designer](designer.md) · [implementer](implementer.md) · [tester](tester.md) · [Reviewer](reviewer.md) · [council member](council-member.md) · [explorer](explorer.md) · [researcher](researcher.md) · [prototyper](prototyper.md). New card → copy [_template.md](_template.md).
