# harness.sh

`scripts/harness.sh` is the harness layer of this skill. Every harness term (worker, spawn, wait, read, tell, storage, compact, context reading, the tiers) is a subcommand; `terms` also names the **wake tools** a worker must not wait with. Run it; never translate a term yourself. Under bb each command performs the action. Under Claude Code or Codex, where the action is a tool call the shell cannot make, it prints the exact tool call to make. Under no harness it says so.

Path: `<skill folder>/scripts/harness.sh`. Needs `sh`; under bb also the `bb` CLI. Every command detects the harness itself from the environment (bb sets `BB_THREAD_ID`, Claude Code sets `CLAUDECODE=1`); you never pass it. Errors go to stderr with exit code 1; a wrong or missing argument prints the usage line (`read <id>`).

## Signatures

```ts
type Harness  = "bb" | "claude-code" | "codex" | "none"
type Provider = "claude-code" | "codex"
type Tier     = "fast" | "balanced" | "deep" | "consultant"
type Effort   = "low" | "medium" | "high" | "xhigh" | "max" | "ultra"   // ultra: codex only
type Id       = string            // bb: thr_…; Claude Code / Codex: the agent id
type ToolCall = string            // printed instructions: the exact tool call to make yourself

terms():                                        { harness: Harness; [term: string]: string }   // one line each
model(tier: Tier, provider?: Provider):         ModelId                                       // e.g. "opus"
storage():                                      AbsolutePath
context(id?: Id):                               TokenReading | "unknown"
title(goal: string):                            bb ? BbOutput : ToolCall      // rename this thread; run before the first spawn
spawn(opts: {
  role: string; tier: Tier; effort: Effort; brief: FilePath;
  slice?: string; goal?: string;                                   // title = "<goal> › <Role> · <slice>"
  isolated?: boolean; provider?: Provider                          // provider: bb only
}):                                             bb ? BbSpawnOutput /* names the new thr_ id */ : ToolCall
wait(id: Id):                                   bb ? BbOutput : ToolCall
read(id: Id):                                   bb ? LatestReply : ToolCall
tell(id: Id, message: string | "-"):            bb ? BbOutput : ToolCall      // "-": message from stdin
compact(id: Id):                                bb ? BbOutput : ToolCall      // bb: idle worker only

// every call: exit 1 + a usage or error line on stderr when input is wrong
```

## terms

`terms(): { harness, ...terms }`

Run once at the start; replaces reading a glossary.

Input: none.

Output: the harness on the first line, then one line per term with its meaning in this harness.
```
harness     bb
worker      a child bb thread; spawn it with: harness.sh spawn
spawn       harness.sh spawn --role R --tier T --effort E --brief FILE [--isolated]; the harness links it to you as parent
wait        end your turn: each child's turn end wakes you with its result ...
...
```

First line `none` but you are Codex (your system prompt or tool list says so) → Codex sets no variable; run `export WORKFLOW_HARNESS=codex` and start again. The variable overrides detection for every command. Under bb the hosted agent is Claude Code when `CLAUDECODE=1`, else Codex; `spawn` and `model` use that provider's model ids. Your tool list lacks the spawn mechanism `terms` names → you have no workers: treat spawn, wait, read, tell, and isolation as none.

## model

`model(tier: Tier, provider?: Provider): ModelId`

Input: a tier, `fast | balanced | deep | consultant`; optionally a provider, `claude-code | codex` (default: the one you run on).

Output: one model id.

| Tier | claude-code | codex |
|---|---|---|
| fast | `haiku` (Haiku 5.5) | `gpt-6-luna` |
| balanced | `sonnet` (Sonnet 5.5) | `gpt-6.1-sol` |
| deep | `opus` (Opus 5.5) | `gpt-6.1-sol` |
| consultant | `fable` (Fable 5.1) | `gpt-6-astra` |

```
harness.sh model deep          → opus
harness.sh model deep codex    → gpt-6.1-sol
harness.sh model nope          → unknown tier 'nope' (fast | balanced | deep | consultant)   exit 1
```

Use it for `Running on` in a brief and the `Plan` line of a classification. A tier is a model; effort (`low · medium · high · xhigh · max`; Codex adds `ultra`) is chosen separately by the routing table or the role card. A model or effort the harness lacks → the nearest available, noted in the classification and in the worker's `Running on` line so the worker does not report it as too weak.

## storage

`storage(): AbsolutePath`

Input: none. Elsewhere than bb, `WORKFLOW_TASK` names the task folder (default `default`).

Output: one absolute path, created by you on first use.
```
harness.sh storage                        → /Users/me/.bb/thread-storage/thr_w3fcd5r4xc      (bb: $BB_THREAD_STORAGE)
WORKFLOW_TASK=auth harness.sh storage     → /Users/me/.agents/workflow/auth                   (Claude Code, Codex, none)
```

