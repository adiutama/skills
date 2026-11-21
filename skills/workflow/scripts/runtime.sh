#!/bin/sh
# runtime.sh — the workflow skill's runtime dictionary and wrapper.
# Each glossary term is a subcommand. Under bb the action runs; under a runtime
# where the action is a tool call the shell cannot make, the exact tool
# parameters are printed instead. The agent never reads a table.
#
#   runtime.sh terms                      the runtime, then every term with its meaning here
#   runtime.sh model work|helper [provider]   built-in model id: work = the vendor's deep model, helper = its fast model
#   runtime.sh providers                  enabled providers and their model ids (built-in defaults outside bb)
#   runtime.sh roster                     the user's agent roster (bb: the agent-roster-v2 memory, else the 1.x agent-roster; elsewhere: none, use built-in defaults);
#       stderr: `stale: …` for the 1.x memory, an old-format roster or a model missing from providers (never entries are not checked)
#   runtime.sh roster-save                save the roster from stdin (bb: update the global pinned memory agent-roster-v2, or add it if absent; agent-roster is never
#       written, so 1.x threads keep it; elsewhere: not stored). WORKFLOW_ROSTER_NAME overrides the memory name (tests)
#   runtime.sh storage                    this agent's storage directory
#   runtime.sh context [id]               context reading (self, or a worker's)
#   runtime.sh title "<goal>"             set this thread's title to the goal, before the first spawn
#   runtime.sh spawn --role R --effort E --brief FILE [--slice S] [--goal G] [--isolated] [--helper] [--provider P] [--model ID]
#       the model comes from the role card (work | helper) through the roster's work/helper line, else the built-in default;
#       --helper puts a work-card role on the helper model (mechanical edits); --provider/--model override both
#       --role council-chair --author P:ID [--size 2|3] [--limited P,...]: the first roster council entry that is not the author's model
#       (through any provider), whose provider and family (the model's maker) are not in never, and whose provider is not --limited
#       or missing; --size (default 2) is recorded in the chair's brief
#       --role council-member --author P:ID --chair P:ID [--limited P,...] (from a chair; outside bb from the main thread): the next
#       such entry whose family differs from the chair's and every existing member's; if none, the next whose model is not seated
#       yet (same family, marked "same family as chair|<member>"); never a seated model; skipping seats logged failed; at most
#       size-1 members; none left → exit 1; with no member at all the verdict is marked "council: 1 of <size>"
#       --provider/--model on a council role pass the same checks. The seat is reserved in council.log under a lock before the launch;
#       a failed bb launch is reported, logged failed, and the next eligible seat is tried. A pending seat whose spawn died stays
#       taken until the chair's children show its thread (the seat gets its id) or its absence (lost). Council roles run in auto;
#       under bb a provider that lists no auto mode (bb provider list --json) holds no seat: skipped, reported, logged no-auto
#       (a smaller council, never full). Other workers: auto where listed, else the first listed mode
#       nesting: a council member spawns nothing; a chair spawns only council members; only a chair (outside bb: anyone naming --chair)
#       spawns members. Under bb the role is read from this thread's title (set at creation): any " › " segment starting "Council
#       member · " or "Council chair · " (member wins), with the marker as a second signal; title unreadable and no marker → exit 1
#       title = "<goal> › <Role> · <slice>" (council roles: "Council chair" | "Council member"); goal defaults to this thread's title (bb) or $WORKFLOW_TASK; slice to the brief folder
#       --mode child|spin-off|fresh (default child): spin-off and fresh make a top-level thread in its own worktree (no --role; need --goal; the work model unless --helper or --provider/--model)
#       --env this|new|<environment id> (spin-off, fresh): this = $BB_ENVIRONMENT_ID, new = a new worktree/personal workspace; default fresh=this, spin-off=new; child uses --isolated instead
#       --wait-go · --after <thread id> · --context none|this|<thread id> · --report-after-merge (spin-off) · --force (re-spawn a slice with no report.md) · --project <id> · --host <id-or-name> (the machine to run on; passed to bb thread spawn as --host)
#       prints the receipt line; WORKFLOW_DRY_RUN=1 prints the commands for every mode
#   runtime.sh council-stop [chair id]    end a council: in a chair, stop its members (council.log); with an id, stop that chair's children, then the chair. Elsewhere: prints the instruction
#   runtime.sh adopt <id> [--quiet]       make an existing thread a child of this one (bb: bb thread update <id> --parent-thread <this>; --quiet adds --parent-notifications off); prints the receipt. Elsewhere: prints the equivalent instruction
#   runtime.sh release <id>               make a child thread top-level again (bb: bb thread update <id> --clear-parent-thread); prints the receipt. Elsewhere: prints that release needs bb
#   runtime.sh wait <id>                  wait for a worker
#   runtime.sh read <id>                  a worker's report
#   runtime.sh tell <id> <message|->       message a worker (- reads stdin); warns on stderr when its report.md or storage folder is missing
#   runtime.sh install-guards            install the spawn guard for Claude Code, Codex and opencode on this machine (idempotent; backs up edited files; skips agents that are not installed)
#   runtime.sh compact <id>               compact an idle worker (bb: its next wake is a replay)
#   runtime.sh help [command]             this header, or the usage and flags of one command
#
# Override detection with WORKFLOW_RUNTIME=codex (Codex has no env signal).
# WORKFLOW_HARNESS (the old name) is still accepted as a fallback.
set -e

die() { printf '%s\n' "$*" >&2; exit 1; }

detect() {
  if [ -n "$WORKFLOW_RUNTIME" ]; then printf '%s\n' "$WORKFLOW_RUNTIME"
  elif [ -n "$WORKFLOW_HARNESS" ]; then printf '%s\n' "$WORKFLOW_HARNESS"  # old name, accepted until the next major release
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
  kind=$1; p=${2:-$(provider)}
  case "$p:$kind" in
    claude-code:helper) echo haiku ;;
    claude-code:work) echo opus ;;
    codex:helper) echo gpt-6-luna ;;
    codex:work) echo gpt-6.2-sol ;;
    claude-code:*|codex:*) die "unknown model kind '$kind' (work | helper; tiers were removed in workflow 2.0.0)" ;;
    *) die "no built-in model for provider '$p'; pass --model <id> (runtime.sh providers lists ids)" ;;
  esac
}

providers() {
  if [ "$(detect)" != bb ]; then
    echo "note: not under bb; these are the built-in defaults, not discovered"
    for k in work helper; do
      printf '%-7s claude-code:%s  codex:%s\n' "$k" "$(model $k claude-code)" "$(model $k codex)"
    done
    return
  fi
  for id in $(provider_ids); do
    printf '%s\n' "$id"
    provider_models "$id" | sed 's/^/  /'
  done
}

