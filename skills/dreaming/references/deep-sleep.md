# Weekly deep sleep

You audit the past week's writes and organize the whole memory store: merge, split, tighten, rescope, and forget what is wrong, stale or unused. The input is the store, the journal and the week's logs, not thread transcripts. `$RUN` = `deep-<date>` from the **run id**. Every step is safe to re-run.

## 1. Begin
**run script** `dream.py lock $RUN` → status JSON (`memoryDump`, `logWritten`, `config`, `guard`). Exit 3 = another attempt is running: stop. `logWritten` → go to §6. Then recover the journal as in the SKILL.md rules.

## 2. Load
- `memoryDump` empty → **run script** `memory.py dump > <dir>/memory.md.tmp && mv <dir>/memory.md.tmp <dir>/memory.md`: every memory in full (id, version, created, pinned), every scope, one call.
- The last 7 days: `logs/*.json` and `.md`, every `*-rejected.md`, `memory.py history --since <date 7 days ago>`, and `state.json` `runs` (memory count and writes per run).
- `<data>/backlog.json`.

## 3. Decide
Every unpinned memory gets at most one of these; the rest are left alone.
- **Audit**: each write journaled this week (skip `:undo` ops and ones the user already corrected) is checked against the nightly bar ([nightly.md](nightly.md) §4) and the store. Wrong, duplicate, mis-scoped or vague → correct it with the matching action below.
- **Merge**: two or more say the same thing, or one is a special case of another → **update** the best-named one with the merged text, **forget** the rest.
- **Split**: one memory holds unrelated rules, or details that would be retrieved separately → **update** it to one topic, **add** one per other topic (same scope, narrower tags). Never split one procedure's steps.
- **Unused**: created ≥ `config.unusedMinAgeDays` days ago, and **thread search** with 2–3 distinctive terms finds no thread updated in the last `config.unusedWeeks` weeks that mentions its subject → **forget**. Facts and procedures about dropped tools, repos or features qualify. Standing preferences and guardrails (never/always rules) are used by being obeyed: forget them only when superseded.
- **Stale**: project facts naming paths, commands, scripts or config. For each such project, **spawn scanner** with `--project <id>` (title `dream-check $RUN <id>`) with the list to check, asking for one line per item: exists / gone. Gone → **forget** or **update**.
- **Contradiction**: keep the better-evidenced one; open sources with **thread context** only when that is unclear.
- **Tighten**: vague, too long, or details repeating the summary → **update**.
- **Rescope**: a global memory naming a project, channel or repo → **add** in that project, **forget** the global one. A project rule seen in other projects → **add** global, **forget** the project ones.
- **Rename**: a misleading name → **add** under the new name, **forget** the old.
- **Importance**: raise rules that keep coming up, lower ones that never do → **update**.
- **Backlog**: an item with evidence this week from a thread it didn't have → decide it now (the bloat guard's exemption applies). `deferred` adds never expire: they wait for that evidence, and leave only when decided or invalidated (superseded, contradicted, or rejected by the user → `dropped` with the reason). `backlog` (unsure) and `failed` items: `waited` + 1 per deep sleep without new evidence; at `config.backlogMaxRuns` → `dropped`, listed with full text.

Never edit pinned memories, AGENTS.md or this skill: those go to "Needs you".

**Self-tuning**: change numbers in `config.json` when the week shows they are off (adds deferred every night that the audit found good → raise `addsPerRun`; a store past `memoryLimit` that the organizing can't shrink → say so rather than raise it). At most two keys per week, never `mode`; write via `.tmp` + `mv`, keeping other keys.

## 4. Write the log
`<data>/logs/$RUN.json`, as in [nightly.md](nightly.md) §5, plus `why` per item (audit, merge, split, unused, stale, contradiction, tighten, rescope, rename, importance, backlog) and, for unused, the search that showed it. Every backlog item whose `waited` changed or that was decided or dropped is in the log with its new status and `waited`, so `dream.py backlog` in §6 replays safely; a `failed` item kept in the backlog stays `failed`.

## 5. Needs you
Collect for the report, each item one line: pinned-memory changes; rules that belong in an AGENTS.md (target file + text to add); procedures grown large or spread over many memories that should become a skill; edits to this skill's files suggested by the week's rejections and dropped lists. Keep it short; omit empty groups.

## 6. Apply
As [nightly.md](nightly.md) §6 steps 2–6, without `commit` (deep sleep moves no cursor): adds before the forgets they replace.

## 7. Report
As [nightly.md](nightly.md) §7, with a `why` column, the memory count before → after, any week's run that forgot more than `config.forgetAlert` under Problems, config changes (old → new, why), and "Needs you" last before the link. A forget is undone with `revert dream $RUN #n`: it re-adds the memory from the journal under a new id.
