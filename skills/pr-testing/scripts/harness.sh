#!/bin/sh
# harness.sh — pr-testing's harness layer. Each term is a subcommand; under bb the action
# runs, elsewhere the honest fallback runs or the exact tool call is printed. Never translate
# a term yourself.
#
#   harness.sh terms                     the harness, then each term and what it means here
#   harness.sh features                  feature flags, one key=value per line
#   harness.sh storage                   this session's storage directory
#   harness.sh invoke                    the command that calls this skill
#   harness.sh notify-target             the dashboard's --notify value (none | bb:<thread>)
#   harness.sh run --title T --log FILE --cwd DIR -- CMD...   start a long-running process
#   harness.sh stop-run <handle>         stop what `run` started (its printed handle)
#   harness.sh share <port>              the address to give the user (remote when possible)
#   harness.sh unshare <port>            undo share
#   harness.sh spawn-implementer --brief FILE --title T [--model M] [--effort E]
#   harness.sh tell <id> -               message a worker (stdin)
#
# Override detection with PR_TESTING_HARNESS=codex (Codex sets no variable).
set -e

die() { printf '%s\n' "$*" >&2; exit 1; }

detect() {
  if [ -n "$PR_TESTING_HARNESS" ]; then printf '%s\n' "$PR_TESTING_HARNESS"
  elif [ -n "$BB_THREAD_ID" ]; then echo bb
  elif [ "$CLAUDECODE" = 1 ]; then echo claude-code
  else echo none
  fi
}

# The agent running inside bb: Claude Code when CLAUDECODE=1, else Codex.
agent() {
  case $(detect) in
    bb) if [ "$CLAUDECODE" = 1 ]; then echo claude-code; else echo codex; fi ;;
    *) detect ;;
  esac
}

# The deep tier: implementers fix code that ships.
deep_model() {
  case $(agent) in
    codex) echo gpt-6.1-sol ;;
    *) echo opus ;;
  esac
}

connect_ok() {
  command -v bb >/dev/null 2>&1 || return 1
  st=$(bb connect status --json 2>/dev/null) || return 1
  printf '%s' "$st" | grep -q '"paired": *true' && printf '%s' "$st" | grep -q '"enabled": *true'
}

features() {
  case $(detect) in
    bb) cat <<EOF
notify=yes
implementer=thread-worktree
process=terminal
share=$(if connect_ok; then echo remote; else echo local; fi)
secret=secure-prompt
EOF
    ;;
    claude-code) cat <<'EOF'
notify=no
implementer=subagent-worktree
process=detached
share=local
secret=user-file
EOF
    ;;
    codex) cat <<'EOF'
notify=no
implementer=subagent-own-worktree
process=detached
share=local
secret=user-file
EOF
    ;;
    *) cat <<'EOF'
notify=no
implementer=none
process=detached
share=local
secret=user-file
EOF
    ;;
  esac
}

terms() {
  h=$(detect)
  printf 'harness      %s\n' "$h"
  case $h in
  bb) cat <<'EOF'
storage      $BB_THREAD_STORAGE (harness.sh storage)
invoke       /pr-testing under Claude Code · $pr-testing under Codex
notify       dashboard buttons wake this thread: dashboard --notify "$(harness.sh notify-target)"
implementer  a child bb thread in its own new worktree: harness.sh spawn-implementer; its turn end wakes you
process      an environment terminal in Terminal Hub: harness.sh run; stop with harness.sh stop-run <terminal id>
share        BB Connect when paired and enabled (harness.sh share <port>), else the local URL
secret       the secrets skill writes values into a dotenv file you never read; you see key names only
link         @thread:<id>
EOF
  ;;
  claude-code) cat <<'EOF'
