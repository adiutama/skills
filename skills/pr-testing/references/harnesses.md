# harness.sh

`scripts/harness.sh` is this skill's harness layer. Each term is a subcommand: under bb it performs the action. Elsewhere it runs the honest fallback, or prints the exact tool call to make. Run it; never translate a term yourself.

## Detect

The script checks top to bottom; the first match wins.

| Harness | Signal |
|---|---|
| override | `PR_TESTING_HARNESS` is set (Codex sets no variable: export `PR_TESTING_HARNESS=codex`) |
| bb | `BB_THREAD_ID` is set |
| Claude Code | `CLAUDECODE=1` |
| none | no match |

bb runs Claude Code or Codex inside it; the bb column names both where they differ.

## Glossary

`harness.sh terms` prints the column for your harness.

| Term | bb | Claude Code | Codex | none |
|---|---|---|---|---|
| storage | `$BB_THREAD_STORAGE` | `~/.agents/pr-testing/<session id>` | `~/.agents/pr-testing/<PR_TESTING_SESSION>` | as Codex |
| invoke | `/pr-testing` under Claude Code · `$pr-testing` under Codex | `/pr-testing` | `$pr-testing` | the skill's name |
| notify | dashboard buttons wake this thread (`bb thread tell --mode auto`) | none: save + copy text; "check the dashboard" → `inbox` | as Claude Code | as Claude Code |
| implementer | child thread in a new worktree; its turn end wakes you | subagent with `isolation: "worktree"` | subagent; its brief makes it create its own git worktree | none: hand the user the brief for a new session |
| process | environment terminal in Terminal Hub | detached `nohup`, log, PID | as Claude Code | as Claude Code |
| share | BB Connect when paired and on, else local URL | local URL | local URL | local URL |
| secret | the secrets skill writes a dotenv file you never read | the user writes the file you name | as Claude Code | as Claude Code |
| link | `@thread:<id>` | agent ID | agent ID | main |

## Commands

```
harness.sh terms | features | storage | invoke | notify-target
harness.sh run --title T --log FILE --cwd DIR -- CMD...      → "handle <id>" and "log <file>"
harness.sh stop-run <handle>
harness.sh share <port>                                      → "remote <url>" or "local <url>  (reason)"
harness.sh unshare <port>
harness.sh spawn-implementer --brief FILE --title T [--model M] [--effort E]
harness.sh tell <id> -                                        message on stdin
```

- **features** prints `notify=yes|no`, `implementer=thread-worktree|subagent-worktree|subagent-own-worktree|none`, `process=terminal|detached`, `share=remote|local`, and `secret=secure-prompt|user-file`. Base every promise to the user on these values.
- **run** hands the command to `/bin/sh` (the user's login shell may be fish or alias `cd`). The output is appended to the log. Under bb, the terminal is environment-scoped, so it outlives this thread and appears in Terminal Hub. Elsewhere it runs under `nohup`, and the handle is the PID.
- **share** under bb checks `bb connect status --json` (`paired` and `enabled`). It then runs `bb connect expose <port>`, and the URL works for the owner's getbb.app session. Not paired → it prints the local URL and the reason; never sign in or turn on remote access yourself.
- **spawn-implementer** uses the deep tier (`opus`, or `gpt-6.1-sol` under Codex) at medium effort unless you pass `--model`/`--effort`.
- **notify-target** is `bb:<this thread>` under bb, else `none`. Pass it to `dashboard.mjs init --notify`. The dashboard calls `bb thread tell <thread> --mode auto --json --message-file -` without a shell, writes the text to stdin, and reads `delivery: sent | queued` from the JSON.

## Setup

Keep this skill explicit-only:

| Harness | Setting |
|---|---|
| Claude Code | `disable-model-invocation: true` in the `SKILL.md` frontmatter |
| Codex | `policy.allow_implicit_invocation: false` in `agents/openai.yaml` |
