#!/bin/sh
# harness.sh — the workflow skill's harness dictionary and wrapper.
# Each glossary term is a subcommand. Under bb the action runs; under a harness
# where the action is a tool call the shell cannot make, the exact tool
# parameters are printed instead. The agent never reads a table.
#
#   harness.sh terms                      the harness, then every term with its meaning here
#   harness.sh model <tier> [provider]    tier → model id (fast | balanced | deep | consultant)
#   harness.sh providers                  enabled providers and their model ids (built-in defaults outside bb)
#   harness.sh roster                     the user's agent roster (bb: the agent-roster memory; elsewhere: none, use built-in defaults)
#   harness.sh roster-save                save the roster from stdin (bb: update the global pinned memory agent-roster, or add it if absent; elsewhere: not stored). WORKFLOW_ROSTER_NAME overrides the memory name (tests)
#   harness.sh storage                    this agent's storage directory
#   harness.sh context [id]               context reading (self, or a worker's)
#   harness.sh title "<goal>"             set this thread's title to the goal, before the first spawn
#   harness.sh spawn --role R [--tier T --why W] --effort E --brief FILE [--slice S] [--goal G] [--isolated] [--provider P] [--model ID] [--author P]
#       --provider/--model come from the user's agent roster (SKILL.md, Roster); --model overrides the tier-derived id
#       tier defaults to the role card; above it needs --why (appended to the brief, logged in storage)
#       bb Reviewer: the vendor other than --author (default: the hosted agent). WORKFLOW_DRY_RUN=1 prints the bb command
#       title = "<goal> › <Role> · <slice>"; goal defaults to this thread's title (bb) or $WORKFLOW_TASK; slice to the brief folder
#   harness.sh wait <id>                  wait for a worker
#   harness.sh read <id>                  a worker's report
#   harness.sh tell <id> <message|->       message a worker (- reads stdin)
#   harness.sh compact <id>               compact an idle worker (bb: its next wake is a replay)
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
  tier=$1; p=${2:-$(provider)}
  case "$p:$tier" in
    claude-code:fast) echo haiku ;;
    claude-code:balanced) echo sonnet ;;
    claude-code:deep) echo opus ;;
    claude-code:consultant) echo fable ;;
    codex:fast) echo gpt-6-luna ;;
    codex:balanced|codex:deep) echo gpt-6.1-sol ;;
    codex:consultant) echo gpt-6-astra ;;
    claude-code:*|codex:*) die "unknown tier '$tier' (fast | balanced | deep | consultant)" ;;
    *) die "no built-in model for provider '$p'; pass --model <id> (harness.sh providers lists ids)" ;;
  esac
}

providers() {
  if [ "$(detect)" != bb ]; then
    echo "note: not under bb; these are the built-in defaults, not discovered"
    for t in fast balanced deep consultant; do
      printf '%-10s claude-code:%s  codex:%s\n' "$t" "$(model $t claude-code)" "$(model $t codex)"
    done
    return
  fi
  for id in $(bb provider list | awk 'NR>2 && $1 !~ /^-+$/ {print $1}'); do
    printf '%s\n' "$id"
    bb provider models "$id" --json 2>/dev/null | sed -n 's/^    "id": "\(.*\)",*$/  \1/p'
  done
}

roster_name=${WORKFLOW_ROSTER_NAME:-agent-roster}

# Prints the memory JSON whose name is exactly the roster name, else nothing.
roster_find() {
  for id in $(bb memory search "$roster_name" --scope all --json 2>/dev/null | sed -n 's/^      "id": "\(.*\)",*$/\1/p'); do
    j=$(bb memory get "$id" --json 2>/dev/null) || continue
    if printf '%s\n' "$j" | grep -q "^    \"name\": \"$roster_name\","; then printf '%s\n' "$j"; return; fi
  done
}

roster() {
  if [ "$(detect)" != bb ]; then
    echo "none: no roster storage here; use the built-in defaults (harness.sh model <tier>)"
    return
  fi
  j=$(roster_find)
  if [ -z "$j" ]; then echo "none: no $roster_name memory; use the built-in defaults"; return; fi
  printf '%s\n' "$j" | sed -n 's/^    "details": "\(.*\)",*$/\1/p' | sed 's/\\n/\n/g'
}