storage      ~/.agents/pr-testing/<session> (harness.sh storage)
invoke       /pr-testing
notify       none: buttons save and offer copy text; the user pastes it into chat or says "check the dashboard" (dashboard inbox)
implementer  a subagent with isolation "worktree": harness.sh spawn-implementer prints the Agent call
process      detached with nohup and a log: harness.sh run; stop with harness.sh stop-run <pid>
share        the local URL only
secret       the user writes the values into the env file you name; you never ask for or read them
link         the agent ID
EOF
  ;;
  codex) cat <<'EOF'
storage      ~/.agents/pr-testing/<session> (harness.sh storage)
invoke       $pr-testing (or pick it from /skills)
notify       none: buttons save and offer copy text; the user pastes it into chat or says "check the dashboard" (dashboard inbox)
implementer  a subagent (spawn-agent); no isolation, so its brief makes it create its own git worktree first
process      detached with nohup and a log: harness.sh run; stop with harness.sh stop-run <pid>
share        the local URL only
secret       the user writes the values into the env file you name; you never ask for or read them
link         the agent ID
EOF
  ;;
  *) cat <<'EOF'
storage      ~/.agents/pr-testing/<session> (harness.sh storage)
invoke       the skill's name
notify       none: buttons save and offer copy text
implementer  none: hand the user the brief to run in a new session in its own worktree; never fix it yourself
process      detached with nohup and a log: harness.sh run
share        the local URL only
secret       the user writes the values into the env file you name
link         main
EOF
  ;;
  esac
}

storage() {
  case $(detect) in
    bb) printf '%s\n' "${BB_THREAD_STORAGE:?BB_THREAD_STORAGE unset}" ;;
    *) printf '%s\n' "$HOME/.agents/pr-testing/${PR_TESTING_SESSION:-${CLAUDE_CODE_SESSION_ID:-default}}" ;;
  esac
}

# Single-quote each argument so a command survives as one string.
quote() {
  out=
  for a in "$@"; do
    q=$(printf '%s' "$a" | sed "s/'/'\\\\''/g")
    out="$out '$q'"
  done
  printf '%s' "${out# }"
}

run() {
  title= log= cwd=
  while [ $# -gt 0 ]; do
    case $1 in
      --title) title=$2; shift ;;
      --log) log=$2; shift ;;
      --cwd) cwd=$2; shift ;;
      --) shift; break ;;
      *) die "run: unknown argument $1" ;;
    esac; shift
  done
  [ -n "$title" ] && [ -n "$log" ] && [ -n "$cwd" ] && [ $# -gt 0 ] || die "run --title T --log FILE --cwd DIR -- CMD..."
  [ -d "$cwd" ] || die "run: no such directory: $cwd"
  mkdir -p "$(dirname "$log")"
  cmd="cd $(quote "$cwd") && $(quote "$@") 2>&1 | tee -a $(quote "$log")"
  case $(detect) in
    bb)
      # Terminal Hub shows it, keeps it after this thread settles, and lets the user restart it.
      # The terminal runs the user's login shell (maybe fish, maybe with cd aliased): hand it to sh.
      out=$(bb terminal create --environment "${BB_ENVIRONMENT_ID:?BB_ENVIRONMENT_ID unset}" --title "$title" --json --command "/bin/sh -c $(quote "$cmd")")
      id=$(printf '%s' "$out" | sed -n 's/^ *"id": *"\([^"]*\)".*/\1/p' | head -1)
      [ -n "$id" ] || die "run: bb terminal create gave no id: $out"
      printf 'handle %s\nlog %s\n' "$id" "$log"
      ;;
    *)
      # $! must be the command itself (nohup execs it), not a subshell around it.
      ( cd "$cwd" || exit 1; nohup "$@" >>"$log" 2>&1 & echo $! >"$log.pid" )
      pid=$(cat "$log.pid")
      printf 'handle %s\nlog %s\n' "$pid" "$log"
      ;;
  esac
}

# A dev server forks (package runner → node → workers): stop the whole tree, children first.
kill_tree() {
  for c in $(pgrep -P "$1" 2>/dev/null); do kill_tree "$c"; done
  kill "$1" 2>/dev/null || true
}

