# harness.sh

`scripts/harness.sh` is the harness layer of this skill. Every harness term (worker, spawn, wait, read, tell, storage, compact, context reading, the tiers) is a subcommand; `terms` also names the **wake tools** a worker must not wait with. Run it; never translate a term yourself. Under bb each command performs the action. Under Claude Code or Codex, where the action is a tool call the shell cannot make, it prints the exact tool call to make. Under no harness it says so.

Path: `<skill folder>/scripts/harness.sh`. Needs `sh`; under bb also the `bb` CLI. Every command detects the harness itself from the environment (bb sets `BB_THREAD_ID`, Claude Code sets `CLAUDECODE=1`); you never pass it. Errors go to stderr with exit code 1; a wrong or missing argument prints the usage line (`read <id>`).

## Signatures

```ts
type Harness  = "bb" | "claude-code" | "codex" | "none"
type Provider = string   // built-in ids: "claude-code" | "codex"; under bb any provider in `bb provider list` (e.g. "acp-opencode")
type Tier     = "fast" | "balanced" | "deep" | "consultant"
type Effort   = "low" | "medium" | "high" | "xhigh" | "max" | "ultra"   // ultra: codex only
type Id       = string            // bb: thr_…; Claude Code / Codex: the agent id
type ToolCall = string            // printed instructions: the exact tool call to make yourself

terms():                                        { harness: Harness; [term: string]: string }   // one line each
model(tier: Tier, provider?: Provider):         ModelId                                       // e.g. "opus"
providers():                                    string                                        // enabled providers and their model ids
storage():                                      AbsolutePath
context(id?: Id):                               TokenReading | "unknown"
title(goal: string):                            bb ? BbOutput : ToolCall      // rename this thread; run before the first spawn
spawn(opts: {
  role: string; effort: Effort; brief: FilePath;
  tier?: Tier; why?: string;                                       // tier: default the role card's; above it, why is required
  slice?: string; goal?: string;                                   // title = "<goal> › <Role> · <slice>"
  isolated?: boolean; provider?: Provider; model?: ModelId; author?: Provider | `${Provider}:${ModelId}`; limited?: Provider[]   // bb only; model overrides the tier-derived id; author, limited: Reviewer pick (spawn)
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

Output: the harness on the first line, then one line per term with its meaning in this harness. `auto branch` names the branch the harness generates for a new working copy, which must never be pushed (SKILL.md, Branches).
```
harness     bb
worker      a child bb thread; spawn it with: harness.sh spawn
spawn       harness.sh spawn --role R --effort E --brief FILE [--slice S] [--isolated]; the tier comes from the role card (above it: --tier T --why "<reason>"); a Reviewer is the first available roster reviewer.order entry, the author's model only as the last resort (--author P:ID; --limited P,... for usage limits; no order: the vendor other than the author); the harness links it to you as parent
helper      the Agent tool (Claude Code hosted), only for a read-only lookup of your own: subagent_type "Explore", model "haiku"; any other job is a worker
wait        end your turn: each child's turn end wakes you with its result ...
...
```

First line `none` but you are Codex (your system prompt or tool list says so) → Codex sets no variable; run `export WORKFLOW_HARNESS=codex` and start again. The variable overrides detection for every command. Under bb the hosted agent is Claude Code when `CLAUDECODE=1`, else Codex; `spawn` and `model` use that provider's model ids. Your tool list lacks the spawn mechanism `terms` names → you have no workers: treat spawn, wait, read, tell, and isolation as none.

## providers

`providers(): string`

Under bb: for each provider in `bb provider list`, its id then its model ids (`bb provider models <id> --json`), one per line, indented. Elsewhere: the built-in defaults per tier, after a note that they were not discovered. Use it to build or check the roster ([SKILL.md, Roster](../SKILL.md#roster)).

### Roster memory

The roster is a global, pinned bb memory named `agent-roster`, a preference with tags `workflow,models,routing`. Its details start with `Fixed format read by the workflow skill; do not merge or reword.`, then one rule per line:

```
tier.<fast|balanced|deep|consultant>  <provider>:<model> …   model per provider for a tier
role.<role>                           <provider>:<model>     overrides the tier for that role
reviewer.order                        <provider>:<model> …   Reviewer candidates, walked in order; the author's model only as the last resort
reviewer.never                        <provider> …           never a Reviewer
fallback                              <from>><to> …          on <from>'s usage limit, move that work to <to>
```

A coordinator turns a line into `--provider <provider> --model <model>` on `spawn`. A provider or model missing from `providers` → the roster is stale. `reviewer.never` entries are exclusions, not providers: skip them in this check.

## roster

`roster(): string` and `roster-save(rules: stdin)`

`roster` prints the rules above. Under bb it reads the `agent-roster` memory (`bb memory search`, `bb memory get`); elsewhere it prints `none: …` and the caller uses the built-in defaults. `roster-save` writes the rules from stdin as that memory under bb (global, pinned): it updates the global memory when it exists (version-checked; project memories of the same name are ignored) and adds it only when absent; elsewhere it prints `not stored`.

## model

`model(tier: Tier, provider?: Provider): ModelId`

Input: a tier, `fast | balanced | deep | consultant`; optionally a built-in provider, `claude-code | codex` (default: the one you run on). Any other provider has no built-in table: `model` fails and `spawn` needs `--model`.

Output: one model id.

| Tier | claude-code | codex |
|---|---|---|
| fast | `haiku` (Haiku 5.5) | `gpt-6-luna` |
| balanced | `sonnet` (Sonnet 5.5) | `gpt-6.1-sol` |
| deep | `opus` (Opus 5.5) | `gpt-6.1-sol` |
| consultant | `fable` (Fable 5.1) | `gpt-6-astra` |

```
harness.sh model deep          → opus
harness.sh providers           → claude-code, codex, acp-opencode, each followed by its model ids (bb)
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

