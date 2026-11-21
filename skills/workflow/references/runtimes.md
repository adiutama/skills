# runtime.sh

`scripts/runtime.sh` is the runtime layer of this skill. Every runtime term (worker, spawn, wait, read, tell, storage, compact, context reading, the work and helper models) is a subcommand; `terms` also names the **wake tools** a worker must not wait with. Run it; never translate a term yourself. Under bb each command performs the action. Under Claude Code or Codex, where the action is a tool call the shell cannot make, it prints the exact tool call to make. Under no runtime it says so.

Path: `<skill folder>/scripts/runtime.sh`. Needs `sh`; under bb also the `bb` CLI. Every command detects the runtime itself from the environment (bb sets `BB_THREAD_ID`, Claude Code sets `CLAUDECODE=1`); you never pass it. Errors go to stderr with exit code 1; a wrong or missing argument prints the usage line (`read <id>`).

## Signatures

```ts
type Runtime  = "bb" | "claude-code" | "codex" | "none"
type Provider = string   // built-in ids: "claude-code" | "codex"; under bb any provider in `bb provider list` (e.g. "acp-opencode")
type Kind     = "work" | "helper"   // the roster line a role card names
type Effort   = "low" | "medium" | "high" | "xhigh" | "max" | "ultra"   // ultra: codex only
type Id       = string            // bb: thr_…; Claude Code / Codex: the agent id
type ToolCall = string            // printed instructions: the exact tool call to make yourself

terms():                                        { runtime: Runtime; [term: string]: string }   // one line each
model(kind: Kind, provider?: Provider):         ModelId                                       // built-in default, e.g. "opus"
providers():                                    string                                        // enabled providers and their model ids
storage():                                      AbsolutePath
context(id?: Id):                               TokenReading | "unknown"
title(goal: string):                            bb ? BbOutput : ToolCall      // rename this thread; run before the first spawn
spawn(opts: {
  role: string; effort: Effort; brief: FilePath;
  helper?: boolean;                                                // a work-card role on the helper model
  slice?: string; goal?: string;                                   // title = "<goal> › <Role> · <slice>"
  isolated?: boolean; provider?: Provider; model?: ModelId;        // override the roster's model
  author?: `${Provider}:${ModelId}`; limited?: Provider[];         // council roles only
  size?: 2 | 3;                                                    // council-chair only, default 2
  chair?: `${Provider}:${ModelId}`;                                // council-member only
  mode?: "child" | "spin-off" | "fresh"; env?: "this" | "new" | EnvironmentId;            // env: spin-off/fresh only; default fresh=this, spin-off=new
}):                                             bb ? BbSpawnOutput /* names the new thr_ id */ : ToolCall
adopt(id: Id, opts?: { quiet?: boolean }):       bb ? string : ToolCall        // existing thread becomes this thread's child
release(id: Id):                                bb ? string : ToolCall        // child thread becomes top-level again
councilStop(chair?: Id):                        bb ? string : ToolCall        // end a council's members (and, with an id, the chair)
wait(id: Id):                                   bb ? BbOutput : ToolCall
read(id: Id):                                   bb ? LatestReply : ToolCall
tell(id: Id, message: string | "-"):            bb ? BbOutput : ToolCall      // "-": message from stdin
compact(id: Id):                                bb ? BbOutput : ToolCall      // bb: idle worker only
help(command?: string):                         string                        // the script header, or one command's usage and flags; unknown command: exit 1

// every call: exit 1 + a usage or error line on stderr when input is wrong
```

## terms

`terms(): { runtime, ...terms }`

Run once at the start; replaces reading a glossary.

Input: none.

Output: the runtime on the first line, then one line per term with its meaning in this runtime. `auto branch` names the branch the runtime generates for a new working copy, which must never be pushed (SKILL.md, Branches).
```
runtime     bb
worker      a child bb thread; spawn it with: runtime.sh spawn
spawn       runtime.sh spawn --role R --effort E --brief FILE [--slice S] [--isolated] [--helper]; the model is the roster's work or helper model, as the role card says (--helper: a work card on the helper model); a council: --role council-chair --author P:ID [--size 2|3] [--limited P,...] (the chair then spawns its members with --role council-member); the runtime links it to you as parent
helper      the Agent tool (Claude Code hosted), only for a read-only lookup of your own: subagent_type "Explore", model "haiku"; any other job is a worker
wait        end your turn: each child's turn end wakes you with its result ...
...
```