A worker's storage is the `Storage:` path in its brief, not this command.

## context

`context(id?: Id): TokenReading | "unknown"`

Input: nothing for your own reading, or a worker id.

Output: bb prints the reading, e.g. `Estimated context: 174,711 / 1,000,000 tokens`; every other harness prints `unknown`. A bad id under bb: `Error: HTTP 404: Thread not found`.

Report `unknown` as such; never estimate.

## title

`title(goal: string): bb ? BbOutput : ToolCall`

Input: the goal, as the user would say it, e.g. `cost sheet accuracy`.

Output: bb runs `bb thread update --self --title "<goal>"` and prints its output; the thread is renamed and every later `spawn` prefixes its titles with it. Elsewhere it prints `no thread title here; export WORKFLOW_TASK='<goal>' so spawn titles carry the goal`, which you then do.

Run it once, before the first spawn, and do not rename afterwards: workers copy the title at spawn time.

## spawn

`spawn({ role, tier, effort, brief, slice?, goal?, isolated?, provider? }): bb ? BbSpawnOutput : ToolCall`

Input, all four required: `--role <Role>` · `--tier <tier>` · `--effort <level>` · `--brief <file>` (write it first: coordinating.md, Spawn). Optional: `--slice <name>` (default: the brief's folder name) · `--goal <name>` (default: this thread's title under bb, else `WORKFLOW_TASK`) · `--isolated` (own working copy: bb a new worktree, Claude Code `isolation: "worktree"`, Codex unavailable) · `--provider <claude-code | codex>` (bb only; default the hosted agent).

Output, by harness:

The title is `<goal> › <Role> · <slice>`, e.g. `cost sheet accuracy › Implementer · totals row`, so threads sort and read by goal.

- bb: runs `bb thread spawn --project $BB_PROJECT_ID --parent-self --provider <p> --model <id> --reasoning-level <effort> --title "<goal> › <Role> · <slice>" --prompt-file <brief> --permission-mode auto` with `--environment $BB_ENVIRONMENT_ID`, or `--new-environment worktree` when isolated. Prints bb's own output, which names the new thread id. The harness links the worker to you as parent; the brief's `Parent:` line is only text.
- Claude Code: prints the tool call, then you make it:
  ```
  Call the Agent tool with:
    description: "auth › Reviewer · whole diff"
    model: "opus"
    effort: "medium"
    isolation: "worktree"        (or: omit)
    prompt: the full contents of /path/to/brief.md
  ```
- Codex: prints the tool call, then you make it:
  ```
  Call the spawn-agent tool (read its schema first) with:
    model: "gpt-6.1-sol"
    reasoning_effort: "medium"
    fork_context: false
    message: the full contents of /path/to/brief.md
  ```
- none: `spawn: no workers in this harness; play the role yourself from <brief>`, exit 1.

Errors: `spawn: --role --tier --effort --brief are required` · `spawn: brief file not found: <path>` · `spawn: unknown argument <x>`.

## wait, read, tell, compact

`wait(id) · read(id) · tell(id, message | "-") · compact(id): bb ? BbOutput : ToolCall`

Input: a worker id; `tell` also a message, or `-` to read it from stdin.

Output under bb: the command runs and prints what bb prints.
```
harness.sh wait <id>            bb thread wait <id>      only within your shell's time limit; usually end your turn instead
harness.sh read <id>            bb thread output <id>    the latest reply, which may be a question or progress; the report file in the worker's storage is the stable record
harness.sh tell <id> "<msg>"    bb thread tell <id>      multi-line: harness.sh tell <id> - <<'EOF' ... EOF
harness.sh compact <id>         bb thread compact <id>   on an idle worker only; prints a replay note
```

After `compact <id>`, bb re-delivers the worker's last message as a new completion wake. `compact` prints `note: the next wake from <id> replays its last report; ignore it`. Run it in the same command as the next `tell` to that worker; a wake matching its last report is noise ([coordinating.md § Run](coordinating.md#5-run)). Suppressing these replays is a bb-core fix, outside this skill.

Output elsewhere: one line saying which tool to use instead, for example `read the agent's final message` or `send the message with SendMessage (Claude Code) or send-message (Codex) to <id>` or `ask the user to run /compact in that agent, or let auto-compaction run`.

Under bb, prefer ending your turn to `wait`: each child's turn end wakes you with its result.

## Reminder hook

Claude Code only, optional. [`scripts/reminder.sh`](../scripts/reminder.sh) injects a six-line checklist (classify, delegate or follow the brief, role card, compact or handoff, reload, coordinator quiet) before every message, including worker notifications. In `~/.claude/settings.json`, with `<dir>` = the installed skill folder:

```json
{ "hooks": { "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "sh <dir>/scripts/reminder.sh" }] }] } }
```
