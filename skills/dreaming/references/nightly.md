# Nightly run

You are the judge. Scanner helpers read the threads; you decide what becomes memory and write it. `$RUN` = the **run id** unless the prompt gives one. Every step is safe to re-run and skips work an earlier attempt finished.

## 1. Begin
**run script** `dream.py begin $RUN` → status JSON: `batches`, `scanned` per batch, `memoryDump`, `logWritten`, `committed`, `config`, `guard`. Exit 3 = another attempt is running: reply with that and stop.
- `committed`, `<data>/logs/$RUN.md` exists, and nothing is left `proposed` in `$RUN.json` (or `config.mode` = `propose`) → reply with that report and stop.
- Otherwise `logWritten` → go to §6.
- No batches → write `[]` to `$RUN.json`, then go to §6.

Then recover the journal as in the SKILL.md rules.

## 2. Scan
For each batch not yet `scanned`, fill [scan.md](scan.md) (`{BATCH}` = batch path, `{OUT}` = same folder, `candidates-NN.json`) into a prompt file and **spawn scanner** (title `dream-scan $RUN NN`), all in parallel. **wait** for each, then re-check with `dream.py status $RUN`. A batch still not scanned: retry once; if it fails again, stop without writing the log (the next attempt retries it) and reply with the error.

## 3. Load
- `memoryDump` empty → **run script** `memory.py dump --summaries > <dir>/memory.md.tmp && mv <dir>/memory.md.tmp <dir>/memory.md` (every scope, one call). Use **memory read** only for memories a candidate may duplicate or contradict.
- `<data>/backlog.json` (missing = `[]`), every `<data>/logs/*-rejected.md`, and proposals still `proposed` in earlier `logs/*.json` (skip `*superseded*`).

## 4. Judge
Merge candidates that describe the same thing across batches and with backlog items. For each decide **add**, **update** (existing id: merge in the new evidence, sharpen wording), **forget** (evidence shows it is now wrong), **backlog** (unsure: note what evidence would settle it), or **drop**. A backlog item without new evidence stays as it is (leave it out of the log). Write only what passes all of:
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
`<data>/logs/$RUN.json`, written last: its presence marks judging done, so it carries every outcome that must survive a crash. An array of items `{n, op, action, scope, projectId, id?, version?, name, summary, details, kind, tags, importance, reason, evidence, status}`, fields matching `memory.py write`, `op` = `$RUN:<n>:<action>:<name>`:
- `status: "proposed"`: a write.
- `status: "deferred"` (held by the bloat guard) or `"backlog"` (unsure; add `note`: what evidence would settle it): goes to the backlog, with `since` and `waited` carried from an existing backlog item (new: `since: $RUN`, `waited: 0`).
- `status: "dropped"` for a backlog item this run settled without a write, with the reason.

A backlog item is identified by scope + projectId + name; keep those fields as they are in `backlog.json`.

## 6. Commit and apply
1. **run script** `dream.py commit $RUN` (safe to repeat).
2. **run script** `dream.py reconcile $RUN`: gives items without an `op` (a legacy log, written before the journal) their op id, and marks every `proposed` item with no journal history that already took effect as `applied` (`reconciled: true`), in one save. Other statuses are kept. Safe to repeat.
3. `config.mode` = `apply`: each `proposed` item in log order (adds before the forgets they replace): **run script** `memory.py write --op <op> [--project <projectId>] -- <action> …` with its fields (`update`/`forget` pass `--expected-version` and `--reason`). A done op prints "already applied". A version conflict: re-read with **memory read**, re-merge, retry once with the same op. Exit 3 or `uncertain` → resolve it now (SKILL.md rules); if you can't, stop writing.
4. Set the `status` of every item still `proposed` from **run script** `memory.py history --run $RUN` (the journal is the truth): `applied` with `memoryId`, or `failed` with the error. Save the log.
5. **run script** `dream.py backlog $RUN`: rebuilds `backlog.json` from the log, keyed by scope + projectId + name: the log's `deferred`, `backlog` and `failed` items replace any with the same key; every other key in the log leaves the backlog. Safe to repeat.
6. **run script** `dream.py record $RUN --memories <store count after>`, then `dream.py release $RUN`. Delete `<data>/batches/` entries older than `config.keepBatchesDays`, except any whose `manifest.json` has `committed: false`.

## 7. Report
Write it to `<data>/logs/$RUN.md` and print the same text as the final reply; the user reads the run in the thread. Never shorten it.
1. **Problems** first (omit when none): scanner or write failures, unresolved journal ops, more than `config.forgetAlert` forgets, deferred adds (name each).
2. One line: threads, candidates, writes by action, mode (`propose` → "nothing applied").
3. A table of every written or proposed item: `#`, action, scope (project name or global), name, one-line summary, memory id, outcome, undo (`revert dream $RUN #n`). Bold borderline ones, with the reason under the table.
4. "Backlog": deferred and unsure items, one line each. "Dropped": the count plus up to 5 notable ones; "New evidence for open proposals", if any.
5. How to correct: `revert dream $RUN #n`, or say "#n is wrong because …". In `propose`: `apply dream $RUN, accept …; reject … (reason)`.
6. Last line: a **file link** to `logs/$RUN.md`.