provider_ids() { bb provider list 2>/dev/null | awk 'NR>2 && $1 !~ /^-+$/ {print $1}'; }
provider_models() { bb provider models "$1" --json 2>/dev/null | sed -n 's/^    "id": "\(.*\)",*$/\1/p'; }

# The v2 roster has its own memory, so 1.x threads keep reading agent-roster unchanged; v2 falls back to that one, warning stale.
roster_name=${WORKFLOW_ROSTER_NAME:-agent-roster-v2}
roster_legacy=agent-roster; [ -z "$WORKFLOW_ROSTER_NAME" ] || roster_legacy=

# roster_find [name]: the memory JSON whose name is exactly that (default: the roster name), else nothing.
roster_find() {
  n_=${1:-$roster_name}
  for id in $(bb memory search "$n_" --scope global --json 2>/dev/null | sed -n 's/^      "id": "\(.*\)",*$/\1/p'); do
    j=$(bb memory get "$id" --json 2>/dev/null) || continue
    if printf '%s\n' "$j" | grep -q "^    \"name\": \"$n_\","; then printf '%s\n' "$j"; return; fi
  done
}

# roster_text: the roster rules (bb: the memory's details; agent-roster when agent-roster-v2 is absent), else nothing.
roster_text() {
  [ "$(detect)" = bb ] || return 0
  j=$(roster_find)
  [ -n "$j" ] || [ -z "$roster_legacy" ] || j=$(roster_find "$roster_legacy")
  [ -n "$j" ] || return 0
  printf '%s\n' "$j" | sed -n 's/^    "details": "\(.*\)",*$/\1/p' | sed 's/\\n/\n/g'
}

roster() {
  if [ "$(detect)" != bb ]; then
    echo "none: no roster storage here; use the built-in defaults (runtime.sh model work|helper)"
    return
  fi
  txt=$(roster_text)
  if [ -z "$txt" ]; then echo "none: no $roster_name${roster_legacy:+ or $roster_legacy} memory; use the built-in defaults"; return; fi
  printf '%s\n' "$txt"
  if [ -n "$roster_legacy" ] && [ -z "$(roster_find)" ]; then
    echo "stale: no $roster_name memory; read $roster_legacy (the 1.x roster; its tier./role./reviewer. lines are ignored); suggest a v2 roster and save it with roster-save" >&2
  fi
  if printf '%s\n' "$txt" | grep -Eq '^[[:space:]]*(tier|role|reviewer)\.'; then
    echo "stale: old roster format (tier./role./reviewer. lines); suggest a v2 roster" >&2
  fi
  roster_check "$txt" >&2
}

# roster_check <rules>: prints `stale: …` for each work/helper/council model, and each fallback provider, that providers does not list.
roster_check() {
  have=" $(provider_ids | tr '\n' ' ') "
  for e in $(printf '%s\n' "$1" | awk '$1 == "work" || $1 == "helper" || $1 == "council" { for (i = 2; i <= NF; i++) print $i }'); do
    ep=${e%%:*}
    case $have in *" $ep "*) ;; *) echo "stale: $e not in providers"; continue ;; esac
    provider_models "$ep" | grep -qxF "$(bb_model_id "${e#*:}")" || echo "stale: $e not in providers"
  done
  for e in $(printf '%s\n' "$1" | awk '$1 == "fallback" { for (i = 2; i <= NF; i++) print $i }'); do
    for ep in "${e%%>*}" "${e#*>}"; do
      case $have in *" $ep "*) ;; *) echo "stale: fallback $ep not in providers" ;; esac
    done
  done
}

roster_save() {
  if [ "$(detect)" != bb ]; then echo "not stored: no roster storage here"; return; fi
  body=$(cat)
  [ -n "$body" ] || die "roster-save reads the roster rules on stdin"
  summary="User's agent roster (v2): the work, helper and council models, vendors that never review, and fallback providers; read by the workflow skill at planning."
  j=$(roster_find)
  if [ -n "$j" ]; then
    id=$(printf '%s\n' "$j" | sed -n 's/^    "id": "\(.*\)",*$/\1/p' | head -1)
    ver=$(printf '%s\n' "$j" | sed -n 's/^    "version": \([0-9]*\),*$/\1/p' | head -1)
    bb memory update "$id" --expected-version "$ver" --summary "$summary" --details "$body" --reason "The user agreed a new roster."
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
  printf 'runtime     %s\n' "$h"
  case $h in
  bb) cat <<'EOF'
worker      a child bb thread; spawn it with: runtime.sh spawn
spawn       runtime.sh spawn --role R --effort E --brief FILE [--slice S] [--isolated] [--helper]; the model is the roster's work or helper model, as the role card says (--helper: a work card on the helper model); a council: --role council-chair --author P:ID [--size 2|3] [--limited P,...] (the chair then spawns its members with --role council-member); the runtime links it to you as parent
nesting     one helper per worker for its own lookup; a council chair spawns its members, one level deep; members never spawn (runtime.sh refuses); never a coordinator under a coordinator (every child turn wakes its parent)
helper      the Agent tool (Claude Code hosted), only for a read-only lookup of your own: subagent_type "Explore", model "haiku"; any other job is a worker (mechanical edits: a worker with --helper)
wait        end your turn: each child's turn end wakes you with its result (runtime.sh wait <id> only within the shell time limit)
read        runtime.sh read <id>
tell        runtime.sh tell <id> <message|->
link        @thread:<id>
isolation   --isolated on spawn gives the worker its own worktree
storage     runtime.sh storage (a worker's: the Storage: path in its brief)
compact     a worker: runtime.sh compact <id>, in the same command as your next tell to it; its next wake replays its last report; yourself: ask the user to run /compact, or let auto-compaction run
wake tool   Claude Code: Monitor, ScheduleWakeup, a background shell command that re-invokes you; Codex: none. Each firing ends your turn and wakes your parent
permission  workers: auto where the provider lists it; council roles: auto, and a provider without auto holds no council seat (never full); denials become blockers
context     runtime.sh context [id]
spawn cost  a full new session
auto branch bb/<title>-<thread id>, the branch bb names a new worktree; never push it
EOF
  ;;
  claude-code) cat <<'EOF'
worker      a subagent (Agent tool)
spawn       runtime.sh spawn ... prints the Agent tool parameters (Explorer: Explore subagent on haiku); the model comes from the role card (work | helper); the brief's contents are the prompt; a council's members are spawned by you with --chair (no nesting)
wait        a foreground Agent call, or its completion notification
read        the agent's final message
tell        SendMessage to the agent ID
link        the agent ID; the main session is main
nesting     usually no
isolation   Agent isolation: "worktree"
storage     runtime.sh storage
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
spawn       runtime.sh spawn ... prints the spawn-agent parameters; non-forked context; the brief's contents are the prompt; a council's members are spawned by you with --chair
wait        wait-agent tool; repeat after a timeout
read        the agent's final report
tell        send-message / follow-up tool with the agent ID
link        the agent ID; the main session is main
nesting     yes if the worker has the spawn tool; pairing only, never a coordinator under a coordinator
isolation   none: one shared working directory; parallelize only disjoint writes
storage     runtime.sh storage
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
storage     runtime.sh storage
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

