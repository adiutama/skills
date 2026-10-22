#!/bin/sh
# harness.sh — the workflow skill's harness dictionary and wrapper.
# Each glossary term is a subcommand. Under bb the action runs; under a harness
# where the action is a tool call the shell cannot make, the exact tool
# parameters are printed instead. The agent never reads a table.
#
#   harness.sh terms                      the harness, then every term with its meaning here
#   harness.sh model <tier> [provider]    tier → model id (fast | balanced | deep | consultant)
#   harness.sh storage                    this agent's storage directory
#   harness.sh context [id]               context reading (self, or a worker's)
#   harness.sh title "<goal>"             set this thread's title to the goal, before the first spawn
#   harness.sh spawn --role R --tier T --effort E --brief FILE [--slice S] [--goal G] [--isolated] [--provider P]
#       title = "<goal> › <Role> · <slice>"; goal defaults to this thread's title (bb) or $WORKFLOW_TASK; slice to the brief folder
#   harness.sh wait <id>                  wait for a worker
#   harness.sh read <id>                  a worker's report
#   harness.sh tell <id> <message|->       message a worker (- reads stdin)
#   harness.sh compact <id>               compact an idle worker
#
# Override detection with WORKFLOW_HARNESS=codex (Codex has no env signal).
set -e

die() { printf '%s\n' "$*" >&2; exit 1; }

detect() {
  if [ -n "$WORKFLOW_HARNESS" ]; then printf '%s\n' "$WORKFLOW_HARNESS"
  elif [ -n "$BB_THREAD_ID" ]; then echo bb
  elif [ "$CLAUDECODE" = 1 ]; then echo claude-code
  else echo none
  fi
}

# provider: the model vendor whose ids we use. Under bb it is the hosted agent.
provider() {
  case "${1:-$(detect)}" in
    codex) echo codex ;;
    claude-code) echo claude-code ;;
    bb) if [ "$CLAUDECODE" = 1 ]; then echo claude-code; else echo codex; fi ;;
    *) echo claude-code ;;
  esac
}

model() {
  tier=$1; p=$(provider "$2")
  case "$p:$tier" in
    claude-code:fast) echo haiku ;;
    claude-code:balanced) echo sonnet ;;
    claude-code:deep) echo opus ;;
    claude-code:consultant) echo fable ;;
    codex:fast) echo gpt-6-luna ;;
    codex:balanced|codex:deep) echo gpt-6.1-sol ;;
    codex:consultant) echo gpt-6-astra ;;
    *) die "unknown tier '$tier' (fast | balanced | deep | consultant)" ;;
  esac
}

storage() {
  case $(detect) in
    bb) printf '%s\n' "${BB_THREAD_STORAGE:?BB_THREAD_STORAGE unset}" ;;
    *) printf '%s\n' "$HOME/.agents/workflow/${WORKFLOW_TASK:-default}" ;;
  esac
}

context() {
  case $(detect) in
    bb) if [ -n "$1" ]; then bb thread context "$1"; else bb thread context --self; fi ;;
    *) echo unknown ;;
  esac
}

terms() {
  h=$(detect)
  printf 'harness     %s\n' "$h"
  case $h in
  bb) cat <<'EOF'
worker      a child bb thread; spawn it with: harness.sh spawn
spawn       harness.sh spawn --role R --tier T --effort E --brief FILE [--slice S] [--isolated]; the harness links it to you as parent
wait        end your turn: each child's turn end wakes you with its result (harness.sh wait <id> only within the shell time limit)
read        harness.sh read <id>
tell        harness.sh tell <id> <message|->
link        @thread:<id>
nesting     yes, for pairing only: one helper per worker, never a coordinator under a coordinator (every child turn wakes its parent)
isolation   --isolated on spawn gives the worker its own worktree
storage     harness.sh storage (a worker's: the Storage: path in its brief)
compact     a worker: harness.sh compact <id>; yourself: ask the user to run /compact, or let auto-compaction run
permission  inherit; auto instead of accept-edits; denials become blockers
context     harness.sh context [id]
spawn cost  a full new session
EOF
  ;;
  claude-code) cat <<'EOF'
worker      a subagent (Agent tool)
spawn       harness.sh spawn ... prints the Agent tool parameters; the brief's contents are the prompt
wait        a foreground Agent call, or its completion notification
read        the agent's final message
tell        SendMessage to the agent ID
link        the agent ID; the main session is main
nesting     usually no
isolation   Agent isolation: "worktree"
storage     harness.sh storage
compact     ask the user to run /compact, or let auto-compaction run
permission  inherit
context     unknown
spawn cost  ~19K tokens
EOF
  ;;
  codex) cat <<'EOF'
