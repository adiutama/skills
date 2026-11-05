# deep-sleep

Apply the day files written since your last run to the memory store, then tidy the whole store. Never read threads or thread logs: the day files are your only evidence about the user's work. You write memory directly, so every write goes through the journal and stays within the limits below.

## 1. What's new

- Read `<home>/deep-sleep/state.json` (missing → `through` is the day before the oldest day file) and `<home>/deep-sleep/backlog.md` if it exists.
- New days = day files in `<home>/days/` dated after `through`. No new days and an empty backlog → reply only "Nothing new since <through>." and stop; read nothing else.
- Read those day files, and **run script** `collect-day.py keys --home <home>` for how many days each key has been seen.
- The run id is `<newest new day>` (or `backlog-<today>` with no new days). A rerun after a crash gets the same id.
- **Recover first:** **run script** `memory.py pending --journal <home>/deep-sleep/journal.jsonl`. It lists ops that crashed mid-write or ended uncertain. For each, **run script** `memory.py check --journal … --op <op>`: it shows the memory before and now (an add is looked up by scope and name) with a hint. Decide whether the change happened, then **run script** `memory.py resolve --journal … --op <op> --status done|failed --note "<what you saw>"`. Can't tell → leave it unresolved, stop, and report it: don't decide anything new while an op is unresolved. Ops already done with this run id are applied; don't decide them again.

## 2. The store, once

**run script** `memory.py dump`: every memory in full, with its id and version. Don't fetch memories one by one.

## 3. Decide

From the new days and the backlog:
- **ADD** a memory when a key appears on 2+ days (the keys table's days seen), or when the user stated the rule explicitly.
- **UPDATE** a memory a signal contradicts or extends.

Across the whole store, only where it clearly helps:
- **MERGE** duplicates or overlaps, including between a project and global: update the survivor, then forget the rest.
- **MOVE** scope: a project rule that shows up in other projects goes global; a global rule only ever used in one project goes to that project. Add the new memory, then forget the old one.
- **RENAME** a misleading name the same way: add the new memory, then forget the old one.
- **SPLIT** an entry that holds two unrelated rules.
- **FORGET** a memory that is wrong, superseded, or a duplicate, and say which evidence shows it. Not being used is never enough on its own.
- Adjust **importance** for rules that keep coming up.

Limits:
- At most 10 writes per run. Pick the ones that matter most; the rest go to the backlog.
- Never edit `AGENTS.md`, skills, or any other file outside `<home>`. A rule that should always apply goes under "Promote" in the report, with the target file and the text to add.
- When unsure, don't write. Put it in the backlog with one line on what evidence would settle it. Drop a backlog item after it has waited 4 runs with no new evidence, and say so in the report.

## 4. Apply

Every write goes through **run script** `memory.py write --journal <home>/deep-sleep/journal.jsonl --op <run id>:<n>:<action>:<memory name> [--project <id>] -- <add|update|forget …>`.
- The op id must come out the same if this run is replayed, so build it from the decision, not from the time. The script skips an op already done.
- Use `--project <id>` for project memories. Update and forget take `--expected-version` from the dump.
- A version conflict means the user changed that memory since the dump: don't retry; put it in the backlog with the new version noted.
- An "uncertain" result: check and resolve it now, as in §1. If you can't, stop writing, and finish §5 without advancing `through`.
- Never call the **memory CLI** to write directly; a write that isn't journaled can't be undone.

## 5. Record

In this order, so a crash at any step is replayed safely:

1. Write the report as a fixed record: `<home>/deep-sleep/<run id>.md`, or, if a crashed run already wrote that, `<run id>-recovery-<n>.md` with only what this run resolved and changed, starting with a link to the first report. Before you write it, the journal's done ops for this run id are its source of truth; list every one.

```
# Deep sleep <run id>
Days applied: <list>. Store: <before> → <after> memories (global <n>, <project> <n>, …).

## Changed
1. ADD global `answer-the-question-first` (mem_…) · seen 3 days · days/2026-11-03.md, …
   Undo: <memory CLI forget command>
2. FORGET project kai-platform `old-name` (mem_…) · superseded by mem_… · Undo: re-add from the journal entry.

## Promote
## Backlog
What carries over, and why.
## Skipped
Version conflicts, failed writes, and recovered ops from a crashed run, one line each.
```

2. Write `<home>/deep-sleep/backlog.md` (as mutable state): every decision not applied, each with its evidence and the day files it came from. An empty backlog is an empty file.
3. Write `<home>/deep-sleep/state.json` (as mutable state) with `through` = the newest day applied. A backlog-only run, or one that stopped on an unresolved op, keeps the old `through`. This comes last: a run that crashes before it is replayed with the same run id, and the journal skips the ops it already did.

## 6. Reply

The Changed list in one line per write, then the report link.