# role_model <role> → the card's model kind (work | helper); empty for roles without a card.
role_model() {
  case $(lower "$1") in
    explorer) echo helper ;;
    researcher|prototyper|designer|implementer|tester|architect|council-chair|council-member) echo work ;;
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

# bb_model_id <id>: bb rejects the short Claude aliases; map them to full ids, pass anything else through.
bb_model_id() {
  case $1 in
    haiku) echo claude-haiku-5-5 ;;
    sonnet) echo claude-sonnet-5-5 ;;
    opus) echo claude-opus-5-5 ;;
    fable) echo claude-fable-5-2 ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# cc_alias <id>: the Agent tool takes the short Claude aliases; map full ids back, pass anything else through.
cc_alias() {
  case $1 in
    claude-haiku-5-5) echo haiku ;;
    claude-sonnet-5-5) echo sonnet ;;
    claude-opus-5-5) echo opus ;;
    claude-fable-5-2) echo fable ;;
    *) printf '%s\n' "$1" ;;
  esac
}

other_provider() { if [ "$1" = codex ]; then echo claude-code; else echo codex; fi; }

# roster_rule <key>: the entries of that roster line (bb only), else nothing. Old-format keys (tier.*, role.*, reviewer.*) are never read.
roster_rule() {
  [ "$(detect)" = bb ] || return 0
  roster_text 2>/dev/null | awk -v k="$1" '$1 == k { $1 = ""; sub(/^ +/, ""); print; exit }'
}

# kind_model <work|helper>: <provider>:<model> from the roster line, else this vendor's built-in model.
kind_model() {
  e=$(roster_rule "$1"); e=${e%% *}
  if [ -n "$e" ]; then printf '%s\n' "$e"; else p0=$(provider); printf '%s:%s\n' "$p0" "$(model "$1" "$p0")"; fi
}

# council_list: the roster's council line, else the other built-in vendor's work model, then this vendor's, then this vendor's
# second model (so a one-vendor runtime still has a chair when the author used the work model).
council_list() {
  c=$(roster_rule council)
  if [ -n "$c" ]; then printf '%s\n' "$c"; return; fi
  p0=$(provider); o=$(other_provider "$p0")
  # This vendor's other models follow, so a one-vendor runtime still seats two distinct models (same family).
  if [ "$p0" = codex ]; then a0="gpt-6.2-astra gpt-6-luna"; else a0="fable sonnet"; fi
  printf '%s:%s %s:%s' "$o" "$(model work "$o")" "$p0" "$(model work "$p0")"
  for x in $a0; do printf ' %s:%s' "$p0" "$x"; done; echo
}

# have_providers: the providers a spawn can use here (bb: bb provider list; elsewhere only this vendor).
have_providers() {
  if [ "$(detect)" = bb ]; then provider_ids | tr '\n' ' '; else provider; fi
}

# family <P:ID>: the model's maker, from the model id with any "<vendor>/" prefix stripped; unknown → the provider id.
# One provider can serve many makers (acp-opencode), so the provider alone does not say whose model it is.
family() {
  n=$(lower "${1#*:}"); n=${n##*/}
  case $n in
    claude*|opus*|sonnet*|haiku*|fable*) echo anthropic ;;
    gpt*|o[0-9]*|codex*|chatgpt*) echo openai ;;
    gemini*|gemma*) echo google ;;
    grok*) echo xai ;;
    glm*) echo zhipu ;;
    kimi*) echo moonshot ;;
    deepseek*) echo deepseek ;;
    qwen*) echo alibaba ;;
    mistral*|codestral*|devstral*) echo mistral ;;
    llama*) echo meta ;;
    *) printf '%s\n' "${1%%:*}" ;;
  esac
}

# same_model <ID>: the model's own name, Claude aliases mapped and any "<vendor>/" prefix stripped, to compare across providers.
same_model() { n=$(bb_model_id "$1"); printf '%s\n' "${n##*/}"; }

# council_ctx <author P:ID> <taken P:ID ...>: sets what council_ok checks against, once per pick.
council_ctx() {
  am=$(same_model "${1#*:}"); tf_=" " tm_=" " fam_=1
  for x in $2; do tf_="$tf_$(family "$x") "; tm_="$tm_$(same_model "${x#*:}") "; done
  never=" $(roster_rule never) "
  lim=" $(printf '%s' "$limited" | tr ',' ' ') "
  have=" $(have_providers) "
  # A council seat runs in auto (it must run git, rg and tests unprompted, and is never given full): under bb, a provider
  # that lists no auto permission mode holds no seat. An unreadable provider list leaves none eligible.
  auto_=; [ "$(detect)" != bb ] || auto_=" $(auto_providers) "
}

# auto_providers: the bb providers whose permission modes include auto (bb provider list --json).
auto_providers() {
  bb provider list --json 2>/dev/null | awk '
    /^    "id": "/ { cur = $0; sub(/^    "id": "/, "", cur); sub(/".*$/, "", cur) }
    /"permissionModes"/ { f = 1; next }
    f && /\]/ { f = 0 }
    f && /"auto"/ { print cur }' | tr '\n' ' '
}

