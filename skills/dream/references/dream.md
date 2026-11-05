# dream

Read finished days of the user's work and record what they teach future agents. This job never writes memory: `deep-sleep` decides. Your day file is deep-sleep's only evidence, so record every signal, even weak ones.

## 1. Which days

**run script** `collect-day.py pending --home <home> --tz <tz>`. It prints the days to process, oldest first: up to 3 finished days with no day file yet, catching up from the oldest day file, so no day is lost after an outage. Empty output → reply only "Nothing to dream." and stop; read nothing else.

## 2. Context, once

- **run script** `collect-day.py keys --home <home>`: every signal key so far, with days seen and the latest evidence.
- **run script** `memory.py dump --summaries`: every memory as one line (id, version, name, summary). Use it only to mark each signal covered / contradicts / extends / new. Read a memory in full with the **memory CLI** only when its summary isn't enough to decide that.

## 3. Each day, oldest first

1. **run script** `collect-day.py digest <day> --tz <tz>`. It lists every prompt the user typed that day, grouped by thread, each after the tail of the agent message it answered. Messages from other threads, automation prompts, and briefs written by agents are already removed. "No activity." → write a day file with the header and `No activity.`, then go to the next day.
2. Find the signals. A signal is something the user corrected, complained about, rejected, repeated, or stated as a preference, or a hard-won fact about a repo, machine, or tool. Most prompts are plain instructions; skip those. The "agent before" line usually shows what the user is reacting to. Open a thread (the **thread link** command) only when a correction is still unclear after reading it, and read only the turns around it.
3. Give each signal a kebab-case key. Reuse an existing key when it's the same lesson; the count of days seen depends on it.
4. Write `<home>/days/<day>.md` (atomically), at most ~6K characters:

```
# Dream <day>
<n> threads with prompts · projects: <names>

## Signals
| key | scope | evidence (short quote · thread link) | memory |
|---|---|---|---|
| answer-the-question-first | global | "but you don't answer my question" · <thread link> | new |

## For deep sleep
At most 5 lines: things the table can't carry, such as a memory the agent plainly ignored, a likely duplicate, or a stale fact.
```

- **scope:** `global` for preferences that apply everywhere; `project <name> (<id>)` for repo or machine facts.
- **memory:** `new`, or `<id> covered`, `<id> contradicts`, `<id> extends`.
- Don't list the day's threads; the evidence column links the ones that matter.


## 4. Reply

One short paragraph per day: how many signals, and the 1–3 strongest, each with its key. Link the day file.