First line `none` but you are Codex (your system prompt or tool list says so) → Codex sets no variable; run `export WORKFLOW_RUNTIME=codex` and start again. The variable overrides detection for every command; the old name `WORKFLOW_HARNESS` still works as a fallback until the next major release. Under bb the hosted agent is Claude Code when `CLAUDECODE=1`, else Codex; `spawn` and `model` use that provider's model ids. Your tool list lacks the spawn mechanism `terms` names → you have no workers: treat spawn, wait, read, tell, and isolation as none.

## providers

`providers(): string`

Under bb: for each provider in `bb provider list`, its id then its model ids (`bb provider models <id> --json`), one per line, indented. Elsewhere: the built-in work and helper models per vendor, after a note that they were not discovered. Use it to build or check the roster ([SKILL.md, Roster](../SKILL.md#roster)).

### Roster memory

The roster is a global, pinned bb memory named `agent-roster-v2`, a preference with tags `workflow,models,routing`. Its details start with `Fixed format read by the workflow skill; do not merge or reword.`, then one rule per line:

```
work      <provider>:<model>             the model that does the work (effort medium or high)
helper    <provider>:<model>             helper subagents (read-only lookups) and mechanical-edit workers
council   <provider>:<model> …           reviewers, in order of preference
never     <provider|family> …            vendors (providers or model makers) that never review
fallback  <from>><to> …                  on <from>'s usage limit, move that work to <to>
```

`spawn` reads the lines itself: a role card's `work` or `helper` names the line, and a council role walks `council` (section spawn); pass `--provider`/`--model` only to override. Without a roster, or without a line: work = this runtime's deep model, helper = its fast model, council = the other built-in vendor's deep model, then this vendor's, then this vendor's second model (`fable`; Codex: `gpt-6-luna`), so a one-vendor runtime still has a chair when the author used the deep model (section model); no fallback. The old lines (`tier.*`, `role.*`, `reviewer.order`, `reviewer.never`) are no longer read. A model in `work`, `helper` or `council`, or a provider in `fallback`, that `providers` does not list → the roster is stale. `never` entries are exclusions, not providers: they are not checked.

## roster

`roster(): string` and `roster-save(rules: stdin)`

`roster` prints the rules above, and on stderr one `stale: <entry> not in providers` line per model `providers` does not list, or `stale: old roster format (tier./role./reviewer. lines); suggest a v2 roster` for a pre-2.0 roster; both mean: suggest a fix to the user. Under bb it reads the `agent-roster-v2` memory (`bb memory search`, `bb memory get`); when that is absent it reads `agent-roster`, the 1.x memory, using only its v2 lines, and warns `stale: no agent-roster-v2 memory; read agent-roster …`. Elsewhere it prints `none: …` and the caller uses the built-in defaults. `roster-save` writes the rules from stdin as `agent-roster-v2` under bb, never `agent-roster`, so running 1.x threads keep theirs; no swap at merge. It writes that memory (global, pinned): it updates the global memory when it exists (version-checked; project memories of the same name are ignored) and adds it only when absent; elsewhere it prints `not stored`.

## model

`model(kind: Kind, provider?: Provider): ModelId`

Input: `work | helper`; optionally a built-in provider, `claude-code | codex` (default: the one you run on). Any other provider has no built-in table: `model` fails and `spawn` needs `--model`. The built-in defaults, used when there is no roster:

| Kind | Vendor model | claude-code | codex |
|---|---|---|---|
| helper | fast | `haiku` (Haiku 5.5) | `gpt-6-luna` |
| work | deep | `opus` (Opus 5.5) | `gpt-6.2-sol` |

```
runtime.sh model work          → opus
runtime.sh providers           → claude-code, codex, acp-opencode, each followed by its model ids (bb)
runtime.sh model work codex    → gpt-6.2-sol
runtime.sh model deep          → unknown model kind 'deep' (work | helper; tiers were removed in workflow 2.0.0)   exit 1
```

Effort (`low · medium · high · xhigh · max`; Codex adds `ultra`) is chosen separately, by the role card or SKILL.md, Classify and route. A model or effort the runtime lacks → the nearest available, noted in the classification and in the worker's `Running on` line so the worker does not report it as too weak.

## storage

`storage(): AbsolutePath`

Input: none. Elsewhere than bb, `WORKFLOW_TASK` names the task folder (default `default`).

Output: one absolute path, created by you on first use.
```
runtime.sh storage                        → /Users/me/.bb/thread-storage/thr_w3fcd5r4xc      (bb: $BB_THREAD_STORAGE)
WORKFLOW_TASK=auth runtime.sh storage     → /Users/me/.agents/workflow/auth                   (Claude Code, Codex, none)
```

A worker's storage is the `Storage:` path in its brief, not this command.

## context

`context(id?: Id): TokenReading | "unknown"`

Input: nothing for your own reading, or a worker id.

Output: bb prints the reading, e.g. `Estimated context: 174,711 / 1,000,000 tokens`; every other runtime prints `unknown`. A bad id under bb: `Error: HTTP 404: Thread not found`.

Report `unknown` as such; never estimate.

## title

`title(goal: string): bb ? BbOutput : ToolCall`

Input: the goal, as the user would say it, e.g. `cost sheet accuracy`.

Output: bb runs `bb thread update --self --title "<goal>"` and prints its output; the thread is renamed and every later `spawn` prefixes its titles with it. Elsewhere it prints `no thread title here; export WORKFLOW_TASK='<goal>' so spawn titles carry the goal`, which you then do.

Run it once, before the first spawn, and do not rename afterwards: workers copy the title at spawn time.

## spawn

`spawn({ role, effort, brief, helper?, slice?, goal?, isolated?, provider?, model?, author?, limited?, size?, chair?, mode?, env? }): bb ? BbSpawnOutput : ToolCall`

Input, required: `--role <Role>` · `--effort <level>` · `--brief <file>` (write it first: coordinating.md, Spawn).

Model: the role card names `work` or `helper` (Explorer helper · Researcher, Prototyper, Designer, Implementer, Tester, Architect, council roles work); `spawn` takes that line of the roster, else the built-in default (section model). `--helper` puts a work-card role on the helper model (an Implementer for a mechanical edit; refused on council roles). `--provider <p> --model <id>` overrides it; `--model` alone keeps the hosted provider, `--provider` alone takes that provider's built-in model. A role without a card needs `--model`; `--role Reviewer` and `--role Consultant` exit 1 and point at the council. `--tier` and `--why` were removed in 2.0.0 and exit 1.

Council (SKILL.md, Verify). Eligible entry of the roster's `council` line, walked in order: neither its provider nor its family is in `never`, its provider is not in `--limited <provider,…>` (at its usage limit) and listed by `bb provider list` (outside bb: only this runtime's vendor), and its model is not the author's through any provider (`--author <provider>:<model>`; Claude aliases match their full ids, a `<vendor>/` prefix is ignored, so `acp-opencode:opencode/gpt-6.2-sol` is `codex:gpt-6.2-sol`). Family is the model's maker, read from the model id with any `<vendor>/` prefix stripped: `claude*` anthropic · `gpt*`, `o<n>*` openai · `gemini*` google · `grok*` xai · `glm*` zhipu · `kimi*` moonshot · `deepseek*` deepseek · `qwen*` alibaba · `mistral*` mistral · `llama*` meta; any other name → its provider id. One provider (acp-opencode) can serve many families. No roster → the built-in council (section Roster memory).

- `--role council-chair --author P:ID [--size 2|3] [--limited P,…]`, from the main thread: the first eligible entry; none → exit 1 (`no council model is eligible to chair`). `--size` (default 2; 3 for hard work) counts the chair. The composed brief, `<storage>/briefs/<slice>-child.md`, adds a Council block: the chair's model, the author, the size, the limited vendors, and the exact member spawn command.
- `--role council-member --author P:ID --chair P:ID [--limited P,…]`, from the chair: the next eligible entry whose family differs from the chair's and from every member's already in the council's `council.log` (`<chair P:ID><TAB><member P:ID><TAB><thread id | - | pending:<pid>:<slice> | failed | no-auto | lost>`, in the chair's storage), skipping seats logged `failed` or `no-auto`. The seat is reserved (`pending:<pid>:<slice>`, under the lock `.council.lock`) before the launch, so concurrent member spawns see it; the launch replaces it with the thread id. A pending seat whose spawn process died still counts toward the size and its family; the next member spawn (bb) checks the chair's live children (`bb thread list --parent-thread <chair> --json`): a child titled `… Council member · <slice>` not yet logged gives the seat its id, no such child marks it `lost` (no seat), and a failed lookup leaves it pending. Outside bb a dead pending seat stays until its line is removed; the chair's limited vendors are added to `--limited`. `--chair` and `--author` must match the chair's marker. At most size − 1 members (`the council is full`); none left → exit 1 (`no council model left for a member …; rule with fewer members: mark the verdict "council: <n> of <size>, too few families"`). Under bb the member's lifecycle owner is the chair (`--lifecycle-owner-thread`), so archiving the chair archives and stops its members.
- Nesting guards, checked against `runtime.sh storage` before anything else: `.council-member` there → every spawn exits 1; `.council-chair` there → only `--role council-member` (no other role, no chair, no `--mode spin-off|fresh`); under bb a member spawn without `.council-chair` exits 1 (`only a council chair spawns members`). A real council spawn writes the marker (`.council-chair`: `chair`, `author`, `size`, `limited` lines; `.council-member`: `member`, `chair`, `author`) into `<storage>/workers/<slice>/` and, under bb, into the new thread's own storage (`<thread-storage root>/<new id>/`, a sibling of this thread's); a dry run prints `marker: <path>` instead. Under bb the role also holds from creation: the title has a ` › ` segment starting `Council chair · ` or `Council member · ` (whatever is appended after it, e.g. `› follow-up`; a member segment wins over its chair's), and the guards read it from the thread's own record (`bb thread get $BB_THREAD_ID --json`), so a child that runs before its spawn returns is already restricted. If that lookup fails or has no title field and no marker exists, every spawn exits 1 (`council role is unknown`); a chair whose marker is not yet written waits up to 30 s for it before spawning a member. `--provider`/`--model` replace the pick but pass the same checks; they never bypass the guards or the size.
- Launch: council roles run with `--permission-mode auto`, so a reviewer runs `git diff`, `rg` and tests without approval prompts. A provider whose permission modes in `bb provider list --json` lack `auto` (acp-opencode today) holds no council seat: the pick skips it (`skipped <P:ID>: <provider> lists no auto permission mode`, on stderr), a member spawn logs it `no-auto` in `council.log`, and the council may be smaller (`too few families`); it is never given `full`. An unreadable provider list seats no one. Other workers run with `auto`, else the first listed. A failed bb launch prints its error, is logged `failed` in `council.log` (a member) and the next eligible seat is tried, at most 10 launches; an explicit `--provider`/`--model` is not replaced and exits 1.

Modes: `--mode child|spin-off|fresh` (default `child`, as above). `spin-off` and `fresh` (bb only) create a top-level thread: no `--parent-self`, `--new-environment <kind>` (`worktree`; `personal` when `bb project show <id> --json` says `"kind": "personal"`, the Personal project, which bb rejects worktrees in; the same kind is used for `--isolated`), title = `--goal` (required), no `Role:` brief, no `--role`; they take the work model (`--helper`: the helper model; `--provider`/`--model` override), and need `--effort`. They write the brief plus a runtime-owned setup block (origin link, reporting rule, hold, context line) to `<storage>/briefs/<slice>-<mode>.md` and spawn from that. `fresh` then runs `bb thread update <origin> --parent-thread <new> --parent-notifications off`. Workspace: `--env this|new|<environment id>` (spin-off and fresh only; with `--mode child` it exits 1, use `--isolated`): `this` → `--environment $BB_ENVIRONMENT_ID`, `new` → `--new-environment <kind>` as above, an id → `--environment <id>`; default `this` for fresh (the origin goes silent, so the branch and uncommitted work carry over) and `new` for spin-off (both keep working). The receipt ends `· env: reused|new|<id>`. Model ids: bb rejects the short Claude aliases, so `haiku`, `sonnet`, `opus`, `fable` (built-in or passed with `--model`) become `claude-haiku-5-5`, `claude-sonnet-5-5`, `claude-opus-5-5`, `claude-fable-5-2`. Modifiers: `--wait-go` · `--after <thread id>` (untracked in `<storage>/spin-offs.md` or fresh mode → `bb thread tell <that id> "When your work is done, tell @thread:<new> go"` once) · `--context none|this|<thread id>` (`none` adds no `Context:` line) · `--report-after-merge` (spin-off only) · `--force` · `--project <id>` · `--host <id-or-name>` (bb only; passed to `bb thread spawn --host`, for a project whose source is on another machine; without it bb answers "HTTP 409: No project source configured for this host"). bb prints a receipt line (`Delegated|Spun off|Started fresh → @thread:<id> · <child|top-level> · <provider/model> · <effort> · <reporting rule> [· waiting for your go | · after @thread:X] · context: …`). A spin-off appends `| thread | title | started | trigger | waiting-on | status | last milestone |` to `<storage>/spin-offs.md`. A child slice already in `<storage>/spawned.log` (`slice<TAB>thread id`) with no `workers/<slice>/report.md` is refused: `run \`bb thread retry <id>\``. `WORKFLOW_DRY_RUN=1` prints every command (spawn, update, tell, ledger row) with `<new>` for the id. `scripts/test-spawn.sh` checks all of this.

Optional: `--slice <name>` (default: the brief's folder name) · `--goal <name>` (default: this thread's title under bb, else `WORKFLOW_TASK`) · `--isolated` (own working copy: bb a new worktree, Claude Code `isolation: "worktree"`, Codex unavailable) · `--provider <id>` (bb only; any listed provider, e.g. `acp-opencode`; default the roster's line, else the hosted agent) · `--model <id>` (replaces the roster's or built-in id; required for a provider without a built-in table) · `WORKFLOW_DRY_RUN=1` (bb: print the command instead of running it).

Output, by runtime:

The title is `<goal> › <Role> · <slice>`, e.g. `cost sheet accuracy › Implementer · totals row`, so threads sort and read by goal; council roles use `Council chair` and `Council member` as the Role.

- bb: runs `bb thread spawn --project $BB_PROJECT_ID --parent-self --provider <p> --model <id> --reasoning-level <effort> --title "<goal> › <Role> · <slice>" --prompt-file <brief> --permission-mode <mode>` (section Council, Launch) with `--environment $BB_ENVIRONMENT_ID`, or `--new-environment worktree` when isolated. Prints the receipt line (the new thread id is in it). The runtime links the worker to you as parent; the brief's `Parent:` line is only text.
- Claude Code: prints the tool call, then you make it (an Explorer adds `subagent_type: "Explore"` and runs on `haiku`; full Claude ids are printed as their aliases):
  ```
  Call the Agent tool with:
    description: "auth › Council chair · whole diff"
    model: "opus"
    effort: "medium"
    isolation: "worktree"        (or: omit)
    prompt: the full contents of /path/to/brief.md
  ```
- Codex: prints the tool call, then you make it:
  ```
  Call the spawn-agent tool (read its schema first) with:
    model: "gpt-6.2-sol"
    reasoning_effort: "medium"
    fork_context: false
    message: the full contents of /path/to/brief.md
  ```
- none: `spawn: no workers in this runtime; play the role yourself from <brief>`, exit 1.

Errors: `spawn: --role --effort --brief are required` · `spawn: --mode <m> needs --goal …` · `spawn: --mode <m> needs bb` · `spawn: role '<role>' has no card; pass --model ID` · `spawn: --tier was removed in workflow 2.0.0 …` · `spawn: a council member never spawns …` · `spawn: a council chair spawns only --role council-member …` · `spawn: only a council chair spawns members …` · `spawn: the council is full …` · `spawn: no council model …` · `spawn: --size is 2 or 3` · `spawn: brief file not found: <path>` · `spawn: unknown argument <x>` · `no built-in model for provider '<p>'; pass --model <id>`.

### Council outside bb

Claude Code and Codex subagents do not nest, and only this runtime's vendor is available, so one model family: a council here is the chair alone. The flow: the main thread runs `spawn --role council-chair` (the built-in council gives a chair other than the author's model) and makes the printed call; it then runs the member command the chair's brief prints, which exits 1 (`no council model left … too few families`) because every other model is the chair's family. `--model` cannot substitute a same-vendor member: it passes the same checks. The main thread tells the chair (**tell**) that no member could be seated; the chair reviews alone and writes `verdict.md` with `council: 1 of <size>, too few families` on its Council line, and the main thread tells the user the review had one family. If a second family is ever eligible here, `spawn` finds the council by the newest `<storage>/workers/*/.council-chair` naming that chair, logs members in that folder's `council.log` and keeps the size cap; the discussion runs through files: each member writes `findings.md` in its own storage, the chair writes its merged list as `exchange-<n>.md`, the main thread resumes each member (**tell**) with that path, the member appends its answers to `findings.md`, and the chair writes `verdict.md`. The none runtime has no workers: no council; you review in sequence and the verdict says `council: 0 of <size>, too few families`.

