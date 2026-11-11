# Harnesses

## Detect

Read the environment with one shell call (`echo "$BB_THREAD_ID"`): set → bb; otherwise → none.

bb runs Claude Code or Codex inside it; the bb column names both where they differ. This skill reads bb threads and writes bb memory, so it runs only under bb.

## Glossary

| Term | bb | none |
|---|---|---|
| data | `~/.bb/dreaming` (`$DREAMING_HOME` overrides; the scripts read it too) | unsupported |
| run script | `python3 -I <skill>/scripts/<script> <args>` from any directory; `<skill>` = this skill's folder; needs `bb` on PATH | unsupported |
| run id | today's date in `Asia/Jakarta` (`TZ=Asia/Jakarta date +%F`); deep sleep `deep-<date>` | unsupported |
| me | `$BB_THREAD_ID` | unsupported |
| spawn scanner | `WORKFLOW_SPAWN=1 bb thread spawn --project proj_personal --parent-self --lifecycle-owner-thread "$BB_THREAD_ID" --provider claude-code --model <config.scannerModel> --reasoning-level low --title "<title>" --prompt-file <file> --json` (`WORKFLOW_SPAWN=1` passes the workflow spawn guard; these are helper threads, not workers). For a project-environment check: `--project <id>` instead | unsupported |
| wait | `bb thread wait <id>` | unsupported |
| thread status | `bb thread show <id> --json` → `.thread.status` (`active` = running) | unsupported |
| thread search | `bb thread search "<2–3 distinctive terms>" --limit 50 --json` | unsupported |
| thread context | `bb thread log <id> --message <seq> --context 3` | unsupported |
| thread link | `@thread:<id>#msg=<seq>` | unsupported |
| memory read | `bb memory get <id or name> --json` (global); prefix `BB_PROJECT_ID=<id>` for a project memory; `bb memory history <id> --json` for past versions | unsupported |
| file link | Markdown link to the absolute path, e.g. `[logs/<run>.md](/Users/<you>/.bb/dreaming/logs/<run>.md)` | unsupported |

Memory writes never use the bb CLI directly: always `memory.py write` / `undo`, which journal them. Project scope works from any thread through `--project <id>` (the script sets `BB_PROJECT_ID`).

## Models

`config.json` holds the model ids; bb rejects short aliases, so use full ids.

| Role | Default | Effort |
|---|---|---|
| Judge (the automation's thread) | `claude-opus-5-5` | medium |
| Scanner and project-check helpers | `claude-haiku-5-5` (`config.scannerModel`) | low |

## Automations

Project Personal (`proj_personal`). Re-run one: `bb automation run <id> --project proj_personal`.

| Job | Id | Schedule | Prompt must name |
|---|---|---|---|
| Nightly run | `auto_9ryg_5siyo8` | daily 03:00 Asia/Jakarta | the `dreaming` skill and "nightly run" |
| Weekly deep sleep | `auto_ice5ecfcskc` | Sun 04:00 Asia/Jakarta | the `dreaming` skill and "weekly deep sleep" |

Both: provider `claude-code`, model `claude-opus-5-5`, reasoning `medium`.
