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
#   harness.sh spawn --role R [--tier T --why W] --effort E --brief FILE [--slice S] [--goal G] [--isolated] [--provider P] [--model ID] [--author P[:ID]] [--limited P,...]
#       --provider/--model come from the user's agent roster (SKILL.md, Roster); --model overrides the tier-derived id
#       tier defaults to the role card; above it needs --why (appended to the brief, logged in storage)
#       bb Reviewer (no --provider/--model): the first available roster reviewer.order entry, skipping reviewer.never, providers missing or
#       --limited (at their usage limit), and the --author model (last resort); no order → the vendor other than --author (default: the hosted agent)
#       title = "<goal> › <Role> · <slice>"; goal defaults to this thread's title (bb) or $WORKFLOW_TASK; slice to the brief folder
#       --mode child|spin-off|fresh (default child): spin-off and fresh make a top-level thread in its own worktree (no --role; need --goal, and --tier or --provider/--model)
#       --wait-go · --after <thread id> · --context none|this|<thread id> · --report-after-merge (spin-off) · --force (re-spawn a slice with no report.md) · --project <id> · --host <id-or-name> (the machine to run on; passed to bb thread spawn as --host)
#       prints the receipt line; WORKFLOW_DRY_RUN=1 prints the commands for every mode
#   harness.sh adopt <id> [--quiet]       make an existing thread a child of this one (bb: bb thread update <id> --parent-thread <this>; --quiet adds --parent-notifications off); prints the receipt. Elsewhere: prints the equivalent instruction
#   harness.sh wait <id>                  wait for a worker
#   harness.sh read <id>                  a worker's report
#   harness.sh tell <id> <message|->       message a worker (- reads stdin); warns on stderr when its report.md or storage folder is missing
#   harness.sh install-guards            install the spawn guard for Claude Code, Codex and opencode on this machine (idempotent; backs up edited files; skips agents that are not installed)
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
  for id in $(bb memory search "$roster_name" --scope global --json 2>/dev/null | sed -n 's/^      "id": "\(.*\)",*$/\1/p'); do
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
spawn       harness.sh spawn --role R --effort E --brief FILE [--slice S] [--isolated]; the tier comes from the role card (above it: --tier T --why "<reason>"); a Reviewer is the first available roster reviewer.order entry, the author's model only as the last resort (--author P:ID; --limited P,... for usage limits; no order: the vendor other than the author); the harness links it to you as parent
helper      the Agent tool (Claude Code hosted), only for a read-only lookup of your own: subagent_type "Explore", model "haiku"; any other job is a worker
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

# q: print args as one POSIX-shell-quoted command line.
q() {
  for a in "$@"; do
    case $a in
      ''|*[!A-Za-z0-9_./:=@%+,-]*) printf "'%s' " "$(printf '%s' "$a" | sed "s/'/'\\\\''/g")" ;;
      *) printf '%s ' "$a" ;;
    esac
  done
  printf '\n'
}

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

rank() {
  case $1 in
    fast) echo 1 ;; balanced) echo 2 ;; deep) echo 3 ;; consultant) echo 4 ;;
    *) die "unknown tier '$1' (fast | balanced | deep | consultant)" ;;
  esac
}

other_provider() { if [ "$1" = codex ]; then echo claude-code; else echo codex; fi; }

# roster_rule <key>: the entries of that roster line (bb only), else nothing.
roster_rule() {
  [ "$(detect)" = bb ] || return 0
  roster 2>/dev/null | awk -v k="$1" '$1 == k { $1 = ""; sub(/^ +/, ""); print; exit }'
}