stop_run() {
  h=$1
  [ -n "$h" ] || die "stop-run <handle>"
  case $h in
    term_*) bb terminal close "$h" ;;
    *[!0-9]*) die "stop-run: unknown handle $h" ;;
    *) if kill -0 "$h" 2>/dev/null; then kill_tree "$h"; echo "stopped $h and its children"; else echo "not running: $h"; fi ;;
  esac
}

share() {
  port=$1
  case $port in ''|*[!0-9]*) die "share <port>" ;; esac
  if [ "$(detect)" = bb ] && connect_ok; then
    url=$(bb connect expose "$port" 2>&1 | grep -Eo 'https://[^ ]+' | head -1)
    [ -n "$url" ] && { printf 'remote %s\n' "$url"; return; }
    printf 'local http://127.0.0.1:%s/  (BB Connect expose failed)\n' "$port"
  elif [ "$(detect)" = bb ]; then
    printf 'local http://127.0.0.1:%s/  (BB Connect is not paired or is off: bb account login / bb connect on)\n' "$port"
  else
    printf 'local http://127.0.0.1:%s/\n' "$port"
  fi
}

unshare() {
  port=$1
  case $port in ''|*[!0-9]*) die "unshare <port>" ;; esac
  if [ "$(detect)" = bb ]; then bb connect unexpose "$port"; else echo "nothing to unshare"; fi
}

spawn_implementer() {
  brief= title= model= effort=medium
  while [ $# -gt 0 ]; do
    case $1 in
      --brief) brief=$2; shift ;;
      --title) title=$2; shift ;;
      --model) model=$2; shift ;;
      --effort) effort=$2; shift ;;
      *) die "spawn-implementer: unknown argument $1" ;;
    esac; shift
  done
  [ -f "$brief" ] && [ -n "$title" ] || die "spawn-implementer --brief FILE --title T [--model M] [--effort E]"
  [ -n "$model" ] || model=$(deep_model)
  case $(detect) in
    bb)
      bb thread spawn --project "${BB_PROJECT_ID:?BB_PROJECT_ID unset}" --parent-self --provider "$(agent)" \
        --model "$model" --reasoning-level "$effort" --title "$title" --prompt-file "$brief" \
        --permission-mode auto --new-environment worktree
      ;;
    claude-code) cat <<EOF
Call the Agent tool with:
  description: "$title"
  model: "$model"
  effort: "$effort"
  isolation: "worktree"
  prompt: the full contents of $brief
EOF
    ;;
    codex) cat <<EOF
Call the spawn-agent tool (read its schema first) with:
  model: "$model"
  reasoning_effort: "$effort"
  fork_context: false
  message: the full contents of $brief
The brief's Worktree line makes it create its own git worktree; never let it use the test checkout.
EOF
    ;;
    *) die "spawn-implementer: no workers here; give the user $brief to run in a new session in its own worktree" ;;
  esac
}

case ${1:-} in
  terms) terms ;;
  features) features ;;
  storage) storage ;;
  invoke) case $(agent) in codex) echo '$pr-testing' ;; claude-code) echo /pr-testing ;; *) echo pr-testing ;; esac ;;
  notify-target) if [ "$(detect)" = bb ]; then printf 'bb:%s\n' "${BB_THREAD_ID:?BB_THREAD_ID unset}"; else echo none; fi ;;
  run) shift; run "$@" ;;
  stop-run) stop_run "$2" ;;
  share) share "$2" ;;
  unshare) unshare "$2" ;;
  spawn-implementer) shift; spawn_implementer "$@" ;;
  tell) [ -n "$2" ] || die "tell <id> -"
        if [ "$(detect)" = bb ]; then bb thread tell "$2" --message-file -
        else echo "send the message with SendMessage (Claude Code) or send-message (Codex) to $2"; fi ;;
  ''|-h|--help|help) sed -n '2,19p' "$0" ;;
  *) die "unknown command: $1 (harness.sh help)" ;;
esac
