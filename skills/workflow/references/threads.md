# Threads

Every thread you create is one of three verbs, and the verb decides where it sits and whether it reports back; two more verbs move a thread that already exists. Create threads only with `runtime.sh spawn`, never with a raw thread command, and never set `WORKFLOW_SPAWN=1` yourself; only the script uses it.

| Verb | `--mode` | Placement | Tells this thread |
|---|---|---|---|
| delegate | `child` (default) | child of this thread, brief starts `Role:` | one final report, plus failures |
| spin off | `spin-off` | top-level, own workspace | one message each on DONE, BLOCKED, FAILED; nothing else |
| start fresh | `fresh` | top-level, this thread's workspace by default | never; this thread is re-parented under the new one, silenced |
| adopt | `runtime.sh adopt <id> [--quiet]` | an existing thread becomes a child of this thread; it keeps its project, workspace and history | like a child: wakes this thread on every outcome; `--quiet` ("adopt quietly") sets notifications off |
| release | `runtime.sh release <id>` | a child thread becomes top-level again; it keeps its project, workspace and history | nothing: it no longer has a parent |

## Picking a verb

Settle two things: does the new thread sit under this one or at the top, and does it report back? Plain wording that settles both is enough ("work on issue x on a top-level thread so we can wrap this thread up" means start fresh); if either is open, suggest one with your reason ("I suggest spin off because … — ok?"), and never guess. Adopt is the reverse of start fresh ("make that thread a child of this one"), and release is the reverse of adopt; neither is "absorb", copying a thread's findings here and archiving it, which this skill doesn't define. The user may also name verbs the skill doesn't have yet: gather (adopt every open thread on one topic), relay (continue in a sibling thread from a handoff note when context runs low), queue (children one at a time, each after the last), rescue (copy what's worth keeping out of **storage** before archiving), side room (a quiet child the user talks to directly, whose history survives), and move house (spin off, adopt it, wait for go). Do those by hand with the verbs above, or say there's no command for them. "Wrap up" is only the user's way of saying they're finishing; it has no routine.

## Before a top-level thread

Search for one that already does this work (`runtime.sh threads "<query>"`) and list the open ones in the target project (`runtime.sh threads --project <id>`); if one clearly does, offer it instead, by its **link**. Then ask whether this thread keeps editing, because that sets the workspace. Start fresh reuses this one by default (`--env this`): this thread goes silent, and the new one carries on in the same branch with any uncommitted work. Spin off gets a new one (`--env new`), because both keep working and would collide; use `--env this` only when the user says this thread stops editing. A child shares this workspace, and `--isolated` gives it its own. To run the thread on another machine, add `--host`.

## Options

The three verbs that create a thread (delegate, spin off, start fresh) take `--wait-go` (the thread only reads and plans until the user, or this thread, says "go"), `--after <thread id>` (the same, released when that thread is done), `--context none|this|<thread id>` (the goal alone, for reviews the user wants fresh; the goal with relevant context, the default; or the goal with a pointer to another thread), and a named model or effort; otherwise the roster decides. Spin off also takes `--report-after-merge`, which holds DONE until the PR merges. Adopt takes only `--quiet`, and release takes nothing. `runtime.sh help spawn` has the details.

Who releases an `--after` thread depends on whether you track the one it waits on. If that thread is a spin-off in your `spin-offs.md`, its DONE message comes to you, so the script tells it nothing and the waiting thread's brief says you relay "go": when that DONE arrives, **tell** "go" to every thread waiting on it (the `waiting-on` column of `spin-offs.md`, and any child you spawned `--after` it, which your ledger notes). Otherwise the script tells that thread once to send "go" itself when it's done. Start fresh always takes this second path, even when the prerequisite is a tracked spin-off: this thread goes silent once the fresh one starts, so it can't relay, and the prerequisite tells the fresh thread directly.

## After spawning

Every verb prints a receipt; copy it to the user as it is, never from memory. Each spin off adds a row to `<storage>/spin-offs.md`. When the user asks how the spin-offs are doing, answer with one table (thread link, status, last milestone) with what needs their eye first on top; a spin-off that crashed without saying FAILED shows as `error`. A failed child slice is retried, not spawned again: `spawn` refuses a slice with no `report.md` and names the earlier worker, so retry that one (`runtime.sh retry <id>`), or pass `--force`.