roster_save() {
  if [ "$(detect)" != bb ]; then echo "not stored: no roster storage here"; return; fi
  body=$(cat)
  [ -n "$body" ] || die "roster-save reads the roster rules on stdin"
  summary="User's agent roster: which provider/model each tier, role and Reviewer uses, plus fallback providers; read by the workflow skill at planning."
  j=$(roster_find)
  if [ -n "$j" ]; then
    id=$(printf '%s\n' "$j" | sed -n 's/^    "id": "\(.*\)",*$/\1/p' | head -1)
    ver=$(printf '%s\n' "$j" | sed -n 's/^    "version": \([0-9]*\),*$/\1/p' | head -1)
    bb memory update "$id" --expected-version "$ver" --details "$body" --reason "The user agreed a new roster."
  else
    bb memory add --scope global --pinned --kind preference --tag workflow,models,routing --importance 80 \
      --name "$roster_name" --summary "$summary" \
      --details "$body" --reason "The workflow skill routes workers by this roster."
  fi
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
spawn       harness.sh spawn --role R --effort E --brief FILE [--slice S] [--isolated]; the tier comes from the role card (above it: --tier T --why "<reason>"); a Reviewer runs on the vendor other than --author (default: you); the harness links it to you as parent
helper      a read-only lookup of your own with the Agent tool (Claude Code hosted): subagent_type "Explore", model "haiku"
wait        end your turn: each child's turn end wakes you with its result (harness.sh wait <id> only within the shell time limit)
read        harness.sh read <id>
tell        harness.sh tell <id> <message|->
link        @thread:<id>
nesting     yes, for pairing only: one helper per worker, never a coordinator under a coordinator (every child turn wakes its parent)
isolation   --isolated on spawn gives the worker its own worktree
storage     harness.sh storage (a worker's: the Storage: path in its brief)
compact     a worker: harness.sh compact <id>, in the same command as your next tell to it; its next wake replays its last report; yourself: ask the user to run /compact, or let auto-compaction run
wake tool   Claude Code: Monitor, ScheduleWakeup, a background shell command that re-invokes you; Codex: none. Each firing ends your turn and wakes your parent
permission  inherit; auto instead of accept-edits; denials become blockers
context     harness.sh context [id]
spawn cost  a full new session
auto branch bb/<title>-<thread id>, the branch bb names a new worktree; never push it
EOF
  ;;
  claude-code) cat <<'EOF'
worker      a subagent (Agent tool)
spawn       harness.sh spawn ... prints the Agent tool parameters (Explorer: Explore subagent on haiku); the tier comes from the role card; the brief's contents are the prompt
wait        a foreground Agent call, or its completion notification
read        the agent's final message
tell        SendMessage to the agent ID
link        the agent ID; the main session is main
nesting     usually no
isolation   Agent isolation: "worktree"
storage     harness.sh storage
compact     ask the user to run /compact, or let auto-compaction run
wake tool   Monitor, ScheduleWakeup, a background shell command that re-invokes you
permission  inherit
context     unknown
spawn cost  ~19K tokens
auto branch the branch an isolated worktree is created with; never push it
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
wake tool   none
permission  inherit sandbox and approval policy
context     unknown
spawn cost  a new session
auto branch none
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
wake tool   none
permission  none
context     unknown
spawn cost  none
auto branch none
EOF
  ;;
  esac
}

# role_tiers <role> → "<card tier> <highest tier allowed without --why>"; empty for roles without a card.
role_tiers() {
  case $(lower "$1") in
    explorer) echo "fast fast" ;;
    implementer|tester) echo "fast balanced" ;;
    researcher|prototyper) echo "balanced balanced" ;;
    architect|designer|reviewer) echo "deep deep" ;;
    consultant) echo "consultant consultant" ;;
  esac
}

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

rank() {
  case $1 in
    fast) echo 1 ;; balanced) echo 2 ;; deep) echo 3 ;; consultant) echo 4 ;;
    *) die "unknown tier '$1' (fast | balanced | deep | consultant)" ;;
  esac
}

other_provider() { if [ "$1" = codex ]; then echo claude-code; else echo codex; fi; }

