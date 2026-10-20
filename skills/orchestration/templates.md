# Templates

## §1 Classification block

Before any work; again on reclassification.

```
Classification: DEEP · stakes HIGH
Why deep:    <the hard reasoning involved>
Why high:    <what breaks if wrong>
Plan:        <tier · model> · <effort> · <myself | specialist | new Lead>
Verify:      <steps from the ladder>
Escalate if: <the signal that would change this classification>
Context:     <🟢 62K measured | unknown>
```

Trivial: `Classification: TRIVIAL · fast tier · doing it directly`.

## §2 Brief

A self-contained file in the worker's `Storage:` directory, delivered per **spawn**. Always starts with `Role:`.

Variant A — **specialist installed**:
```
Role: <role>
Parent: <your link>
Storage: <absolute path you created for this worker>
Load the `specialist` skill and follow role card: <role>.

Goal:        <what done means>
Inputs:      <file paths: spec, design, handoff note, relevant code>
Scope:       <what you may touch; what you must not>
Constraints: <decisions already made, with reasons>
Running on:  <tier · model · effort you spawned it with>
```

Variant B — standalone: same, minus the "Load" line, plus the following, with the §6 and §7 blocks pasted in full (the worker can't read this file):
```
Your job:  <role row from delegation.md § Roles>
Rules:     talk only to your parent; never ask the user or spawn workers.
           Inputs are the source of truth: wrong or missing → BLOCKED.
           Use any installed skill that fits a step; the report format stays.
           PRs: draft only, unless this brief says otherwise.
           Start from the pointers in your inputs. Keep tool output small: read by line range,
           never print whole files or logs, trim test runs to failures and the summary.
Output:    write your artifact to <storage>/<role>.md unless Goal names a file (<storage> = the Storage path above);
           no write tools → put it in your final message.
Report:    end every turn with this, ≤ ~300 words:
           <§6 block, with the BLOCKED fields>
Context:   🔴 (> 250K tokens, or > 80 % of your window) → don't stop; finish and note "context 🔴" under Open.
           Can't finish here → write <storage>/handoff.md in this shape, report HANDOFF:
           <§7 block>
```

`Role: Lead`: `Role`, `Parent`, `Storage` + "Load the orchestration skill." + Goal, Inputs, Scope, Constraints, Running on + the approved plan + the owner (Lead link) of each contract it shares with other Leads.

## §3 Consultant brief

Shown to the user with its size for approval.

```
Question:   <one precise question>
Context:    <the problem in ≤ 10 lines>
Candidate:  <the proposed solution>
Excerpts:   <only the key code, ≤ ~200 lines>
Answer in:  ≤ 300 words — verdict, risks missed, what to change
```

## §4 Lead plan (user approves once, via the Manager)

```
Lead:       <goal, e.g. cost sheet accuracy> — after: <Lead, or —>
Classification: <block from §1>

Dependency map (base first; a layer starts when the one below is DONE):
  L0 base   spec.md (data model, interfaces, pointers)  Architect    deep · high      depends on: —           gate: Lead checks spec (delegation.md)
  L1        <slice> · <slice> · high (parallel, disjoint) Implementer  fast · low       depends on: L0          gate: criteria tests pass
            test L1 (only cross-slice or running-app)    Tester       fast · low       depends on: L1 slices   gate: PASS
  L2        <slice> (uses L1's API)                      Implementer  balanced · med   depends on: L1          gate: criteria tests pass
  Final     review the whole diff (fixed: one per Lead)  Reviewer     deep · medium*   depends on: L2          gate: Approve (fresh eyes, complementary)
  Base      only if L1 is a high-stakes shared base      Reviewer     deep · high      depends on: test L1
  * medium even when slices are high stakes; they are named as its focus
Expected:  <n> specialists = Architect + Implementers + Testers in the map + 1 Reviewer (+1 Base); max <n> parallel
Needs approval again if: extra role, higher tier, consultant, > 4 parallel
```

## §5 Ledger (`<storage>/ledger.md`, Manager and every Lead)

```
# Ledger — <Manager | Lead: name>
Goal: <what done means>
Updated: <time>

## Board
| Worker | Role | Tier · effort | Status | Last result |
|---|---|---|---|---|

## Decisions
- <decision> — because <reason> (<who decided>)

## Open
- <question or blocker> — waiting on <whom>

## Next
- <step>
```

## §6 Report contract (minimum fields; the `specialist` skill produces a superset)

<!-- contract:report — specialist/SKILL.md "Report" must contain every field here. -->
```
Status:  DONE | BLOCKED | HANDOFF | FAILED
Result:  <what was achieved>
Changed: <files>
Evidence: <tests run, output summary, how verified>
Open:    <issues, risks>
User corrections: <anything the user changed directly with this worker, or "none">
Details: <path to longer notes in your storage, if any>
```

BLOCKED adds:

```
Question: <one precise question>
Options:  A) <…>  B) <…>
Default:  <what I'll assume if there is no answer>
```

## §7 Handoff note (`<storage>/handoff.md`)

<!-- contract:handoff — identical to specialist/SKILL.md "Context". -->
```
# Handoff — <task>
Goal:          <what done means>
Decisions:     <decision — reason>, one per line; do not revisit
Current state: <what works, what is verified, what is not>
Next steps:    <ordered list>
Pointers:      <file paths, worker links, spec — never file contents>
```

## §8 Board (Manager → user)

On every milestone (delegation.md § Messages); one row per Lead or direct specialist.

```
| Lead / specialist | Goal | Status | Needs you? |
|---|---|---|---|
| <link> | auth migration | 🔄 2/3 implementers done | — |
| <link> | slow sync | ⛔ blocked | Keep old column for 1 release? (default: yes) |
```