# pick_reviewer <author provider[:model]> <reviewer.order entries>: sets pick=<provider>:<model>.
# Walks the order; skips reviewer.never, providers missing from bb provider list or passed in --limited,
# and the author's model (the author's vendor when its model is unknown), which is the last resort.
pick_reviewer() {
  ap=${1%%:*}; am=; case $1 in *:*) am=${1#*:} ;; esac
  never=" $(roster_rule reviewer.never) "
  have=" $(bb provider list 2>/dev/null | awk 'NR>2 && $1 !~ /^-+$/ {printf "%s ", $1}') "
  lim=" $(printf '%s' "$limited" | tr ',' ' ') "
  pick= last= out=
  [ -n "$am" ] || printf "note: --author has no model; the author's vendor %s counts as its model\n" "$ap" >&2
  for e in $2; do
    ep=${e%%:*}
    case "$never$lim" in *" $ep "*) out="$out $e"; continue ;; esac
    case $have in *" $ep "*) ;; *) out="$out $e"; continue ;; esac
    if { [ -n "$am" ] && [ "${e#*:}" = "$am" ]; } || { [ -z "$am" ] && [ "$ep" = "$ap" ]; }; then
      [ -n "$last" ] || last=$e; continue
    fi
    pick=$e; return
  done
  [ -n "$last" ] || die "spawn: no reviewer.order entry is available (unavailable:$out); wait for a reset, or pass --provider P --model ID"
  printf "note: every other Reviewer is unavailable (%s); the Reviewer runs on the author's %s (last resort; say so in the classification)\n" "${out# }" "$last" >&2
  pick=$last
}

# new_env_kind <project id>: the --new-environment kind the project supports.
# A Personal project (bb project show --json: "kind": "personal") has no git source, so bb accepts only
# a personal workspace there; every other project gets a git worktree.
new_env_kind() {
  k=$(bb project show "$1" --json 2>/dev/null | sed -n 's/^ *"kind": "\([^"]*\)".*$/\1/p' | head -1)
  case $k in
    personal) echo personal ;;
    standard) echo worktree ;;
    *) printf 'note: could not read the kind of project %s; assuming a worktree\n' "$1" >&2; echo worktree ;;
  esac
}

# brief_extra: the harness-owned part appended to a composed brief (modes, hold, context).
brief_extra() {
  printf '\n---\nThread setup (added by harness.sh; do not edit)\n\n'
  case $mode in
  spin-off)
    printf 'Origin: @thread:%s spun this thread off.\n' "$origin"
    if [ -n "$after_merge" ]; then
      printf 'Reporting: send the origin ONE message with `bb thread tell %s --message-file -` (your Report block on stdin) on each of these, and nothing else (no progress, no thanks):\n- DONE: only after your PR has merged, not when the work finishes.\n- BLOCKED: as soon as you are blocked.\n- FAILED: as soon as you fail.\n' "$origin"
    else
      printf 'Reporting: send the origin ONE message with `bb thread tell %s --message-file -` (your Report block on stdin) on each of these, and nothing else (no progress, no thanks):\n- DONE: when your work is finished.\n- BLOCKED: as soon as you are blocked.\n- FAILED: as soon as you fail.\n' "$origin"
    fi ;;
  fresh)
    printf 'Origin: @thread:%s started this thread.\n' "$origin"
    printf 'Reporting: none. Do not message the thread that started you; it is reference context and is not woken by you.\n' ;;
  esac
  case $ctx in
    none) ;;
    this) printf 'Context: the relevant context from @thread:%s is in the goal above; read that thread only if something is missing.\n' "$origin" ;;
    *) printf 'Context: reference only: @thread:%s. Read it for background; do not message it.\n' "$ctx" ;;
  esac
  if [ -n "$after" ]; then
    printf 'Hold: read and plan only; make no changes (no edits, commits, pushes or new threads) until you receive "go". It is released when @thread:%s is done: ' "$after"
    if [ -n "$after_tracked" ]; then printf '@thread:%s relays "go" to you.\n' "$origin"
    else printf '@thread:%s tells you "go" directly.\n' "$after"; fi
  elif [ -n "$wait_go" ]; then
    printf 'Hold: read and plan only; make no changes (no edits, commits, pushes or new threads) until the user says "go" in this thread'
    if [ "$mode" = fresh ]; then printf '.\n'; else printf ', or @thread:%s relays "go".\n' "$origin"; fi
  fi
}