spawn() {
  role= tier= effort= brief= slice= goal= isolated= prov= why= author= mod=
  while [ $# -gt 0 ]; do
    case $1 in
      --role) role=$2; shift ;;
      --tier) tier=$2; shift ;;
      --effort) effort=$2; shift ;;
      --brief) brief=$2; shift ;;
      --slice) slice=$2; shift ;;
      --goal) goal=$2; shift ;;
      --provider) prov=$2; shift ;;
      --model) mod=$2; shift ;;
      --author) author=$2; shift ;;
      --why) why=$2; shift ;;
      --isolated) isolated=1 ;;
      *) die "spawn: unknown argument $1" ;;
    esac; shift
  done
  [ -n "$role" ] && [ -n "$effort" ] && [ -n "$brief" ] || die "spawn: --role --effort --brief are required"
  [ -f "$brief" ] || die "spawn: brief file not found: $brief"
  card=$(role_tiers "$role")
  card_tier=${card% *}; max_tier=${card#* }
  if [ -z "$tier" ]; then
    [ -n "$card" ] || die "spawn: --tier is required for role '$role' (no role card)"
    tier=$card_tier
  fi
  rank "$tier" >/dev/null
  [ -n "$slice" ] || slice=$(basename "$(dirname "$brief")")
  h=$(detect)
  if [ -z "$goal" ]; then
    case $h in
      bb) goal=$(bb status --json 2>/dev/null | sed -n 's/^ *"title": "\(.*\)",*$/\1/p' | head -1) ;;
    esac
    [ -n "$goal" ] || goal=${WORKFLOW_TASK:-}
  fi
  if [ -n "$goal" ]; then title="$goal › $role · $slice"; else title="$role · $slice"; fi
  # Above the card's tier costs more on every turn: allowed, but only with a written reason.
  if [ -n "$card" ] && [ "$(rank "$tier")" -gt "$(rank "$max_tier")" ]; then
    [ -n "$why" ] || die "spawn: the $role card is $card_tier (up to $max_tier without a reason); --tier $tier needs --why \"<reason>\""
    printf "\nTier override: %s, above the card's %s — %s\n" "$tier" "$max_tier" "$why" >> "$brief"
    d=$(storage); mkdir -p "$d"
    printf '%s\t%s\t%s\t%s\n' "$(date '+%F %T')" "$title" "$tier" "$why" >> "$d/tier-overrides.log"
    printf 'note: tier override logged to %s/tier-overrides.log\n' "$d" >&2
  fi
  case $h in
  bb)
    p=$(provider bb)
    if [ -n "$prov" ]; then p=$prov
    elif [ "$(lower "$role")" = reviewer ]; then
      # Cross-vendor review: fresh eyes from the vendor other than the code's author.
      a=${author:-$(provider bb)}; p=$(other_provider "$a")
      if ! bb provider list 2>/dev/null | grep -qw "$p"; then
        printf "note: provider %s unavailable; the Reviewer runs on the author's vendor %s (say so in the classification)\n" "$p" "$a" >&2
        p=$a
      fi
    fi
    m=${mod:-$(model "$tier" "$p")}
    project=${BB_PROJECT_ID:?BB_PROJECT_ID unset}
    set -- bb thread spawn --project "$project" --parent-self --provider "$p" --model "$m" \
      --reasoning-level "$effort" --title "$title" --prompt-file "$brief" --permission-mode auto
    if [ -n "$isolated" ]; then set -- "$@" --new-environment worktree
    else set -- "$@" --environment "${BB_ENVIRONMENT_ID:?BB_ENVIRONMENT_ID unset}"; fi
    if [ -n "$WORKFLOW_DRY_RUN" ]; then printf '%s\n' "$*"; else "$@"; fi
    ;;
  claude-code)
    m=${mod:-$(model "$tier" claude-code)}
    st=
    if [ "$(lower "$role")" = explorer ]; then st='
  subagent_type: "Explore"'; fi
    cat <<EOF
Call the Agent tool with:
  description: "$title"$st
  model: "$m"
  effort: "$effort"
  isolation: $( [ -n "$isolated" ] && echo '"worktree"' || echo 'omit' )
  prompt: the full contents of $brief
EOF
    ;;
  codex)
    m=${mod:-$(model "$tier" codex)}
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
  providers) providers ;;
  roster) roster ;;
  roster-save) roster_save ;;
  storage) storage ;;
  context) shift; context "$@" ;;
  title) [ -n "$2" ] || die 'title "<goal>"'; bb_or_print "no thread title here; export WORKFLOW_TASK='$2' so spawn titles carry the goal" update --self --title "$2" ;;
  spawn) shift; spawn "$@" ;;
  wait) [ -n "$2" ] || die "wait <id>"; bb_or_print "end your turn; the completion notification wakes you (Claude Code: foreground Agent call; Codex: wait-agent tool)" wait "$2" ;;
  read) [ -n "$2" ] || die "read <id>"; bb_or_print "read the agent's final message" output "$2" ;;
  tell) [ -n "$2" ] && [ -n "$3" ] || die "tell <id> <message|->"
        msg="send the message with SendMessage (Claude Code) or send-message (Codex) to $2"
        if [ "$3" = - ]; then bb_or_print "$msg" tell "$2" --message-file -; else bb_or_print "$msg" tell "$2" "$3"; fi ;;
  compact) [ -n "$2" ] || die "compact <id>"; bb_or_print "ask the user to run /compact in that agent, or let auto-compaction run" compact "$2"
           if [ "$(detect)" = bb ]; then echo "note: the next wake from $2 replays its last report; ignore it"; fi ;;
  ''|-h|--help|help) sed -n '2,23p' "$0" ;;
  *) die "unknown command: $1 (run harness.sh help)" ;;
esac