`spawn({ role, tier?, why?, effort, brief, slice?, goal?, isolated?, provider?, model?, author? }): bb ? BbSpawnOutput : ToolCall`

Input, required: `--role <Role>` · `--effort <level>` · `--brief <file>` (write it first: coordinating.md, Spawn).

Tier: `--tier <tier>` defaults to the role card (Explorer fast · Implementer, Tester fast, up to balanced · Researcher, Prototyper balanced · Architect, Designer, Reviewer deep · Consultant consultant); a role without a card must pass it. Above the card's highest tier → `--why "<reason>"` is required; the script appends `Tier override: <tier>, above the card's <max> — <reason>` to the brief and a line to `<storage>/tier-overrides.log`.

Reviewer, bb only, without `--provider`/`--model`: the first available entry of the roster's `reviewer.order`, walked in order. Unavailable: in `reviewer.never`, missing from `bb provider list`, or in `--limited <provider,…>` (at its usage limit). The entry with the author's model (`--author <provider>:<model>`, the id as the roster names it) is skipped, and taken only when every other entry is unavailable, with a note to put in the classification; the author's vendor on another model is fine. `--author <provider>` alone → that vendor counts as the author's model. Nothing available → exit 1. No `reviewer.order` → the vendor other than `--author` (default: the hosted agent); that vendor missing → the author's vendor, with a note.

Modes: `--mode child|spin-off|fresh` (default `child`, as above). `spin-off` and `fresh` (bb only) create a top-level thread: no `--parent-self`, `--new-environment <kind>` (`worktree`; `personal` when `bb project show <id> --json` says `"kind": "personal"`, the Personal project, which bb rejects worktrees in; the same kind is used for `--isolated`), title = `--goal` (required), no `Role:` brief, no `--role`; they need `--tier T` or `--model ID` (+ `--provider`), and `--effort`. They write the brief plus a harness-owned setup block (origin link, reporting rule, hold, context line) to `<storage>/briefs/<slice>-<mode>.md` and spawn from that. `fresh` then runs `bb thread update <origin> --parent-thread <new> --parent-notifications off`. Modifiers: `--wait-go` · `--after <thread id>` (untracked in `<storage>/spin-offs.md` or fresh mode → `bb thread tell <that id> "When your work is done, tell @thread:<new> go"` once) · `--context none|this|<thread id>` (`none` adds no `Context:` line) · `--report-after-merge` (spin-off only) · `--force` · `--project <id>` · `--host <id-or-name>` (bb only; passed to `bb thread spawn --host`, for a project whose source is on another machine). bb prints a receipt line (`Delegated|Spun off|Started fresh → @thread:<id> · <child|top-level> · <provider/model> · <effort> · <reporting rule> [· waiting for your go | · after @thread:X] · context: …`). A spin-off appends `| thread | title | started | trigger | waiting-on | status | last milestone |` to `<storage>/spin-offs.md`. A child slice already in `<storage>/spawned.log` (`slice<TAB>thread id`) with no `workers/<slice>/report.md` is refused: `run \`bb thread retry <id>\``. `WORKFLOW_DRY_RUN=1` prints every command (spawn, update, tell, ledger row) with `<new>` for the id. `scripts/test-spawn.sh` checks all of this.