spawn() {
  role= tier= effort= brief= slice= goal= isolated= prov= why= author= mod= limited=
  mode=child wait_go= after= ctx=this after_merge= force= project= host=
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
      --limited) limited=$2; shift ;;
      --why) why=$2; shift ;;
      --mode) mode=$2; shift ;;
      --after) after=$2; shift ;;
      --context) ctx=$2; shift ;;
      --project) project=$2; shift ;;
      --host) host=$2; shift ;;
      --wait-go) wait_go=1 ;;
      --report-after-merge) after_merge=1 ;;
      --force) force=1 ;;
      --isolated) isolated=1 ;;
      *) die "spawn: unknown argument $1" ;;
    esac; shift
  done
  case $mode in child|spin-off|fresh) ;; *) die "spawn: --mode is child | spin-off | fresh" ;; esac
  [ -z "$after_merge" ] || [ "$mode" = spin-off ] || die "spawn: --report-after-merge is for --mode spin-off only"
  [ -n "$effort" ] && [ -n "$brief" ] || die "spawn: --effort --brief are required"
  [ -f "$brief" ] || die "spawn: brief file not found: $brief"
  h=$(detect)
  if [ "$mode" = child ]; then
    [ -n "$role" ] || die "spawn: --role --effort --brief are required"
    card=$(role_tiers "$role")
    card_tier=${card% *}; max_tier=${card#* }
    if [ -z "$tier" ]; then
      [ -n "$card" ] || die "spawn: --tier is required for role '$role' (no role card)"
      tier=$card_tier
    fi
  else
    [ "$h" = bb ] || die "spawn: --mode $mode needs bb (top-level threads exist only there)"
    [ -n "$goal" ] || die "spawn: --mode $mode needs --goal \"<goal>\" (it becomes the thread title)"
    [ -n "$tier" ] || [ -n "$mod" ] || die "spawn: --mode $mode needs --tier T or --provider P --model ID (from the roster)"
    card=
    [ -n "$tier" ] || tier=balanced
  fi
  rank "$tier" >/dev/null
  [ -n "$slice" ] || slice=$(basename "$(dirname "$brief")")
  if [ "$mode" = child ]; then
    if [ -z "$goal" ]; then
      case $h in
        bb) goal=$(bb status --json 2>/dev/null | sed -n 's/^ *"title": "\(.*\)",*$/\1/p' | head -1) ;;
      esac
      [ -n "$goal" ] || goal=${WORKFLOW_TASK:-}
    fi
    if [ -n "$goal" ]; then title="$goal › $role · $slice"; else title="$role · $slice"; fi
  else
    title=$goal
  fi
  d=$(storage)
  # A slice spawned before whose report.md is missing is retried, not re-spawned (a duplicate thread).
  if [ "$mode" = child ] && [ -z "$force" ] && [ ! -f "$d/workers/$slice/report.md" ]; then
    prev=$(awk -F'\t' -v s="$slice" '$1 == s { id = $2; f = 1 } END { if (f) print (id == "" ? "-" : id) }' "$d/spawned.log" 2>/dev/null || true)
    if [ -n "$prev" ]; then
      [ "$prev" != - ] || prev='<id>'
      die "spawn: slice '$slice' was spawned before ($prev) and $d/workers/$slice/report.md is missing; run \`bb thread retry $prev\` on the earlier worker (--force spawns a new one anyway)"
    fi
  fi
  # Above the card's tier costs more on every turn: allowed, but only with a written reason.
  if [ -n "$card" ] && [ "$(rank "$tier")" -gt "$(rank "$max_tier")" ]; then
    [ -n "$why" ] || die "spawn: the $role card is $card_tier (up to $max_tier without a reason); --tier $tier needs --why \"<reason>\""
    printf "\nTier override: %s, above the card's %s — %s\n" "$tier" "$max_tier" "$why" >> "$brief"
    mkdir -p "$d"
    printf '%s\t%s\t%s\t%s\n' "$(date '+%F %T')" "$title" "$tier" "$why" >> "$d/tier-overrides.log"
    printf 'note: tier override logged to %s/tier-overrides.log\n' "$d" >&2
  fi
  origin=${BB_THREAD_ID:-}
  after_tracked=
  if [ -n "$after" ]; then
    [ "$mode" != fresh ] && grep -qF "| @thread:$after |" "$d/spin-offs.md" 2>/dev/null && after_tracked=1
  fi
  if [ "$ctx" = none ] && grep -Eqi '^[#*[:space:]-]*(context|reference)s?([*]*:|[[:space:]]*$)' "$brief"; then
    die "spawn: --context none, but $brief has a Context:/Reference: section; remove it (the goal only) or use --context this"
  fi
  # A composed brief = the agent's brief + the harness-owned setup block.
  if [ "$mode" != child ] || [ -n "$wait_go$after" ] || [ "$ctx" != this ]; then
    [ "$h" != bb ] || [ -n "$origin" ] || die "spawn: BB_THREAD_ID unset"
    mkdir -p "$d/briefs"
    sent=$d/briefs/$slice-$mode.md
    { cat "$brief"; brief_extra; } > "$sent"
    brief=$sent
  fi
  case $h in
  bb)
    p=$(provider bb)
    if [ -n "$prov" ]; then p=$prov
    elif [ "$(lower "$role")" = reviewer ] && [ -z "$mod" ]; then
      a=${author:-$(provider bb)}
      order=$(roster_rule reviewer.order)
      if [ -n "$order" ]; then
        pick_reviewer "$a" "$order"; p=${pick%%:*}; mod=${pick#*:}
      else
        # No roster order: fresh eyes from the vendor other than the code's author.
        a=${a%%:*}; p=$(other_provider "$a")
        if ! bb provider list 2>/dev/null | grep -qw "$p"; then
          printf "note: provider %s unavailable; the Reviewer runs on the author's vendor %s (say so in the classification)\n" "$p" "$a" >&2
          p=$a
        fi
      fi
    fi
    m=${mod:-$(model "$tier" "$p")}
    [ -n "$project" ] || project=${BB_PROJECT_ID:?BB_PROJECT_ID unset}
    set -- bb thread spawn --project "$project" --provider "$p" --model "$m" \
      --reasoning-level "$effort" --title "$title" --prompt-file "$brief" --permission-mode auto
    [ -z "$host" ] || set -- "$@" --host "$host"
    if [ "$mode" = child ]; then
      set -- "$@" --parent-self
      if [ -n "$isolated" ]; then set -- "$@" --new-environment "$(new_env_kind "$project")"
      else set -- "$@" --environment "${BB_ENVIRONMENT_ID:?BB_ENVIRONMENT_ID unset}"; fi
    else
      set -- "$@" --new-environment "$(new_env_kind "$project")"
    fi
    case $mode in
      child) word=Delegated place=child; rule="reports once when done, and on failure" ;;
      spin-off) word='Spun off' place=top-level
        if [ -n "$after_merge" ]; then rule="tells you DONE after merge, BLOCKED, FAILED"; else rule="tells you DONE, BLOCKED, FAILED"; fi ;;
      fresh) word='Started fresh' place=top-level; rule="never reports back" ;;
    esac
    case $ctx in none) cx='context: none' ;; this) cx='context: this thread' ;; *) cx="context: @thread:$ctx" ;; esac
    hold=
    if [ -n "$after" ]; then hold=" · after @thread:$after"
    elif [ -n "$wait_go" ]; then hold=" · waiting for your go"; fi
    if [ -n "$WORKFLOW_DRY_RUN" ]; then
      printf 'WORKFLOW_SPAWN=1 '; q "$@" --json
      [ "$mode" = child ] || printf 'brief: %s\n' "$brief"
      id='<new>'
      [ "$mode" != fresh ] || { printf 'WORKFLOW_SPAWN=1 '; q bb thread update "$origin" --parent-thread "$id" --parent-notifications off; }
      if [ -n "$after" ] && [ -z "$after_tracked" ]; then
        q bb thread tell "$after" "When your work is done, tell @thread:$id go"
      fi
      [ "$mode" != spin-off ] || printf 'ledger row (%s/spin-offs.md): %s\n' "$d" "| @thread:$id | $title | $(date '+%F %T') | $([ -n "$after_merge" ] && echo 'after merge' || echo done) | ${after:--} | running | - |"
    else
      mkdir -p "$d"
      out=$(WORKFLOW_SPAWN=1 "$@" --json)
      id=$(printf '%s\n' "$out" | sed -n 's/^ *"id": "\([^"]*\)".*$/\1/p' | head -1)
      if [ -z "$id" ]; then printf '%s\n' "$out"; die "spawn: could not read the new thread id from bb's output"; fi
      if [ "$mode" = child ]; then printf '%s\t%s\n' "$slice" "$id" >> "$d/spawned.log"; fi
      if [ "$mode" = fresh ]; then
        WORKFLOW_SPAWN=1 bb thread update "$origin" --parent-thread "$id" --parent-notifications off >/dev/null
      fi
      if [ -n "$after" ] && [ -z "$after_tracked" ]; then
        bb thread tell "$after" "When your work is done, tell @thread:$id go" >/dev/null
      fi
      if [ "$mode" = spin-off ]; then
        if [ ! -f "$d/spin-offs.md" ]; then
          printf '# Spin-offs\n\n| thread | title | started | trigger | waiting-on | status | last milestone |\n|---|---|---|---|---|---|---|\n' > "$d/spin-offs.md"
        fi
        printf '| @thread:%s | %s | %s | %s | %s | running | - |\n' "$id" "$title" "$(date '+%F %T')" "$([ -n "$after_merge" ] && echo 'after merge' || echo done)" "${after:--}" >> "$d/spin-offs.md"
      fi
    fi
    printf '%s → @thread:%s · %s · %s/%s · %s · %s%s · %s\n' "$word" "$id" "$place" "$p" "$m" "$effort" "$rule" "$hold" "$cx"
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

