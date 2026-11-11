---
name: dreaming
description: "Consolidate thread history into durable agent memory (\"dreaming\") and keep the memory store tidy. Use to run the nightly run or weekly deep sleep, re-run a failed one, undo or correct what a dream changed (e.g. \"revert dream 2026-11-04 #3\", \"#2 is wrong because …\"), apply proposals when dreaming is in propose mode, or tune what dreams keep."
metadata:
  version: "1.0.0"
  related: ""
---

# Dreaming

Scanner helpers read every new thread message since a saved cursor; the judge (you) turns them into memory writes each night; a weekly deep sleep audits and organizes the whole store. Memory is yours to manage: you write, audit and correct it; the user reads reports and points out problems.

## Harness

At the start, detect your harness with [harnesses.md § Detect](references/harnesses.md#detect) and read its glossary column. These terms mean exactly what that column says: **data** (`<data>` in paths) · **run script** · **run id** · **me** · **spawn scanner** · **wait** · **thread status** · **thread search** · **thread context** · **thread link** · **memory read** · **file link**. Unsupported → say so in one line and stop.

## Route

| Request | Read |
|---|---|
| Nightly run, or re-run a failed one | [references/nightly.md](references/nightly.md) (scanners get [references/scan.md](references/scan.md)) |
| Weekly deep sleep | [references/deep-sleep.md](references/deep-sleep.md) |
| Revert, correct ("#3 is wrong because …"), or apply/reject proposals from a log | [references/apply.md](references/apply.md) |
| Review a run | Show `<data>/logs/<run>.md`; change nothing |
| Tune | Edit this skill's files only when the user asks; record why in the commit |

## Data

Code lives here; data lives in `<data>`, never in this folder or a repo.

| Path | What |
|---|---|
| `config.json` | `mode`, models, guard and deep-sleep numbers; missing keys take the defaults in `scripts/dream.py` |
| `state.json` | read cursor (`cursorMs`, `lastSeq`), dream threads to skip, memory count and per-run write counts |
| `journal.jsonl` | every memory write: intent (with the memory as it was) → done / failed / uncertain |
| `backlog.json` | decisions waiting for evidence: unsure, failed, or deferred by the guard |
| `logs/<run>.json`, `.md` | proposals with status, op id and memory id; the report |
| `logs/<run>-rejected.md` | what the user rejected or corrected, with the reason; every run reads these |
| `batches/<run>/` | batches, candidates, memory dump, lock |

## Rules

- **Every memory write goes through the journal**: **run script** `memory.py write --op <run>:<n>:<action>:<name> [--project <id>] -- add|update|forget …` (undo: `memory.py undo`). Op ids come from the decision, never the time, so a replay skips what is done.
- **Recover before writing**: `memory.py pending`; for each op, `memory.py check --op …`, then `resolve --status done|failed --note "<what you saw>"`. One you can't settle → make no memory writes this run and report it first.
- **Modes**: `config.mode` = `apply` (default) writes memory; `propose` (emergency brake) writes logs only. Only the user changes it.
- **Self-tuning**: deep sleep may change numbers in `config.json` (guard thresholds, unused age), saying so in its report. Edits to this skill's files are suggestions for the user.
- **Idempotent**: every step is safe to repeat. `dream.py` advances the read cursor only in `commit`, after the log exists. Write every file to `<path>.tmp` and `mv` it into place.
- **Never** pin, edit or forget a pinned memory (suggest it in the report), or store secrets, customer or personal data, or task status.
- Spawn only the helper threads the references describe.
