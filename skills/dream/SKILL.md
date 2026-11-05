---
name: dream
description: Turn the user's past days of work into durable agent memory, in two scheduled jobs. `dream` reads one finished day of the user's prompts across all threads and records signals (corrections, preferences, hard-won facts) in a day file. `deep-sleep` never reads threads; it reads the day files since its last run plus the whole memory store and applies changes to memory, journaled so each can be undone. Use when a scheduled job or the user asks to dream, run deep sleep, or reflect past work into memory.
argument-hint: '[dream | deep-sleep] [--tz <Area/City>]'
metadata:
  version: "1.0.0"
  related: ""
---

## Harness

At the start, detect your harness with [harnesses.md § Detect](references/harnesses.md#detect), then read its glossary column. These terms mean exactly what that column says, everywhere in this skill: **home** (`<home>` in paths) · **run script** · **memory CLI** · **thread link**. A harness whose column says unsupported → say so in one line and stop.

## Route

- No action, or `dream` → read [references/dream.md](references/dream.md) and follow it. Read nothing else from this skill.
- `deep-sleep` → read [references/deep-sleep.md](references/deep-sleep.md) and follow it. Read nothing else from this skill.
- `--tz <Area/City>` sets the timezone that defines a calendar day (default: the machine's). Pass the same value to every script call.

Each job loads only its own file, so neither pays for the other's instructions.

## Files

All state lives in `<home>`, never in a repo:

| Path | Written by | Read by | What |
|---|---|---|---|
| `days/<YYYY-MM-DD>.md` | dream | dream, deep-sleep | signals for one day; its existence marks the day done. Signal keys are counted from these files (`collect-day.py keys`), so there is no separate registry to fall out of sync |
| `deep-sleep/<run id>.md` | deep-sleep | the user | what was changed and why, with undo |
| `deep-sleep/journal.jsonl` | `memory.py` | deep-sleep, the user | every memory write with its op id: intent (with the memory as it was) before, then done, failed, or uncertain |
| `deep-sleep/backlog.md` | deep-sleep | deep-sleep | decisions not applied yet (over the write limit, failed, unsure), carried to the next run |
| `deep-sleep/state.json` | deep-sleep | deep-sleep | `{"through": "<YYYY-MM-DD>"}`: the last day file already applied |

## Rules (both jobs)

- **Scripts do the plumbing.** Gather data only with `scripts/collect-day.py` and `scripts/memory.py` through **run script**. Never page through threads or memories by hand; if a script fails, report its error and stop.
- **Write files atomically**, through a temp file next to the target named `<file>.tmp.<pid>`:
  - **Fixed records** (day files, deep-sleep reports): `mv -n <tmp> <file>`, then `rm -f <tmp>`. If `<file>` already existed, another run won: leave it and say so.
  - **Mutable state** (`backlog.md`, `state.json`): `mv -f <tmp> <file>`, which replaces it in one step.
  - A leftover `*.tmp.*` is from a crashed run: delete it.
- **Reports are a fixed record.** If the user continues in the job's thread afterwards (asking questions, applying something by hand), do that work but never edit a day file or deep-sleep report already written. The next dream run reads that conversation like any other thread.
- **Never store** secrets, guesses, transient status, or one-off task details.
- **Stay in scope.** Do not spawn or message other threads, and do not touch any repository.