# adopt <id> [--quiet]: re-parent an existing thread under this one. It keeps its project, workspace and history; no thread is created.
adopt() {
  id= quiet=
  while [ $# -gt 0 ]; do
    case $1 in
      --quiet) quiet=1 ;;
      -*) die "adopt: unknown argument $1" ;;
      *) [ -z "$id" ] || die "adopt: one thread id only"; id=$1 ;;
    esac; shift
  done
  [ -n "$id" ] || die "adopt <id> [--quiet]"
  if [ "$(detect)" = bb ]; then
    [ -n "$BB_THREAD_ID" ] || die "adopt: BB_THREAD_ID unset"
    [ "$id" != "$BB_THREAD_ID" ] || die "adopt: a thread cannot adopt itself"
    n=auto; [ -z "$quiet" ] || n=off
    if [ -n "$WORKFLOW_DRY_RUN" ]; then q bb thread update "$id" --parent-thread "$BB_THREAD_ID" --parent-notifications "$n"
    else bb thread update "$id" --parent-thread "$BB_THREAD_ID" --parent-notifications "$n" >/dev/null; fi
    printf 'Adopted → @thread:%s · child · reports %s\n' "$id" "$([ -n "$quiet" ] && echo off || echo 'every outcome')"
  else
    printf 'adopt needs bb (threads and parents exist only there); here, treat %s as a worker you coordinate: ask it for its report and read it\n' "$id"
  fi
}

