# runtime.sh

`scripts/runtime.sh` is this skill's runtime layer: every runtime term (worker, spawn, wait, read, tell, storage, compact, context reading, the work and helper models) is one of its subcommands. Under bb each command performs the action; under Claude Code or Codex, where the action is a tool call the shell can't make, it prints the exact call to make; under no runtime it says so. Run it instead of translating a term yourself.

The script documents itself: `runtime.sh help` lists every command, and `runtime.sh help <command>` gives its flags and output, including the roster format (`help roster-save`). What a command prints (a receipt, a tool call, a Council block in a brief) is what you act on. Maintainers read the script's comments and `scripts/test-spawn.sh`, which checks every behavior. Setting up the spawn guard on a machine is in the repository README.

## Detect

Every command detects the runtime itself, top to bottom:

1. `WORKFLOW_RUNTIME` is set → that runtime (the older `WORKFLOW_HARNESS` still works until the next major release).
2. `BB_THREAD_ID` is set → bb. bb runs Claude Code or Codex inside it: the hosted agent is Claude Code when `CLAUDECODE=1`, else Codex, and `spawn` and `model` use that provider's model ids.
3. `CLAUDECODE=1` → Claude Code.
4. Otherwise → none. Codex sets no variable, so if `terms` prints `none` and you are Codex, run `export WORKFLOW_RUNTIME=codex` and start again.

If your tool list lacks the spawn mechanism `terms` names, you have no workers: treat spawn, wait, read, tell and isolation as none.
