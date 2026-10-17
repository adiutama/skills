# Harnesses

## Detect

1. **Identity.** Read the environment with one shell call (`echo "$BB_THREAD_ID|$CLAUDECODE"`), then check top to bottom; the first match is your harness.

   | Harness | Signal |
   |---|---|
   | bb | `BB_THREAD_ID` is set |
   | Claude Code | `CLAUDECODE=1` |
   | Codex | you are Codex (your system prompt or tool list says so) |
   | none | no match |

2. **Hosted agent.** bb runs Claude Code or Codex inside it; the bb column names both where they differ, and the tier table uses the hosted agent's column. Workers you spawn under bb are bb threads; never mix bb threads and native subagents in one plan.
3. **Capabilities.** Your tool list lacks the spawn mechanism in your column → treat worker, spawn, wait, read, tell, and isolation as `—`, whatever your identity.

## Glossary

Each term means what your harness's column says, everywhere in this skill and its templates.

| Term | Meaning | bb | Claude Code | Codex | none |
|---|---|---|---|---|---|
| worker | an agent you start for one job | child thread | subagent | subagent | — (you play every role in sequence) |
| spawn | start a worker with a brief, tier, and effort | `bb thread spawn --project <id from bb status> --parent-self --environment "$BB_ENVIRONMENT_ID" --provider <claude-code\|codex> --model <id> --reasoning-level <effort> --title "<Role>: <task>" --prompt-file <brief>` | Agent tool; `model`, `effort`; brief contents as the prompt | spawn-agent tool (read its schema first); `model`, `reasoning_effort`, non-forked context; brief contents as the prompt | — |
| wait | block until a worker's turn ends | `bb thread wait <id>` | foreground Agent call, or its completion notification | wait-agent tool; repeat after a timeout | — |
| read | get a worker's report | `bb thread output <id>` (full history: `bb thread log <id>`) | the agent's final message | the agent's final report | — |
| tell | message a running worker | `bb thread tell <id>` | SendMessage to the agent ID | send-message / follow-up tool with the agent ID | — |
| link | a reference to an agent, for the user and for `Parent:` | `@thread:<id>` | agent ID; the main session is `main` | agent ID; the main session is `main` | `main` |
| nesting | workers can spawn workers | yes | usually no | yes if the worker has the spawn tool | — |
| isolation | give a worker its own working copy | `--new-environment worktree` on spawn | Agent `isolation: "worktree"` | — (one shared working directory) | — |
| storage | your per-agent directory that outlives context; a worker's is the `Storage:` path in its brief | `$BB_THREAD_STORAGE` | `~/.agents/orchestration/<task>/` | `~/.agents/orchestration/<task>/` | `~/.agents/orchestration/<task>/` |
| compact | shrink your context after the ledger is current | ask the user to run `/compact`, or let auto-compaction run | ask the user to run `/compact`, or let auto-compaction run | ask the user to run `/compact`, or let auto-compaction run | start a fresh session from the handoff note |
| permission | a worker's permission mode | inherit; `auto` instead of `accept-edits`; denials become blockers | inherit | inherit sandbox and approval policy | — |
| specialist installed | the `specialist` skill is available | `~/.bb/skills/specialist` exists | listed in available skills | listed in available skills | listed in available skills |
| context reading | a token count the model can see | Claude Code: hook line, if installed · Codex: unknown | hook line, if [installed](#context-zone-hook) | unknown | unknown |
| spawn cost | context a worker uses before working | a full new session | ~19K tokens | a new session | — |

## Tiers

A tier names a model; effort comes from the routing table or role, never from the tier.

| Tier | Claude | Codex | other |
|---|---|---|---|
| fast | Haiku 5.5 (`haiku`) | `gpt-6-luna` | smallest, cheapest model |
| balanced | Sonnet 5.5 (`sonnet`) | `gpt-6.1-sol` | mid model |
| deep | Opus 5.5 (`opus`) | `gpt-6.1-sol` | strongest everyday model |
| consultant | Fable 5.1 (`fable`) | `gpt-6-astra` | top model, if any; else deep |

| Effort | Claude | Codex |
|---|---|---|
| levels | low · medium · high · xhigh · max | low · medium · high · xhigh · max · ultra |

A model missing from your plan → nearest available, noted in the classification block.
Harness `none`, or a vendor not listed → use the `other` column. An effort level your harness lacks → the nearest one it has, noted the same way.

## Context zone hook

Claude Code only. [`scripts/context-zone.sh`](../scripts/context-zone.sh) reads the session transcript and injects one line when the zone changes. Needs `jq`. Set `CTX_WINDOW` to your window size (e.g. `200000`) when it is under ~300K, so the hook uses 50 % / 80 %; or override directly with `CTX_GREEN_MAX`, `CTX_YELLOW_MAX`, `CTX_RED_REMIND`.

In `~/.claude/settings.json`, with `<dir>` = the installed skill folder:

```json
{
  "hooks": {
    "PostToolUse": [{ "hooks": [{ "type": "command", "command": "<dir>/scripts/context-zone.sh hook" }] }],
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "<dir>/scripts/context-zone.sh hook" }] }]
  },
  "statusLine": { "type": "command", "command": "<dir>/scripts/context-zone.sh status \"$(jq -r .transcript_path)\"" }
}
```