worker      a subagent (spawn-agent tool; read its schema first)
spawn       harness.sh spawn ... prints the spawn-agent parameters; non-forked context; the brief's contents are the prompt
wait        wait-agent tool; repeat after a timeout
read        the agent's final report
tell        send-message / follow-up tool with the agent ID
link        the agent ID; the main session is main
nesting     yes if the worker has the spawn tool; pairing only, never a coordinator under a coordinator
isolation   none: one shared working directory; parallelize only disjoint writes
storage     harness.sh storage
compact     ask the user to run /compact, or let auto-compaction run
permission  inherit sandbox and approval policy
context     unknown
spawn cost  a new session
EOF
  ;;
  *) cat <<'EOF'
worker      none: you play every role in sequence
spawn       none
wait        none
read        none
tell        none
link        main
nesting     none
isolation   none
storage     harness.sh storage
compact     start a fresh session from the handoff note
permission  none
context     unknown
spawn cost  none
EOF
  ;;
  esac
}

spawn() {
  role= tier= effort= brief= slice= goal= isolated= prov=
  while [ $# -gt 0 ]; do
    case $1 in
      --role) role=$2; shift ;;
      --tier) tier=$2; shift ;;
      --effort) effort=$2; shift ;;
      --brief) brief=$2; shift ;;
      --slice) slice=$2; shift ;;
      --goal) goal=$2; shift ;;
      --provider) prov=$2; shift ;;
      --isolated) isolated=1 ;;
      *) die "spawn: unknown argument $1" ;;
    esac; shift
  done
  [ -n "$role" ] && [ -n "$tier" ] && [ -n "$effort" ] && [ -n "$brief" ] || die "spawn: --role --tier --effort --brief are required"
  [ -f "$brief" ] || die "spawn: brief file not found: $brief"
  [ -n "$slice" ] || slice=$(basename "$(dirname "$brief")")
  h=$(detect)
  if [ -z "$goal" ]; then
    case $h in
      bb) goal=$(bb status --json 2>/dev/null | sed -n 's/^ *"title": "\(.*\)",*$/\1/p' | head -1) ;;
    esac
    [ -n "$goal" ] || goal=${WORKFLOW_TASK:-}
  fi
  if [ -n "$goal" ]; then title="$goal › $role · $slice"; else title="$role · $slice"; fi
  case $h in
  bb)
    p=$(provider bb); [ -n "$prov" ] && p=$prov
    m=$(model "$tier" "$p")
    project=${BB_PROJECT_ID:?BB_PROJECT_ID unset}
    set -- bb thread spawn --project "$project" --parent-self --provider "$p" --model "$m" \
      --reasoning-level "$effort" --title "$title" --prompt-file "$brief" --permission-mode auto
    if [ -n "$isolated" ]; then set -- "$@" --new-environment worktree
    else set -- "$@" --environment "${BB_ENVIRONMENT_ID:?BB_ENVIRONMENT_ID unset}"; fi
    "$@"
    ;;
  claude-code)
    m=$(model "$tier" claude-code)
    cat <<EOF
Call the Agent tool with:
  description: "$title"
  model: "$m"
  effort: "$effort"
  isolation: $( [ -n "$isolated" ] && echo '"worktree"' || echo 'omit' )
  prompt: the full contents of $brief
EOF
    ;;
  codex)
    m=$(model "$tier" codex)
    cat <<EOF
Call the spawn-agent tool (read its schema first) with:
  model: "$m"
  reasoning_effort: "$effort"
  fork_context: false
  message: the full contents of $brief
EOF
    ;;
  *) die "spawn: no workers in this harness; play the role yourself from $brief" ;;
  esac
}

bb_or_print() {  # $1 = what to do outside bb; the rest = bb thread arguments
  msg=$1; shift
  case $(detect) in
    bb) bb thread "$@" ;;
    *) printf '%s\n' "$msg" ;;
  esac
}

case ${1:-} in
  terms) terms ;;
  model) shift; model "$@" ;;
  storage) storage ;;
  context) shift; context "$@" ;;
  title) [ -n "$2" ] || die 'title "<goal>"'; bb_or_print "no thread title here; export WORKFLOW_TASK='$2' so spawn titles carry the goal" update --self --title "$2" ;;
  spawn) shift; spawn "$@" ;;
  wait) [ -n "$2" ] || die "wait <id>"; bb_or_print "end your turn; the completion notification wakes you (Claude Code: foreground Agent call; Codex: wait-agent tool)" wait "$2" ;;
  read) [ -n "$2" ] || die "read <id>"; bb_or_print "read the agent's final message" output "$2" ;;
  tell) [ -n "$2" ] && [ -n "$3" ] || die "tell <id> <message|->"
        msg="send the message with SendMessage (Claude Code) or send-message (Codex) to $2"
        if [ "$3" = - ]; then bb_or_print "$msg" tell "$2" --message-file -; else bb_or_print "$msg" tell "$2" "$3"; fi ;;
  compact) [ -n "$2" ] || die "compact <id>"; bb_or_print "ask the user to run /compact in that agent, or let auto-compaction run" compact "$2" ;;
  ''|-h|--help|help) sed -n '2,19p' "$0" ;;
  *) die "unknown command: $1 (run harness.sh help)" ;;
esac