# council_ok <P:ID> [failed P:ID ...]: eligible after council_ctx: its seat has not failed, neither its provider nor its family
# is in never, its provider is not --limited and is present, it is not the author's model (through any provider), and its
# family differs from every taken entry (the chair and existing members). Else appends the reason to why= and returns 1.
council_ok() {
  e=$1; ep=${e%%:*}; ef=$(family "$e")
  case " $2 " in *" $e "*) why="$why $e(failed)"; return 1 ;; esac
  case "$never" in *" $ep "*|*" $ef "*) why="$why $e(never)"; return 1 ;; esac
  case "$lim" in *" $ep "*) why="$why $e(limited)"; return 1 ;; esac
  case $have in *" $ep "*) ;; *) why="$why $e(missing)"; return 1 ;; esac
  case "${auto_:- $ep }" in *" $ep "*) ;; *) why="$why $e(no auto mode)"; noauto_="$noauto_ $e"; return 1 ;; esac
  [ "$(same_model "${e#*:}")" != "$am" ] || { why="$why $e(author)"; return 1; }
  case "$tm_" in *" $(same_model "${e#*:}") "*) why="$why $e(seated)"; return 1 ;; esac
  [ -z "$fam_" ] || case "$tf_" in *" $ef "*) why="$why $e(family $ef taken)"; return 1 ;; esac
}

# council_pick <author P:ID> <taken P:ID ...> [failed P:ID ...]: sets pick= to the first eligible council entry
# (council_ok). Returns 1 when none is left; why= lists what was skipped.
# Two passes: first an entry of a family not yet seated; if none, any entry whose model is not seated yet (same family allowed;
# same_ names the seat it shares a family with). A model is never seated twice.
council_pick() {
  council_ctx "$1" "$2"; pick= why= same_=
  council_walk "$3" && return 0
  [ -n "$2" ] || return 1
  fam_=; why=
  council_walk "$3" || return 1
  same_=$(same_as "$pick" "$2")
}
council_walk() {
  for e in $(council_list); do
    council_ok "$e" "$1" || continue
    pick=$e; return 0
  done
  return 1
}
# same_as <P:ID> <seated P:ID ...>: "same family as chair" or "same family as <member>" for the first seat sharing its family.
same_as() {
  f_=$(family "$1"); for x in $2; do
    [ "$(family "$x")" = "$f_" ] || continue
    if [ "$x" = "$chair" ]; then echo "same family as chair"; else echo "same family as $x"; fi; return 0
  done
}

# The member seats live in council.log (<chair>\t<member>\t<thread id | - | pending:<pid>:<slice> | failed | no-auto | lost>). A
# spawn reserves its seat (pending) under the lock before the launch, so concurrent spawns see it; the launch then replaces it
# with the id, or failed.
council_lock() {
  l_=$cdir/.council.lock; i_=0
  until mkdir "$l_" 2>/dev/null; do
    o_=$(cat "$l_/pid" 2>/dev/null || true)
    if [ -n "$o_" ] && ! kill -0 "$o_" 2>/dev/null; then rm -rf "$l_"; continue; fi
    i_=$((i_ + 1)); [ $i_ -lt 30 ] || die "spawn: $l_ is held by another member spawn; remove it if none is running"
    sleep 1
  done
  echo $$ > "$l_/pid"
}
council_unlock() { rm -rf "$cdir/.council.lock"; }

# council_seats taken|failed: the member entries of this chair that hold a seat (an id, -, or pending), or that hold none and are
# skipped (failed: the launch failed; no-auto: the provider lists no auto mode). A lost seat (see council_reconcile) is neither.
council_seats() {
  awk -F'\t' -v c="$chair" -v w="$1" '$1 == c && $3 != "lost" && (w == "failed") == ($3 == "failed" || $3 == "no-auto") { print $2 }' \
    "$cdir/council.log" 2>/dev/null || true
}

# council_reconcile (under the lock, bb only): a pending seat (pending:<pid>:<slice>) whose spawn wrapper died may still have
# launched its thread. It keeps its seat unless the chair's live children prove otherwise: a child titled "… Council member ·
# <slice>" that is not logged yet turns the seat into that thread's id; no such child turns it into lost (no seat, not skipped).
# If the children cannot be listed, the seat stays pending, so it still counts toward the size and its family.
council_reconcile() {
  [ "$h" = bb ] && [ -n "$BB_THREAD_ID" ] || return 0
  dead_=$(awk -F'\t' -v c="$chair" '$1 == c && $3 ~ /^pending:[0-9]+:/ { print $3 }' "$cdir/council.log" 2>/dev/null |
    while IFS= read -r k_; do p_=${k_#pending:}; kill -0 "${p_%%:*}" 2>/dev/null || printf '%s\n' "$k_"; done)
  [ -n "$dead_" ] || return 0
  kids_=$(bb thread list --parent-thread "$BB_THREAD_ID" --json 2>/dev/null) || return 0
  case $kids_ in '['*) ;; *) return 0 ;; esac
  printf '%s\n' "$dead_" | while IFS= read -r k_; do
    s_="Council member · ${k_#pending:*:}"
    id_=$(printf '%s\n' "$kids_" | awk -v s="$s_" '
      /^    "id": "/ { id = $0; sub(/^    "id": "/, "", id); sub(/".*$/, "", id) }
      /^    "title": "/ { t = $0; sub(/^    "title": "/, "", t); sub(/",*$/, "", t)
        if (length(t) >= length(s) && substr(t, length(t) - length(s) + 1) == s) print id }' |
      while IFS= read -r i_; do cut -f3 "$cdir/council.log" | grep -qxF "$i_" || { printf '%s\n' "$i_"; break; }; done)
    awk -F'\t' -v OFS='\t' -v k="$k_" -v v="${id_:-lost}" '$3 == k { $3 = v } { print }' "$cdir/council.log" > "$cdir/council.log.$$" &&
      mv "$cdir/council.log.$$" "$cdir/council.log"
  done
}

# noauto_report: name each seat skipped for lacking auto (stderr) and, when reserving, log it once as no-auto.
noauto_report() {
  for e_ in $noauto_; do
    printf 'spawn: skipped %s: %s lists no auto permission mode (a council seat runs in auto, never full); the council may be smaller\n' "$e_" "${e_%%:*}" >&2
    [ -n "$rs_" ] || continue
    awk -F'\t' -v c="$chair" -v m="$e_" '$1 == c && $2 == m && $3 == "no-auto" { f = 1 } END { exit !f }' "$cdir/council.log" 2>/dev/null ||
      printf '%s\t%s\tno-auto\n' "$chair" "$e_" >> "$cdir/council.log"
  done
}

# council_seat <token> <value>: rewrite this spawn's reserved seat (its pending token) to the new thread id, - or failed.
council_seat() {
  council_lock
  awk -F'\t' -v OFS='\t' -v k="$1" -v v="$2" '$3 == k { $3 = v } { print }' "$cdir/council.log" > "$cdir/council.log.$$" &&
    mv "$cdir/council.log.$$" "$cdir/council.log"
  council_unlock
}

