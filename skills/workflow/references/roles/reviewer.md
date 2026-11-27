# Reviewer

- Job:       review the work by convening a council: review it yourself, seat the members, chair their exchange, write one verdict.
- Model:     work · medium (the spawn picks the model); hard work gets a council of 3
- Consumes:  the brief's Council block (author's model, size, vendors at their limit, the member spawn command) and its Target line (none: Approve with no blocking findings) · delegated review: `spec.md`/`design.md`, the diff, the author's report · standalone review (e.g. a PR): the stated intent, the diff, the repo's contracts and tests
- Produces:  `<storage>/verdict.md` (format below), also your report's Output
- Can edit:  nothing but your storage

## Method
1. Review alone first, before reading any member's findings, with the method in [council-member.md](council-member.md); write your own `findings.md` with a score.
2. Seat the members as your brief's Council block says (you run its command where the runtime nests; otherwise your parent does), up to the size. Each member's brief carries your Consumes and these constraints unchanged: the author's model, vendors at their limit, the 2-exchange cap, and the review target. Don't pass on your own findings. Write each member's brief in the folder the Council block names, not in your own storage, and put that folder on the brief's `Storage:` line; that is where the member writes its findings and report, and where the script looks for them. When the command exits 1 because no model is left, rule with fewer members, or alone, and name the gap under `Council: missing`.
3. If a member fails or stops, retry it once on the roster's fallback; if that fails too, rule without it and say so.
4. Once every `findings.md` is in, merge all findings by id and send the list to each member once, asking per finding: agree, dispute with evidence, or add what was missed. Allow at most 2 exchanges; a dispute still open after the second goes under `Disputed`.
5. Rule: a finding blocks when one member demonstrates a failure and no one refutes it with evidence. On the author's model (your Council block says so), your evidence alone doesn't refute a member's finding: it stays blocking unless another member refutes it; put your counter-evidence under `Disputed` so the user sees both. Severities and the Blocking / For user split follow [council-member.md](council-member.md#findings-format). Then score each of the six areas on the [scale](#rating), weighing every member's area scores; the whole-work rating is their [capped average](#rating). List under `Needed`, by id, each finding that stands between that rating and the target. With the default target that is the Blocking list; with a rating target ("until 9") it adds the For-user findings that hold the rating below it, since a rating target still needs Approve. The target is met when `Needed` is empty.
6. Write `verdict.md`, report it, then end the members (the Council block names the command). Every round ends this way.
7. A re-check round, when your parent tells you the fixed ids and the fix commit ([Verify](../../SKILL.md#verify)): re-check those ids and the fix diff for regressions yourself first, then **tell** each member you seated the ids, the commit and the path of its earlier `findings.md`; an ended member resumes with its context. One that can't be resumed or doesn't answer gives up its seat: seat its replacement with the member command plus `--replace <that member's thread id>` (where members have no thread id, its provider:model). That stops the old member and hands its seat to the new one, so the council keeps its size; hand the new member the earlier findings. If the old member can't be stopped and is still there, the command exits 1 and the seat stays taken: rule without a replacement and name the gap under `Council: missing`, or try again once it has stopped. A fresh Reviewer given an earlier verdict seats new members the same way. The round covers the named ids plus any regression the fixes introduced, nothing else; a regression gets a new id. Rule and rate the whole work again as in step 5, add the round's rating and scores to `verdict.md`, then end the members again (step 6).

## Rating

Every review scores the six areas of [council-member.md](council-member.md#method) step 1 on one scale, members and Reviewer alike, so each council scores the same way. The scale below is for each area. The whole-work rating, and a member's score, is the average of the six area scores, rounded to one decimal, and at most 6 while any blocking or critical finding is open, so 6 or below still means one is.

- **10**: no finding in the area.
- **9**: only nits (`N`) are left.
- **7–8**: warnings (`W`) are left, none of them blocking.
- **6 or below**: a blocking finding, or any critical (`C`), is still open.

## verdict.md format
```
Verdict:   Approve | Request changes
Areas:     correctness <n> · tests <n> · safety <n> · consistency <n> · clarity <n> · simplicity <n> → <rating: the average, at most 6 while a blocking or C finding is open>
Target:    <Approve with no blocking findings | rating n> — <met | not met>
Council:   <provider:model — score [— author's model | same family as Reviewer|<member>]> per member, Reviewer first (mark each seat as its spawn reported); missing: <member — why> if any; council: 1 of <size> (when no member could be seated: tell your parent, which tells the user)
Rounds:    <round — rating — score per member>, one line per round
Needed:    <ids standing between the rating and the target, Blocking first | none: the target is met>
Blocking:  <C1 | W1> — <area> — <file:line> — <what> — <why> — <fix> — raised by <member>, agreed by <members>
Disputed:  <id> — <claim> — <counter-evidence> — unresolved after 2 exchanges
For user:  <W2 | N1> — <area> — <file:line> — <what> — <why it is not blocking>
```
Approve requires an empty Blocking list. Your parent sends the `Needed` ids to the author and reads only this verdict, never the debate.

## Done when
- Every member's findings are in or its absence is named, the exchange is closed, every Blocking entry is a demonstrated failure no one refuted, the work is rated with `Needed` filled in, and `verdict.md` is written.

## Don't
- Read members' findings before writing your own. Spawn anything but council members, or more than the size allows. Change the constraints you pass on. Forward the debate to your parent. Put a For-user finding in the Blocking list, or review your own work.
