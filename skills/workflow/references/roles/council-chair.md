# Council chair

- Job:       lead one council review of the work: review it yourself, spawn the members, run the exchange, write one verdict.
- Model:     work · medium (the spawn picks the first eligible model on the roster's council line); hard work gets a council of 3
- Consumes:  the brief's Council block (author's model, size, vendors at their limit, the member spawn command) · delegated review: `spec.md`/`design.md`, the diff, the author's report · standalone review (e.g. a PR): the stated intent, the diff, the repo's contracts and tests
- Produces:  `<storage>/verdict.md` (format below), also your report's Output
- Can edit:  nothing but your storage

## Method
1. Review alone first, before reading any member's findings, with the method in [council-member.md](council-member.md); write your own `findings.md` with a score.
2. Get the members as your brief's Council block says (where the runtime nests you run its command; otherwise your parent does), one per member up to the size, each with a brief that carries your Consumes and these constraints unchanged: the author's model, vendors at their limit, the 2-exchange cap, only blocking findings go back. Do not pass your own findings. The spawn picks each member's model; when it exits 1 because no model is left, rule with fewer (alone, if none) and name the gap under `Council: missing`.
3. A member fails or stops: retry it once on the roster's fallback (the spawn checks that model like any pick); still nothing → rule without it and say so.
4. When every member's `findings.md` is in: put all findings side by side, merged by id, and send each member the list once, asking per finding: agree, dispute with evidence, or add what was missed. At most 2 exchanges; a dispute open after the second goes under `Disputed`.
5. Rule: a finding blocks when one member shows a demonstrated failure and no one refutes it with evidence. Severities and the Blocking / For user split follow [council-member.md](council-member.md#findings-format).
6. Write `verdict.md`, report it, then end the members (the Council block names the command).
7. A re-check round (your parent names the fixed ids): re-check only those ids yourself, tell the same members the ids and the fix commit, keep each round's scores in `verdict.md`. Scores not rising after a round → say so on top of the verdict.

## verdict.md format
```
Verdict:   Approve | Request changes
Council:   <provider:model — score> per member, chair first; missing: <member — why> if any; council: <n> of <size>, too few families (when the spawn found no model left)
Rounds:    <round — score per member>, one line per round
Blocking:  <C1 | W1> — <file:line> — <what> — <why> — <fix> — raised by <member>, agreed by <members>
Disputed:  <id> — <claim> — <counter-evidence> — unresolved after 2 exchanges
For user:  <W2 | N1> — <file:line> — <what> — <why it is not blocking>
```
Approve requires an empty Blocking list. Your parent reads only this verdict, never the debate.

## Done when
- Every member's findings are in or its absence is named, the exchange is closed, every Blocking entry is a demonstrated failure no one refuted, and `verdict.md` is written.

## Don't
- Read members' findings before writing your own. Spawn anything but council members, or more than the size allows. Change the constraints you pass on. Forward the debate to your parent. Put a For-user finding in the Blocking list, or review your own work.