Optional: `--slice <name>` (default: the brief's folder name) · `--goal <name>` (default: this thread's title under bb, else `WORKFLOW_TASK`) · `--isolated` (own working copy: bb a new worktree, Claude Code `isolation: "worktree"`, Codex unavailable) · `--provider <id>` (bb only; any listed provider, e.g. `acp-opencode`; default the hosted agent, or the Reviewer pick above) · `--model <id>` (replaces the tier-derived id; required for a provider without a built-in table; the tier is still checked against the role card) · `WORKFLOW_DRY_RUN=1` (bb: print the command instead of running it).

Output, by harness:

The title is `<goal> › <Role> · <slice>`, e.g. `cost sheet accuracy › Implementer · totals row`, so threads sort and read by goal.

- bb: runs `bb thread spawn --project $BB_PROJECT_ID --parent-self --provider <p> --model <id> --reasoning-level <effort> --title "<goal> › <Role> · <slice>" --prompt-file <brief> --permission-mode auto` with `--environment $BB_ENVIRONMENT_ID`, or `--new-environment worktree` when isolated. Prints the receipt line (the new thread id is in it). The harness links the worker to you as parent; the brief's `Parent:` line is only text.
- Claude Code: prints the tool call, then you make it (an Explorer adds `subagent_type: "Explore"` and runs on `haiku`):
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

Errors: `spawn: --role --effort --brief are required` · `spawn: --mode <m> needs --goal …` · `spawn: --mode <m> needs --tier T or --provider P --model ID` · `spawn: --mode <m> needs bb` · `spawn: --tier is required for role '<role>' (no role card)` · `spawn: the <Role> card is <tier> (up to <max> without a reason); --tier <t> needs --why "<reason>"` · `spawn: brief file not found: <path>` · `spawn: unknown argument <x>` · `no built-in model for provider '<p>'; pass --model <id>`.

## adopt

`adopt({ id, quiet? }): bb ? string : ToolCall` — `harness.sh adopt <id> [--quiet]`.

Makes an existing thread a child of this one; no thread is created, and the thread keeps its project, workspace and history. bb runs `bb thread update <id> --parent-thread $BB_THREAD_ID --parent-notifications auto` (`--quiet`: `off`) and prints `Adopted → @thread:<id> · child · reports <every outcome|off>`. Refuses itself as the target. Claude Code and Codex have no thread parents; the script prints the instruction to treat the thread as a worker and read its report. `WORKFLOW_DRY_RUN=1` prints the command instead of running it. `scripts/test-spawn.sh` checks this.

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

## Spawn guard

Optional. It blocks a command that runs `bb thread spawn` or `bb thread create` (not `--help`/`-h`, which is read-only) and names `harness.sh spawn --mode child|spin-off|fresh` instead, unless the command goes through `harness.sh` or carries `WORKFLOW_SPAWN=1`; `harness.sh spawn` sets that variable on its own bb call. It fails open (unreadable input → allow). It is a reminder, not a security boundary.

One step for a new machine: `sh <dir>/scripts/harness.sh install-guards` (`<dir>` = the installed skill folder). It installs all three guards below, can be run twice safely, backs up each file it edits (the backup name carries a checksum of the file's full path, so two Codex homes never share a backup), and skips an agent that is not installed.

The guard scripts do not run from the skill folder. The installer copies `spawn-guard.sh` and `spawn-check.sh` to `~/.local/share/workflow-guard/` (override with `WORKFLOW_GUARD_DIR`) and every hook and plugin points there, so moving or updating the skill never breaks a guard. After a skill update, run `install-guards` again: it refreshes the copies that differ and replaces an entry that still points at an old path, leaving one entry per config. It needs `jq`; Codex trust needs `python3`.

[`scripts/spawn-check.sh`](../scripts/spawn-check.sh) holds the check (command string in, exit 2 to block). Each agent has a thin adapter:

| Agent | Adapter | Registered in |
|---|---|---|
| Claude Code | `scripts/spawn-guard.sh` (hook JSON on stdin, exit 2 blocks) | `~/.claude/settings.json`: `hooks.PreToolUse` entry `{"matcher":"Bash","hooks":[{"type":"command","command":"sh <guard dir>/spawn-guard.sh"}]}` |
| Codex | the same `scripts/spawn-guard.sh` (same stdin shape, same exit 2) | `~/.codex/hooks.json`: same entry plus `"async":false`; Codex runs a hook only once it is trusted (`hooks.state` in `config.toml`, written through Codex's app-server `config/batchWrite`). Not covered: a different `CODEX_HOME` such as bb's provider home |
| opencode | `scripts/opencode-spawn-guard.ts`, a plugin whose `ctx.tool.hook("execute.before")` throws for the `shell` tool | `~/.config/opencode/plugins/workflow-spawn-guard.ts` (loaded automatically; `__SPAWN_CHECK__` is replaced by the path of the copied `spawn-check.sh`) |