### Links and receipts

Under bb a thread's **link** is `@thread:<id>`; elsewhere the agent id (the main session is `main`). The receipts the user is shown, copied as printed:

- spawn: `<Delegated|Spun off|Started fresh> → @thread:<id> · <child|top-level> · <provider/model · effort> · <reporting rule> [· waiting for your go | after @thread:X] · context: …`
- adopt: `Adopted → @thread:<id> · child · reports <every outcome|off>`
- release: `Released → @thread:<id> · top-level`
- reuse check: "@thread:X already works on this — I suggest telling it instead — ok?"

## council-stop

`councilStop(chair?: Id): bb ? string : ToolCall` — `runtime.sh council-stop [<chair id>]`.

Ends a council. In a chair, no argument: `bb thread stop` for each member thread in its `council.log` (run it after `verdict.md` and the report; a later **tell** for a re-check resumes a stopped member). From the main thread, with the chair's id: stops each child (`bb thread list --parent-thread <id>`), then the chair. `bb thread stop` does not cascade; archiving the chair does archive and stop its members (lifecycle owner). Prints `Stopped → <ids>`. Elsewhere it prints the instruction to stop resuming the members. `WORKFLOW_DRY_RUN=1` prints the commands.

## adopt

`adopt({ id, quiet? }): bb ? string : ToolCall` — `runtime.sh adopt <id> [--quiet]`.

