# Delegation

Read when [SKILL.md §3](../SKILL.md) says delegate. Glossary terms in **bold** are your harness's; "templates" is [templates.md](../templates.md).

## Roles

| Role | Job | Never | Tier · effort |
|---|---|---|---|
| Manager (top-level, no brief) | talk to the user, classify, create Leads, board across Leads | real work; touching a Lead's specialists | deep · medium |
| Lead (`Role: Lead`, loads this skill) | plan one piece of work, assign roles, collect reports, verify; edits only its ledger, briefs, and role artifacts it produces itself | bulk work | deep · medium |
| Specialist (`Role: <specialty>`) | one job, per the `specialist` skill if installed, else the brief | spawning workers | below |

| Specialist | Tier · effort | Consumes → Produces |
|---|---|---|
| Explorer | fast · low | question → pointers |
| Researcher | balanced · medium | question → sourced summary |
| Prototyper | balanced · medium | risky question → GO / NO-GO |
| Architect | deep · high | goal → `spec.md` (interfaces, slices, checkable acceptance criteria) |
| Designer | deep · medium | goal, spec → `design.md` |
| Implementer | fast · low, or balanced · medium for judgment | spec + slice → diff |
| Tester | fast · low, or balanced · medium for tricky tests | acceptance criteria + diff → PASS / FAIL |
| Reviewer | deep · medium (high if high stakes) | spec + diff → Approve / Request changes, findings `C`/`W`/`N` |

- Trivial → the Manager answers. Single-role job → the Manager spawns one specialist. 2+ roles or multi-step → a Lead. No **nesting** → the Manager also plays Lead, with a separate Lead section in its ledger.
- **Approval.** The user approves plans, not spawns: the Lead plan (templates §4) once, via the Manager. Outside the plan (extra role, higher tier, consultant, > 4 parallel) → back to the user. A single specialist: show the classification block and wait. A user asking for a spawn approves the spawn, not its tier and effort — still show the Plan line first.
- **PRs.** Any agent may open a draft PR for its work; ready-for-review or merge only as instructed (user → Manager → brief).
- **Skills.** Every agent uses installed skills that fit its work. Skills only the user may invoke (manual verification, evidence, PR review) are never run by agents; see **Verify by hand**.

## Plan and gates

Map dependencies first; build from the base up (templates §4). Layer 0 = the spec: data model and interfaces, no running code. Shared code that runs is the first implementation layer. Order follows dependencies, never ease; parallel only within a layer; a base change → re-check dependents.

- **L0 DONE** when the Lead confirms the spec names every interface, every slice with its dependencies, and acceptance criteria a Tester can check without asking.
- **Implementation layer DONE** when its Tester reports PASS. The next layer starts only then.
- **Work DONE** after one Reviewer pass over the whole diff returns Approve. High stakes: the Lead may add a Reviewer on a base layer many slices depend on.
- **Feedback loop** (Tester / Reviewer → Implementer): max 2 rounds, then the Lead decides — fix the spec, a stronger tier, or escalate. Wrong spec → specialist reports BLOCKED → back to the Architect, re-check dependents.
- `Fit: MISMATCH` without a `budget:` constraint → re-spawn one tier up (outside the plan → back to the user). `Open: needs <role>` → add that role to the map.

## Spawning

Every **spawn** gets a brief (templates §2: variant A if **specialist installed**, else B) with **permission** as your harness says. Before spawning, create `<storage>/workers/<role>-<slice>/` and put its absolute path in the brief's `Storage:`. Mind the **spawn cost**. Parallel workers without **isolation** share one working directory: parallelize only disjoint writes.

## Messages — one level at a time

- Nobody skips a level; only the Manager talks to the user. Specialists never ask the user; they report `BLOCKED` with question, options, and default.
- Lead: **wait** on specialists within one turn, then **read** their reports; end the turn only for a milestone or blocker.
- Lead answers blockers from spec, ledger, or judgment via **tell** (no **tell** → re-spawn with the answer in the brief); otherwise asks the Manager, who answers or asks the user.
- Manager → user: the board (templates §8) and decisions only the user can make; rows use the worker's **link**.
- A worker the user steps into reports the user's changes to its parent.

## Verify by hand

When work is DONE and needs checking by a person, the Manager posts a **Verify** milestone to the user: what to check, and the exact commands to run. Name the user's own skills when installed (setting up a disposable environment for the case, capturing evidence, reviewing the PR), with arguments filled in — worktree path, case, URLs. Agents never run those skills; the user runs them and reports back.