# council_choose: sets cmodel= for this launch. A chair: the explicit model if eligible, else the first eligible entry not yet
# failed in this run. A member: the same, against the chair and its seated members, skipping failed seats; the seat is
# reserved in council.log (tok=) unless this is a dry run.
council_choose() {
  why= noauto_= rs_= same_=
  if [ "$council" = council-chair ]; then
    if [ -n "$explicit" ]; then
      council_ctx "$author" ""; council_ok "$explicit" "$failed" || { noauto_report; die "spawn: $explicit cannot chair this council (skipped:$why)"; }
      cmodel=$explicit
    else
      if council_pick "$author" "" "$failed"; then rc_=0; else rc_=1; fi; noauto_report
      [ "$rc_" = 0 ] || die "spawn: no council model is eligible to chair (skipped:$why); wait for a reset, or pass --provider P --model ID"
      cmodel=$pick
    fi
    return 0
  fi
  [ -n "$WORKFLOW_DRY_RUN" ] || { rs_=1; council_lock; council_reconcile; }
  members=$(council_seats taken); n=$(printf '%s\n' "$members" | grep -c . || true)
  if [ "$n" -ge $((size - 1)) ]; then
    [ -z "$rs_" ] || council_unlock
    die "spawn: the council is full: size $size = the chair and $n member(s) ($cdir/council.log; a pending seat whose spawn died is kept until the chair's children show whether its thread exists)"
  fi
  fs_="$failed $(council_seats failed | tr '\n' ' ')"
  if [ -n "$explicit" ]; then
    # An explicit model passes the same checks; a family already seated only when no entry of a new family is eligible.
    council_ctx "$author" "$chair $members"; fam_=
    council_ok "$explicit" "$fs_" || { noauto_report; [ -z "$rs_" ] || council_unlock; die "spawn: $explicit cannot sit on this council (skipped:$why)"; }
    case "$tf_" in *" $(family "$explicit") "*)
      fam_=1; w_=$why
      if council_walk "$fs_"; then
        [ -z "$rs_" ] || council_unlock
        die "spawn: $explicit cannot sit on this council (skipped:$w_ $explicit(family $(family "$explicit") taken; $pick is a new family))"
      fi
      same_=$(same_as "$explicit" "$chair $members") ;;
    esac
    cmodel=$explicit
  elif council_pick "$author" "$chair $members" "$fs_"; then
    cmodel=$pick; noauto_report
  else
    noauto_report; [ -z "$rs_" ] || council_unlock
    if [ "$n" = 0 ]; then
      die "spawn: no council model left for a member (skipped:$why); rule alone: mark the verdict \"council: 1 of $size\", which the main thread tells the user"
    fi
    die "spawn: no council model left for a member (skipped:$why); rule with fewer members ($((n + 1)) of $size seats) and name the gap under Council: missing"
  fi
  [ -z "$same_" ] || printf 'spawn: no model of a new family is eligible; seating %s, %s (mark it on the verdict Council line)\n' "$cmodel" "$same_" >&2
  if [ -n "$rs_" ]; then
    tok=pending:$$:$slice; printf '%s\t%s\t%s\n' "$chair" "$cmodel" "$tok" >> "$cdir/council.log"
    council_unlock
  fi
}

# perm_mode <provider> <mode ...>: the first of the modes the provider lists (bb provider list --json), else the first given.
perm_mode() {
  pv_=$1; shift
  ms_=" $(bb provider list --json 2>/dev/null | awk -v p="$pv_" '
    /^    "id": "/ { cur = ($0 ~ "^    \"id\": \"" p "\"") }
    cur && /"permissionModes"/ { f = 1; next }
    f && /\]/ { f = 0 }
    f && cur { gsub(/[ ",]/, ""); print }' | tr '\n' ' ') "
  for x in "$@"; do case $ms_ in *" $x "*) echo "$x"; return ;; esac; done
  echo "$1"
}

# self_council: council-member | council-chair | unknown, from this bb thread's own title, which bb sets when it creates the
# thread (spawn --title), so it holds before the spawn that made it returns. spawn titles a council role "<parent title> ›
# Council member · <slice>" (or Council chair); any " › " segment starting that way counts, whatever is appended after it, and
# member wins over chair (a member's parent title holds its chair's segment). unknown: bb could not be asked or gave no title
# field; the guards then refuse to spawn unless a marker exists.
self_council() {
  [ "$(detect)" = bb ] && [ -n "$BB_THREAD_ID" ] || return 0
  j_=$(bb thread get "$BB_THREAD_ID" --json 2>/dev/null) || { echo unknown; return 0; }
  printf '%s\n' "$j_" | grep -q '^ *"title": ' || { echo unknown; return 0; }
  printf '%s\n' "$j_" | sed -n 's/^ *"title": "\(.*\)",*$/\1/p' | head -1 | awk -F' › ' '{
    for (i = 1; i <= NF; i++) { if ($i ~ /^Council member · /) m = 1; else if ($i ~ /^Council chair · /) c = 1 }
    if (m) print "council-member"; else if (c) print "council-chair" }'
}

# mget <file> <key>: the value of a `key value` line in a council marker.
mget() { awk -v k="$2" '$1 == k { print $2; exit }' "$1" 2>/dev/null; }