Makes an existing thread a child of this one; no thread is created, and the thread keeps its project, workspace and history. bb runs `bb thread update <id> --parent-thread $BB_THREAD_ID --parent-notifications auto` (`--quiet`: `off`) and prints `Adopted → @thread:<id> · child · reports <every outcome|off>`. Refuses itself as the target. Claude Code and Codex have no thread parents; the script prints the instruction to treat the thread as a worker and read its report. `WORKFLOW_DRY_RUN=1` prints the command instead of running it. `scripts/test-spawn.sh` checks this.

## release

`release({ id }): bb ? string : ToolCall` — `runtime.sh release <id>`.

The reverse of adopt: a child thread becomes top-level again; no thread is created, and the thread keeps its project, workspace and history. bb runs `bb thread update <id> --clear-parent-thread` and prints `Released → @thread:<id> · top-level`. Refuses itself as the target. Claude Code and Codex have no thread parents; the script prints `release needs bb …`. `WORKFLOW_DRY_RUN=1` prints the command instead of running it. `scripts/test-spawn.sh` checks this.

## wait, read, tell, compact

`wait(id) · read(id) · tell(id, message | "-") · compact(id): bb ? BbOutput : ToolCall`

Input: a worker id; `tell` also a message, or `-` to read it from stdin.