bb_or_print() {  # $1 = what to do outside bb; the rest = bb thread arguments
  msg=$1; shift
  case $(detect) in
    bb) bb thread "$@" ;;
    *) printf '%s\n' "$msg" ;;
  esac
}

# Warns (never blocks) when the worker being told has no report.md in its slice folder.
warn_no_report() {
  [ "$(detect)" = bb ] || return 0
  t=$(bb thread get "$1" --json 2>/dev/null | sed -n 's/^ *"title": "\(.*\)",*$/\1/p' | head -1)
  s=${t##* · }
  [ -n "$t" ] && [ "$s" != "$t" ] || return 0
  d=$(storage)/workers/$s
  if [ ! -d "$d" ]; then printf 'warning: %s does not exist, so worker %s (%s) has no report.md\n' "$d" "$1" "$s" >&2
  elif [ ! -f "$d/report.md" ]; then printf 'warning: %s has no report.md for worker %s (%s); it may not have finished\n' "$d" "$1" "$s" >&2
  fi
  return 0
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
  adopt) shift; adopt "$@" ;;
  wait) [ -n "$2" ] || die "wait <id>"; bb_or_print "end your turn; the completion notification wakes you (Claude Code: foreground Agent call; Codex: wait-agent tool)" wait "$2" ;;
  read) [ -n "$2" ] || die "read <id>"; bb_or_print "read the agent's final message" output "$2" ;;
  tell) [ -n "$2" ] && [ -n "$3" ] || die "tell <id> <message|->"
        warn_no_report "$2"
        msg="send the message with SendMessage (Claude Code) or send-message (Codex) to $2"
        if [ "$3" = - ]; then bb_or_print "$msg" tell "$2" --message-file -; else bb_or_print "$msg" tell "$2" "$3"; fi ;;
  install-guards) BACKUP_DIR=${BACKUP_DIR:-$(storage)/guards-backup} sh "$(dirname "$0")/install-guards.sh" ;;
  compact) [ -n "$2" ] || die "compact <id>"; bb_or_print "ask the user to run /compact in that agent, or let auto-compaction run" compact "$2"
           if [ "$(detect)" = bb ]; then echo "note: the next wake from $2 replays its last report; ignore it"; fi ;;
  ''|-h|--help|help) sed -n '2,31p' "$0" ;;
  *) die "unknown command: $1 (run harness.sh help)" ;;
esac