# council_dir <chair P:ID>: the folder holding this council's .council-chair marker and council.log.
# In a chair: its own storage. Outside bb (the main thread spawns members): the newest workers/*/ folder whose marker names that chair.
council_dir() {
  if [ -f "$me/.council-chair" ]; then printf '%s\n' "$me"; return; fi
  [ "$(detect)" != bb ] || return 0
  ls -t "$me"/workers/*/.council-chair 2>/dev/null | while IFS= read -r f; do
    if [ "$(mget "$f" chair)" = "$1" ]; then dirname "$f"; break; fi
  done
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

# brief_extra: the runtime-owned part appended to a composed brief (modes, hold, context).
brief_extra() {
  printf '\n---\nThread setup (added by runtime.sh; do not edit)\n\n'
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
  role= effort= brief= slice= goal= isolated= prov= author= mod= limited= helper= size= chair=
  mode=child wait_go= after= ctx=this after_merge= force= project= host= env=
  while [ $# -gt 0 ]; do
    case $1 in
      --role) role=$2; shift ;;
      --effort) effort=$2; shift ;;
      --brief) brief=$2; shift ;;
      --slice) slice=$2; shift ;;
      --goal) goal=$2; shift ;;
      --provider) prov=$2; shift ;;
      --model) mod=$2; shift ;;
      --author) author=$2; shift ;;
      --limited) limited=$2; shift ;;
      --size) size=$2; shift ;;
      --chair) chair=$2; shift ;;
      --mode) mode=$2; shift ;;
      --after) after=$2; shift ;;
      --context) ctx=$2; shift ;;
      --project) project=$2; shift ;;
      --host) host=$2; shift ;;
      --env) env=$2; shift ;;
      --helper) helper=1 ;;
      --wait-go) wait_go=1 ;;
      --report-after-merge) after_merge=1 ;;
      --force) force=1 ;;
      --isolated) isolated=1 ;;
      --tier|--why) die "spawn: $1 was removed in workflow 2.0.0; the model comes from the role card (work | helper) and the roster: --helper for mechanical edits, --provider P --model ID to override" ;;
      *) die "spawn: unknown argument $1" ;;
    esac; shift
  done
  case $mode in child|spin-off|fresh) ;; *) die "spawn: --mode is child | spin-off | fresh" ;; esac
  [ -z "$after_merge" ] || [ "$mode" = spin-off ] || die "spawn: --report-after-merge is for --mode spin-off only"
  # Environment: fresh silences this thread, so reusing its environment is safe; a spin-off keeps both working, so it gets a new one.
  if [ "$mode" = child ]; then
    [ -z "$env" ] || die "spawn: --env is for --mode spin-off|fresh; a child reuses this environment, --isolated gives it a new one"
  elif [ -z "$env" ]; then
    if [ "$mode" = fresh ]; then env=this; else env=new; fi
  fi
  [ -n "$effort" ] && [ -n "$brief" ] || die "spawn: --effort --brief are required"
  [ -f "$brief" ] || die "spawn: brief file not found: $brief"
  h=$(detect)
  d=$(storage); me=$d
  rl=$(lower "$role")
  # Nesting guards: a council stays one level deep (SKILL.md, Verify). Under bb the role is in this thread's title from the moment
  # bb creates it (spawn --title), so it holds before the marker the spawn writes once it returns; the marker is a second signal.
  self_role=$(self_council)
  if [ "$self_role" = unknown ] && [ ! -f "$me/.council-member" ] && [ ! -f "$me/.council-chair" ]; then
    die "spawn: this thread's council role is unknown (bb thread get $BB_THREAD_ID failed or gave no title) and it has no marker; refusing to spawn until bb answers"
  fi
  if [ -f "$me/.council-member" ] || [ "$self_role" = council-member ]; then
    die "spawn: a council member never spawns ($me is a council member); review alone and answer the chair"
  fi
  if { [ -f "$me/.council-chair" ] || [ "$self_role" = council-chair ]; } && { [ "$mode" != child ] || [ "$rl" != council-member ]; }; then
    die "spawn: a council chair spawns only --role council-member ($me is a council chair)"
  fi
  council=
  [ "$mode" != child ] || case $rl in council-chair|council-member) council=$rl ;; esac
  [ -z "$size" ] || [ "$council" = council-chair ] || die "spawn: --size is for --role council-chair"
  [ -z "$chair" ] || [ "$council" = council-member ] || die "spawn: --chair is for --role council-member"
  [ -z "$author$limited" ] || [ -n "$council" ] || die "spawn: --author and --limited are for --role council-chair|council-member"
  if [ "$mode" = child ]; then
    [ -n "$role" ] || die "spawn: --role --effort --brief are required"
    kind=$(role_model "$role")
    if [ -z "$kind" ]; then
      case $rl in
        reviewer) die "spawn: the Reviewer role is now a council: --role council-chair --author P:ID [--size 2|3]" ;;
        consultant) die "spawn: the Consultant role was removed; ask the council instead (--role council-chair)" ;;
      esac
      [ -n "$mod" ] || die "spawn: role '$role' has no card; pass --model ID (and --provider P)"
      kind=work
    fi
  else
    [ "$h" = bb ] || die "spawn: --mode $mode needs bb (top-level threads exist only there)"
    [ -n "$goal" ] || die "spawn: --mode $mode needs --goal \"<goal>\" (it becomes the thread title)"
    kind=work
  fi
  if [ -n "$helper" ]; then
    [ -z "$council" ] || die "spawn: --helper does not apply to council roles; the roster's council line picks their models"
    kind=helper
  fi
  # Model: a council role walks the council line in the launch loop below (council_choose), so a failed launch moves to the
  # next seat; an explicit --provider/--model is checked by the same rules. Any other role takes its card's model from the roster.
  explicit=
  if [ -n "$council" ]; then
    case $author in ?*:?*) ;; *) die "spawn: --role $council needs --author P:ID (the provider:model that wrote the work)" ;; esac
    [ -z "$mod" ] || explicit=${prov:-$(provider)}:$mod
    if [ "$council" = council-chair ]; then
      size=${size:-2}
      case $size in 2|3) ;; *) die "spawn: --size is 2 or 3" ;; esac
    else
      case $chair in ?*:?*) ;; *) die "spawn: --role council-member needs --chair P:ID (the chair's provider:model)" ;; esac
      cdir=$(council_dir "$chair")
      if [ -z "$cdir" ] && [ "$self_role" = council-chair ]; then
        # The title says chair, but the spawn that made this thread has not returned and written the marker yet.
        i=0; while [ ! -f "$me/.council-chair" ] && [ $i -lt "${WORKFLOW_MARKER_WAIT:-30}" ]; do sleep 1; i=$((i + 1)); done
        cdir=$(council_dir "$chair")
      fi
      if [ -z "$cdir" ]; then
        [ "$h" != bb ] || die "spawn: only a council chair spawns members ($me has no .council-chair)"
        die "spawn: no council chaired by $chair under $me/workers/; spawn the chair first"
      fi
      mk=$cdir/.council-chair
      [ "$(mget "$mk" chair)" = "$chair" ] || die "spawn: --chair $chair is not this council's chair ($(mget "$mk" chair))"
      [ "$(mget "$mk" author)" = "$author" ] || die "spawn: --author $author is not this council's author ($(mget "$mk" author)); pass the chair's constraints unchanged"
      size=$(mget "$mk" size); size=${size:-2}
      ml=$(mget "$mk" limited)
      [ -z "$ml" ] || [ "$ml" = - ] || limited=${limited:+$limited,}$ml
    fi
  elif [ -n "$mod" ]; then
    prov=${prov:-$(provider)}
  elif [ -n "$prov" ]; then
    mod=$(model "$kind" "$prov")
  else
    km=$(kind_model "$kind"); prov=${km%%:*}; mod=${km#*:}
  fi
  [ -n "$slice" ] || slice=$(basename "$(dirname "$brief")")
  if [ "$mode" = child ]; then
    if [ -z "$goal" ]; then
      case $h in
        bb) goal=$(bb status --json 2>/dev/null | sed -n 's/^ *"title": "\(.*\)",*$/\1/p' | head -1) ;;
      esac
      [ -n "$goal" ] || goal=${WORKFLOW_TASK:-}
    fi
    # A council role's title carries its role from creation; the nesting guards of the new thread read it (self_council).
    case $council in council-chair) rt='Council chair' ;; council-member) rt='Council member' ;; *) rt=$role ;; esac
    if [ -n "$goal" ]; then title="$goal › $rt · $slice"; else title="$rt · $slice"; fi
  else
    title=$goal
  fi
  # A slice spawned before whose report.md is missing is retried, not re-spawned (a duplicate thread).
  if [ "$mode" = child ] && [ -z "$force" ] && [ ! -f "$d/workers/$slice/report.md" ]; then
    prev=$(awk -F'\t' -v s="$slice" '$1 == s { id = $2; f = 1 } END { if (f) print (id == "" ? "-" : id) }' "$d/spawned.log" 2>/dev/null || true)
    if [ -n "$prev" ]; then
      [ "$prev" != - ] || prev='<id>'
      die "spawn: slice '$slice' was spawned before ($prev) and $d/workers/$slice/report.md is missing; run \`bb thread retry $prev\` on the earlier worker (--force spawns a new one anyway)"
    fi
  fi
  origin=${BB_THREAD_ID:-}
  after_tracked=
  if [ -n "$after" ]; then
    [ "$mode" != fresh ] && grep -qF "| @thread:$after |" "$d/spin-offs.md" 2>/dev/null && after_tracked=1
  fi
  if [ "$ctx" = none ] && grep -Eqi '^[#*[:space:]-]*(context|reference)s?([*]*:|[[:space:]]*$)' "$brief"; then
    die "spawn: --context none, but $brief has a Context:/Reference: section; remove it (the goal only) or use --context this"
  fi
  # A composed brief = the agent's brief + the runtime-owned setup block.
  setup=
  [ "$mode" = child ] && [ -z "$wait_go$after" ] && [ "$ctx" = this ] || setup=1
  if [ -n "$setup$council" ]; then
    [ "$h" != bb ] || [ -n "$origin" ] || die "spawn: BB_THREAD_ID unset"
    mkdir -p "$d/briefs"
  fi
  src=$brief failed= tok= tries=0
  # Launch loop: one pass, except a council seat whose bb launch fails: it is logged failed and the next eligible seat is tried.
  while :; do
    tries=$((tries + 1)); [ $tries -le 10 ] || die "spawn: 10 launches failed (${failed# }); see the errors above"
    [ -z "$council" ] || { council_choose; prov=${cmodel%%:*}; mod=${cmodel#*:}; }
    if [ -n "$setup$council" ]; then
      sent=$d/briefs/$slice-$mode.md
      { cat "$src"; [ -z "$setup" ] || brief_extra; [ -z "$council" ] || council_block; } > "$sent"
      brief=$sent
    fi
    [ "$h" = bb ] || break
    p=$prov; m=$(bb_model_id "$mod")
    [ -n "$project" ] || project=${BB_PROJECT_ID:?BB_PROJECT_ID unset}
    # A council seat runs in auto (council_ok seats only providers that list it). Other workers: auto where supported.
    if [ -n "$council" ]; then pm=auto; else pm=$(perm_mode "$p" auto accept-edits full); fi
    set -- bb thread spawn --project "$project" --provider "$p" --model "$m" \
      --reasoning-level "$effort" --title "$title" --prompt-file "$brief" --permission-mode "$pm"
    [ -z "$host" ] || set -- "$@" --host "$host"
    # Archiving the chair archives and stops its members (bb lifecycle ownership; stop alone does not cascade: council-stop).
    [ "$council" != council-member ] || set -- "$@" --lifecycle-owner-thread "${BB_THREAD_ID:?BB_THREAD_ID unset}"
    if [ "$mode" = child ]; then
      set -- "$@" --parent-self
      if [ -n "$isolated" ]; then set -- "$@" --new-environment "$(new_env_kind "$project")"
      else set -- "$@" --environment "${BB_ENVIRONMENT_ID:?BB_ENVIRONMENT_ID unset}"; fi
      envw=
    else
      case $env in
        this) set -- "$@" --environment "${BB_ENVIRONMENT_ID:?BB_ENVIRONMENT_ID unset}"; envw=' · env: reused' ;;
        new) set -- "$@" --new-environment "$(new_env_kind "$project")"; envw=' · env: new' ;;
        *) set -- "$@" --environment "$env"; envw=" · env: $env" ;;
      esac
    fi
    [ -z "$WORKFLOW_DRY_RUN" ] || break
    mkdir -p "$d"; rc=0
    out=$(WORKFLOW_SPAWN=1 "$@" --json 2>"$d/.spawn-err.$$") || rc=$?
    id=$(printf '%s\n' "$out" | sed -n 's/^ *"id": "\([^"]*\)".*$/\1/p' | head -1)
    err=$(cat "$d/.spawn-err.$$" 2>/dev/null; [ -n "$id" ] || printf '%s' "$out"); rm -f "$d/.spawn-err.$$"
    if [ "$rc" = 0 ] && [ -n "$id" ]; then [ -z "$err" ] || printf '%s\n' "$err" >&2; break; fi
    printf 'spawn: launching %s on %s failed: %s\n' "$title" "$p:$m" "${err:-no thread id in the output}" >&2
    [ -n "$council" ] || die "spawn: could not create the thread"
    failed="$failed $cmodel"
    if [ -n "$tok" ]; then council_seat "$tok" failed; tok=; fi
    [ -z "$explicit" ] || die "spawn: could not create the council seat on $cmodel${cdir:+ (logged as failed in $cdir/council.log)}"
  done
  case $h in
  bb)
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
      [ -z "$council" ] || council_record '<new>'
      [ "$mode" != spin-off ] || printf 'ledger row (%s/spin-offs.md): %s\n' "$d" "| @thread:$id | $title | $(date '+%F %T') | $([ -n "$after_merge" ] && echo 'after merge' || echo done) | ${after:--} | running | - |"
    else
      if [ "$mode" = child ]; then printf '%s\t%s\n' "$slice" "$id" >> "$d/spawned.log"; fi
      [ -z "$council" ] || council_record "$id"
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
    printf '%s → @thread:%s · %s · %s/%s · %s · %s%s · %s%s\n' "$word" "$id" "$place" "$p" "$m" "$effort" "$rule" "$hold" "$cx" "$envw"
    ;;
  claude-code)
    m=$(cc_alias "$mod")
    [ -z "$council" ] || council_record -
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
    m=$mod
    [ -z "$council" ] || council_record -
    cat <<EOF
Call the spawn-agent tool (read its schema first) with:
  model: "$m"
  reasoning_effort: "$effort"
  fork_context: false
  message: the full contents of $brief
EOF
    ;;
  *) die "spawn: no workers in this runtime; play the role yourself from $brief" ;;
  esac
}

# council_block: the runtime-owned council part of a chair's or member's brief.
council_block() {
  self=$(cd "$(dirname "$0")" && pwd)/runtime.sh
  printf '\n---\nCouncil (added by runtime.sh; do not edit)\n\n'
  if [ "$council" = council-chair ]; then
    printf 'You:      council chair on %s\n' "$cmodel"
    printf 'Author:   %s (never a member)\n' "$author"
    printf 'Size:     %s: you and %s member(s)\n' "$size" "$((size - 1))"
    printf 'Limited:  %s\n' "${limited:-none}"
    cmd=$(q sh "$self" spawn --role council-member --author "$author" --chair "$cmodel" ${limited:+--limited "$limited"} --effort "$effort" --brief '<member brief>' --slice '<member name>')
    if [ "$h" = bb ]; then
      printf 'Members:  spawn each with this command, changing only --effort, --brief and --slice; it picks the model and refuses more than %s:\n          %s\n' "$((size - 1))" "$cmd"
      printf '          A member seated from a family already on the council ("same family as …" in its spawn output): mark it so on the Council line.\n'
      printf '          Exit 1 "no council model left": rule with the members you have, mark the verdict as the error says, and name the gap under Council: missing.\n'
      printf 'End:      after verdict.md and your report, stop the members: %s\n' "$(q sh "$self" council-stop)"
    else
      printf 'Members:  your parent spawns them (no nesting here) with: %s\n' "$cmd"
      printf '          Run the discussion through files in your storage (runtimes.md, Council outside bb). Members on other models of this vendor are\n'
      printf '          marked "same family as …"; when that command exits 1 with no member seated, rule alone and mark the verdict "council: 1 of %s".\n' "$size"
    fi
  else
    printf 'You:      council member on %s%s\n' "$cmodel" "${same_:+ ($same_: no model of a new family was eligible)}"
    printf 'Chair:    %s · author: %s\n' "$chair" "$author"
    printf "Rules:    review alone first; write findings.md with your score in your storage; answer the chair's agree / dispute / add request; never spawn (runtime.sh refuses).\n"
  fi
}

# council_marker: the .council-chair / .council-member file a council spawn writes into the new worker's storage.
council_marker() {
  if [ "$council" = council-chair ]; then printf 'chair %s\nauthor %s\nsize %s\nlimited %s\n' "$cmodel" "$author" "$size" "${limited:--}"
  else printf 'member %s\nchair %s\nauthor %s\n' "$cmodel" "$chair" "$author"; fi
}

# council_record <new id | <new> | ->: writes the marker into the worker's brief folder and, under bb, into the new thread's own storage
# (a sibling of this thread's); a member also gets a council.log line. <new> (dry run) only prints what it would write.
council_record() {
  w=$d/workers/$slice/.$council
  t_=
  if [ "$h" = bb ] && [ -n "$BB_THREAD_STORAGE" ]; then t_=${BB_THREAD_STORAGE%/*}/$1/.$council; fi
  line=
  [ "$council" != council-member ] || line=$(printf '%s\t%s\t%s' "$chair" "$cmodel" "$1")
  if [ "$1" = '<new>' ]; then
    printf 'marker: %s\n' "$w"; [ -z "$t_" ] || printf 'marker: %s\n' "$t_"
    [ -z "$line" ] || printf 'council.log (%s): %s\n' "$cdir" "$line"
    return 0
  fi
  mkdir -p "${w%/*}"; council_marker > "$w"
  if [ -n "$t_" ]; then mkdir -p "${t_%/*}"; council_marker > "$t_"; fi
  [ -n "$line" ] || return 0
  if [ -n "$tok" ]; then council_seat "$tok" "$1"; else printf '%s\n' "$line" >> "$cdir/council.log"; fi
}

# council_stop [chair id]: in a chair, stop the members in council.log; with an id, stop that thread's children, then it.
council_stop() {
  if [ "$(detect)" != bb ]; then
    echo "council-stop needs bb (threads exist only there); here, stop resuming the member agents: their work ends with the chair's verdict"
    return
  fi
  if [ -z "$1" ]; then
    me=$(storage)
    [ -f "$me/.council-chair" ] || die "council-stop: not a council chair ($me has no .council-chair); pass the chair's thread id"
    ids=$(awk -F'\t' '$3 ~ /^thr_/ { print $3 }' "$me/council.log" 2>/dev/null || true)
  else
    ids="$(bb thread list --parent-thread "$1" --json 2>/dev/null | sed -n 's/^    "id": "\([^"]*\)".*$/\1/p') $1"
  fi
  for i in $ids; do
    if [ -n "$WORKFLOW_DRY_RUN" ]; then q bb thread stop "$i"; else bb thread stop "$i" >/dev/null || printf 'note: could not stop %s\n' "$i" >&2; fi
  done
  printf 'Stopped → %s\n' "$(printf '%s ' $ids | sed 's/ $//')"
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

# release <id>: the reverse of adopt; a child thread becomes top-level again, keeping its project, workspace and history.
release() {
  [ -n "$1" ] && [ $# = 1 ] || die "release <id>"
  case $1 in -*) die "release: unknown argument $1" ;; esac
  id=$1
  if [ "$(detect)" = bb ]; then
    [ -n "$BB_THREAD_ID" ] || die "release: BB_THREAD_ID unset"
    [ "$id" != "$BB_THREAD_ID" ] || die "release: a thread cannot release itself"
    if [ -n "$WORKFLOW_DRY_RUN" ]; then q bb thread update "$id" --clear-parent-thread
    else bb thread update "$id" --clear-parent-thread >/dev/null; fi
    printf 'Released → @thread:%s · top-level\n' "$id"
  else
    printf 'release needs bb (threads and parents exist only there); here, stop coordinating %s and let it finish on its own\n' "$id"
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
  council-stop) shift; council_stop "$@" ;;
  release) shift; release "$@" ;;
  wait) [ -n "$2" ] || die "wait <id>"; bb_or_print "end your turn; the completion notification wakes you (Claude Code: foreground Agent call; Codex: wait-agent tool)" wait "$2" ;;
  read) [ -n "$2" ] || die "read <id>"; bb_or_print "read the agent's final message" output "$2" ;;
  tell) [ -n "$2" ] && [ -n "$3" ] || die "tell <id> <message|->"
        warn_no_report "$2"
        msg="send the message with SendMessage (Claude Code) or send-message (Codex) to $2"
        if [ "$3" = - ]; then bb_or_print "$msg" tell "$2" --message-file -; else bb_or_print "$msg" tell "$2" "$3"; fi ;;
  install-guards) BACKUP_DIR=${BACKUP_DIR:-$(storage)/guards-backup} sh "$(dirname "$0")/install-guards.sh" ;;
  compact) [ -n "$2" ] || die "compact <id>"; bb_or_print "ask the user to run /compact in that agent, or let auto-compaction run" compact "$2"
           if [ "$(detect)" = bb ]; then echo "note: the next wake from $2 replays its last report; ignore it"; fi ;;
  ''|-h|--help) sed -n '2,/^set -e/p' "$0" | sed '$d' ;;
  help) if [ -z "$2" ]; then sed -n '2,/^set -e/p' "$0" | sed '$d'; else
          out=$(sed -n '2,/^set -e/p' "$0" | awk -v c="$2" '$0 ~ "^#   runtime\\.sh "c"( |$)" {p=1; print; next} p && /^#       / {print; next} {p=0}')
          [ -n "$out" ] || die "no help for: $2 (run runtime.sh help)"; printf '%s\n' "$out" | sed 's/^# *//'
        fi ;;
  *) die "unknown command: $1 (run runtime.sh help)" ;;
esac