Output under bb: the command runs and prints what bb prints.
```
runtime.sh wait <id>            bb thread wait <id>      only within your shell's time limit; usually end your turn instead
runtime.sh read <id>            bb thread output <id>    the latest reply, which may be a question or progress; the report file in the worker's storage is the stable record
runtime.sh tell <id> "<msg>"    bb thread tell <id>      multi-line: runtime.sh tell <id> - <<'EOF' ... EOF
runtime.sh compact <id>         bb thread compact <id>   on an idle worker only; prints a replay note
```

After `compact <id>`, bb re-delivers the worker's last message as a new completion wake. `compact` prints `note: the next wake from <id> replays its last report; ignore it`. Run it in the same command as the next `tell` to that worker; a wake matching its last report is noise ([coordinating.md § Run](coordinating.md#5-run)). Suppressing these replays is a bb-core fix, outside this skill.

Output elsewhere: one line saying which tool to use instead, for example `read the agent's final message` or `send the message with SendMessage (Claude Code) or send-message (Codex) to <id>` or `ask the user to run /compact in that agent, or let auto-compaction run`.

Under bb, prefer ending your turn to `wait`: each child's turn end wakes you with its result.

## Spawn guard

Optional. It blocks a command that runs `bb thread spawn` or `bb thread create` (not `--help`/`-h`, which is read-only) and names `runtime.sh spawn --mode child|spin-off|fresh` instead, unless the command goes through `runtime.sh` or carries `WORKFLOW_SPAWN=1`; `runtime.sh spawn` sets that variable on its own bb call. It fails open (unreadable input → allow). It is a reminder, not a security boundary.

