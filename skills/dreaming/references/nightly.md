# Nightly run

You are the judge. Scanner helpers read the threads; you decide what becomes memory and write it. `$RUN` = the **run id** unless the prompt gives one. Every step is safe to re-run and skips work an earlier attempt finished.

## 1. Begin
**run script** `dream.py begin $RUN` → status JSON: `batches`, `scanned` per batch, `memoryDump`, `logWritten`, `committed`, `config`, `guard`. Exit 3 = another attempt is running: reply with that and stop.
- `committed`, and nothing left `proposed` in `<data>/logs/$RUN.json` (or `config.mode` = `propose`) → reply with the report (§8) and stop.
- Otherwise `logWritten` → go to §7.
- No batches → write `[]` to `$RUN.json`, then go to §7.

Then recover the journal as in the SKILL.md rules.

## 2. Scan
For each batch not yet `scanned`, fill [scan.md](scan.md) (`{BATCH}` = batch path, `{OUT}` = same folder, `candidates-NN.json`) into a prompt file and **spawn scanner** (title `dream-scan $RUN NN`), all in parallel. **wait** for each, then re-check with `dream.py status $RUN`. A batch still not scanned: retry once; if it fails again, stop without writing the log (the next attempt retries it) and reply with the error.

## 3. Load
- `memoryDump` empty → **run script** `memory.py dump --summaries > <dir>/memory.md.tmp && mv <dir>/memory.md.tmp <dir>/memory.md` (every scope, one call). Use **memory read** only for memories a candidate may duplicate or contradict.
- `<data>/backlog.json` (missing = `[]`), every `<data>/logs/*-rejected.md`, and proposals still `proposed` in earlier `logs/*.json` (skip `*superseded*`).

## 4. Judge
Merge candidates that describe the same thing across batches and with backlog items. For each decide **add**, **update** (existing id: merge in the new evidence, sharpen wording), **forget** (evidence shows it is now wrong), **backlog** (unsure: note what evidence would settle it), or **drop**. Write only what passes all of:
- Durable: still true next month; not task status or a one-off.
- Actionable: changes what a future agent does.
- Evidenced: a preference needs `explicit` strength or evidence from 2+ threads (a backlog item's threads count); a fact needs a confirmed outcome, not an assistant guess.
- New: not already in memory, AGENTS.md or a loaded skill.
- Safe: no secrets, tokens, customer or personal data.
- Scoped right: repo/tooling facts → project; only cross-repo user preferences → global.
- Not rejected: nothing a `*-rejected.md` entry rules out; learn from its reasons. An open `proposed` item gets "new evidence" noted instead of a duplicate.

Pinned memories: suggest the change in the report, never write. Importance 40–60 normally, 70 for explicit user rules. Names: lowercase kebab-case, unique.

**Bloat guard** (adds only): taking adds most important first, an add waits in the backlog (`deferred`) once adds this run reach `config.addsPerRun`, or the store count (dump count + adds − forgets this run) reaches `config.memoryLimit`. Exempt: an explicit "remember this", and a deferred backlog item that gained evidence from a thread it didn't have. Updates and forgets never wait.

## 5. Write the log
`<data>/logs/$RUN.json` (written last; its presence marks judging done): an array of proposals `{n, op, action, scope, projectId, id?, version?, name, summary, details, kind, tags, importance, reason, evidence, status: "proposed"}`, fields matching `memory.py write`; `op` = `$RUN:<n>:<action>:<name>`. Deferred and backlogged items are not proposals.

## 6. Backlog
Rewrite `<data>/backlog.json`: add new `deferred` and `unsure` items `{name, action, scope, projectId, id?, why, note, proposal, evidence, since, waited: 0}`; remove items this run turned into proposals or drops. Deep sleep ages and drops items.

## 7. Commit and apply
1. **run script** `dream.py commit $RUN` (safe to repeat).
2. `config.mode` = `apply`, in log order (adds before the forgets they replace): **run script** `memory.py write --op <op> [--project <projectId>] -- <action> …` with the proposal's fields (`update`/`forget` pass `--expected-version` and `--reason`). A done op prints "already applied". A version conflict: re-read with **memory read**, re-merge, retry once with the same op. Still failing → backlog it as `failed`. Exit 3 or `uncertain` → resolve it now (SKILL.md rules); if you can't, stop writing.
3. Set each proposal's `status` from **run script** `memory.py history --run $RUN` (the journal is the truth): `applied` with `memoryId`, or `failed` with the error. Save the JSON.
4. **run script** `dream.py record $RUN --memories <store count after>`, then `dream.py release $RUN`. Delete `<data>/batches/` entries older than `config.keepBatchesDays`, except any whose `manifest.json` has `committed: false`.

## 8. Report
Write it to `<data>/logs/$RUN.md` and print the same text as the final reply; the user reads the run in the thread.
1. One line: threads, candidates, writes by action, mode (`propose` → "nothing applied").
2. **Problems** (omit when none): scanner or write failures, unresolved journal ops, more than `config.forgetAlert` forgets, deferred adds (name each).
3. A table of every proposal: `#`, action, scope (project name or global), name, one-line summary, memory id, outcome. Bold borderline ones, with the reason under the table.
4. "Dropped": the count plus up to 5 notable ones, one line each; "New evidence for open proposals", if any.
5. How to correct: `revert dream $RUN #n`, or say "#n is wrong because …". In `propose`: `apply dream $RUN, accept …; reject … (reason)`.
6. Last line: a **file link** to `logs/$RUN.md`.

Over ~40 proposals: table the 40 most important and say how many more are in the log.
