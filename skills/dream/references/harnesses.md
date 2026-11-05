# Harnesses

## Detect

Read the environment with one shell call (`echo "$BB_THREAD_ID|$CLAUDECODE"`), then check top to bottom; the first match is your harness.

| Harness | Signal |
|---|---|
| bb | `BB_THREAD_ID` is set |
| Claude Code | `CLAUDECODE=1` |
| Codex | you are Codex (your system prompt or tool list says so) |
| none | no match |

bb runs Claude Code or Codex inside it; the bb column names both where they differ.

## Glossary

Each term means what your harness's column says, everywhere in this skill. This skill reads bb threads and writes bb memory, so it runs only under bb.

| Term | Meaning | bb | Claude Code | Codex | none |
|---|---|---|---|---|---|
| home | directory for all dream state, outside any repo | `~/.agents/dream` | unsupported | unsupported | unsupported |
| run script | how to run one of this skill's scripts | `python3 -I <skill folder>/scripts/<script> <args>` from any directory (needs the `bb` CLI on PATH) | unsupported | unsupported | unsupported |
| memory CLI | read or write one memory by hand | `bb memory get <id> --json`; for a project memory prefix `BB_PROJECT_ID=<project id>`. Undo an add: `bb memory forget <id> --expected-version <v> --reason "<why>"` | unsupported | unsupported | unsupported |
| thread link | how to cite a thread, and how to read the turns around a prompt | cite `@thread:<id>`; read `bb thread log <id> --format minimal --limit <n>` (n = user turns, newest last) | unsupported | unsupported | unsupported |

## Setup

Two bb agent automations in any one project (both read every project). `dream` runs daily after midnight; `deep-sleep` runs after it, daily or weekly. The prompts start with `Role:` so the job loads this skill only, not the workflow skill.

| Job | Prompt | Tier · effort |
|---|---|---|
| Dream | `Role: dream job. Load only the dream skill and run: dream --tz Asia/Jakarta` | balanced · medium (Claude Sonnet; the scripts already did the reading) |
| Dream: deep sleep | `Role: deep sleep job. Load only the dream skill and run: deep-sleep --tz Asia/Jakarta` | deep · high (Claude Opus; it writes memory) |

```sh
bb automation create --project <id> --name "Dream" --cron "0 3 * * *" --timezone Asia/Jakarta \
  --prompt "Role: dream job. Load only the dream skill and run: dream --tz Asia/Jakarta" \
  --provider claude-code --model claude-sonnet-5-5 --reasoning medium
bb automation create --project <id> --name "Dream: deep sleep" --cron "0 4 * * 1" --timezone Asia/Jakarta \
  --prompt "Role: deep sleep job. Load only the dream skill and run: deep-sleep --tz Asia/Jakarta" \
  --provider claude-code --model claude-opus-5-5 --reasoning high
```

Replace `Asia/Jakarta` with your timezone.

## Moving from an older setup

Day files from an earlier dream setup can be reused: copy them to `<home>/days/<YYYY-MM-DD>.md`. Leave out test files. Set `<home>/deep-sleep/state.json` to `{"through": "<newest day already applied>"}` so deep sleep doesn't apply them again.