One step for a new machine: `sh <dir>/scripts/runtime.sh install-guards` (`<dir>` = the installed skill folder). It installs all three guards below, can be run twice safely, backs up each file it edits (the backup name carries a checksum of the file's full path, so two Codex homes never share a backup), and skips an agent that is not installed.

The guard scripts do not run from the skill folder. The installer copies `spawn-guard.sh` and `spawn-check.sh` to `~/.local/share/workflow-guard/` (override with `WORKFLOW_GUARD_DIR`) and every hook and plugin points there, so moving or updating the skill never breaks a guard. After a skill update, run `install-guards` again: it refreshes the copies that differ and replaces an entry that still points at an old path, leaving one entry per config. It needs `jq`; Codex trust needs `python3`.

[`scripts/spawn-check.sh`](../scripts/spawn-check.sh) holds the check (command string in, exit 2 to block). Each agent has a thin adapter:

| Agent | Adapter | Registered in |
|---|---|---|
| Claude Code | `scripts/spawn-guard.sh` (hook JSON on stdin, exit 2 blocks) | `~/.claude/settings.json`: `hooks.PreToolUse` entry `{"matcher":"Bash","hooks":[{"type":"command","command":"sh <guard dir>/spawn-guard.sh"}]}` |
| Codex | the same `scripts/spawn-guard.sh` (same stdin shape, same exit 2) | `~/.codex/hooks.json`: same entry plus `"async":false`; Codex runs a hook only once it is trusted (`hooks.state` in `config.toml`, written through Codex's app-server `config/batchWrite`). Not covered: a different `CODEX_HOME` such as bb's provider home |
| opencode | `scripts/opencode-spawn-guard.ts`, a plugin whose `ctx.tool.hook("execute.before")` throws for the `shell` tool | `~/.config/opencode/plugins/workflow-spawn-guard.ts` (loaded automatically; `__SPAWN_CHECK__` is replaced by the path of the copied `spawn-check.sh`) |
