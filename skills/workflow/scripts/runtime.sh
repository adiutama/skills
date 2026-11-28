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
#       format: a global pinned preference memory (tags workflow,models,routing) whose details start with the line
#       `Fixed format read by the workflow skill; do not merge or reword.`, then one rule per line:
#         work      <provider>:<model>        the model that does the work (effort medium or high)
#         helper    <provider>:<model>        helper subagents (read-only lookups) and mechanical-edit workers
#         council   <provider>:<model> …      reviewers, in order of preference
#         never     <provider|family> …       vendors (providers or model makers) that never review
#         fallback  <from>><to> …             on <from>'s usage limit, move that work to <to>
#       a missing line falls back to the built-in default (runtime.sh model)
#   runtime.sh storage                    this agent's storage directory (bb: this thread's storage). A worker's output and report.md
#                                         go to the Storage: path in its brief instead; this one holds the script's state (council log, markers)
#                                         and a Reviewer's member briefs (workers/<member name>/, as its Council block says)
#   runtime.sh context [id]               context reading (self, or a worker's)
#   runtime.sh title "<goal>"             set this thread's title to the goal, before the first spawn
#   runtime.sh spawn --role R --effort E --brief FILE [--slice S] [--goal G] [--isolated] [--helper] [--provider P] [--model ID]
#       the model comes from the role card (work | helper) through the roster's work/helper line, else the built-in default;
#       --helper puts a work-card role on the helper model (mechanical edits); --provider/--model override both
#       --role reviewer --author P:ID [--size 2|3] [--limited P,...] (alias: council-chair): the Reviewer chairs a council; the first roster council entry, even when it is the author's
#       model (marked "author's model"; an explicit --provider/--model must name it), else the first that is not the author's model
#       (through any provider); either way one whose provider and family (the model's maker) are not in never, and whose provider is
#       not --limited or missing; if none, the author's model itself (marked "author's model"); --size (default 2) is recorded in the Reviewer's brief
#       --role council-member --author P:ID --chair P:ID [--limited P,...] (from a Reviewer; outside bb from the main thread): the next
#       such entry whose family differs from the chair's and every existing member's; if none, the next whose model is not seated
#       yet (same family, marked "same family as Reviewer|<member>"); if none, the author's model (marked "author's model"); if none,
#       a model already seated (a second seat, marked "second seat of <model>, same model as Reviewer|<member>"); skipping seats logged failed; at most
#       size-1 members; none left → exit 1; with no member at all the verdict is marked "council: 1 of <size>"
#       --replace <thread id | P:ID> (council-member): a member that cannot be resumed gives up its seat to a new member, picked like
#       any other (the same model may sit again). On bb the seat is named by its thread id and is given up only once that thread is
#       stopped or bb reports it gone (a failed lookup whose error.code is thread_not_found); elsewhere by its P:ID. Exit 1, the seat
#       unchanged, when no seat or more than one matches, the stop fails and bb does not report the thread gone, or the log cannot
#       be written
#       --provider/--model on a council role pass the same checks. The seat is reserved in council.log under a lock before the launch;
#       a failed bb launch is reported, logged failed, and the next eligible seat is tried. A pending seat whose spawn died stays
#       taken until the chair's children show its thread (the seat gets its id) or its absence (lost). Council roles run in auto;
#       under bb a provider that lists no auto mode (bb provider list --json) holds no seat: skipped, reported, logged no-auto
#       (a smaller council, never full). Other workers: auto where listed, else the first listed mode
#       nesting: a council member spawns nothing; a Reviewer spawns only council members; only a Reviewer (outside bb: anyone naming --chair)
#       spawns members. Under bb the role is read from this thread's title (set at creation): any " › " segment starting "Council
#       member · ", or "Reviewer · " or the older "Council chair · " (member wins), with the marker as a second signal; title unreadable and no marker → exit 1
#       title = "<goal> › <Role> · <slice>" (council roles: "Reviewer" | "Council member"); goal defaults to this thread's title (bb) or $WORKFLOW_TASK
#       slice: a brief in <storage>/workers/<folder>/ makes <folder> the slice (a different --slice exits 1); else --slice, else the brief's folder name
#       every launch attempt composes the brief into a new file, <storage>/briefs/<slice>-<mode>-<n>.md (the first unused n; a brief
#       that cannot be copied exits 1), ending with "Running on: <work|helper|council …> · <provider>/<model> · <effort>" and a line
#       counting the lines it added; a composed brief passed back as --brief keeps only its author's text: the blocks an earlier launch
#       added are dropped and rebuilt, and one whose added blocks were edited (the count no longer matches) exits 1 before launching
#       --mode child|spin-off|fresh (default child): spin-off and fresh make a top-level thread in its own worktree (no --role; need --goal; the work model unless --helper or --provider/--model)
#       --env this|new|<environment id> (spin-off, fresh): this = $BB_ENVIRONMENT_ID, new = a new worktree/personal workspace; default fresh=this, spin-off=new; child uses --isolated instead
#       --wait-go · --after <thread id> · --context none|this|<thread id> · --report-after-merge (spin-off) · --force (re-spawn a slice with no report.md) · --project <id> · --host <id-or-name> (the machine to run on; passed to bb thread spawn as --host)
#       prints the receipt line; WORKFLOW_DRY_RUN=1 prints the commands for every mode
#   runtime.sh council-stop [reviewer id] end a council: in a Reviewer, stop its members (council.log); with an id, stop that Reviewer's children, then it. Elsewhere: prints the instruction
#   runtime.sh adopt <id> [--quiet]       make an existing thread a child of this one (bb: bb thread update <id> --parent-thread <this>; --quiet adds --parent-notifications off); prints the receipt. Elsewhere: prints the equivalent instruction
#   runtime.sh release <id>               make a child thread top-level again (bb: bb thread update <id> --clear-parent-thread); prints the receipt. Elsewhere: prints that release needs bb
#   runtime.sh threads [--project ID] [query]  bb: search threads and messages for the query, or list the threads of a project
#                                         (default this one) with their status. Elsewhere: prints where your workers are
#   runtime.sh show <id>                  a thread's details: title, status, parent (bb: bb thread get). Elsewhere: prints the instruction
#   runtime.sh retry <id>                 retry a worker whose turn failed, in place, keeping its context (bb: bb thread retry). Elsewhere:
#                                         prints the instruction
#   runtime.sh wait <id> [--timeout <duration>] [--watchdog]  wait until the worker has finished all its work: a turn that ends
#                                         after the wait starts, then idle with nothing queued and no turn begun since (a re-check still
#                                         in its queue is waited for), or the timeout passes (500ms, 90s, 60m, 2h; bb's default 20m),
#                                         printing which: `ended: <id>` (exit 0) or `timeout: <id> …` naming when the wait began (exit 2,
#                                         bb's timeout exit code); any other failure, or a state it cannot read, prints why (exit 1), never
#                                         ended. Start it right after you send. bb: bb thread wait, get and log.
#                                         Watchdog: --watchdog (default 60m) returns at once and leaves a detached wait that tells this
#                                         thread only on a timeout or a failed wait, since a worker paused on a usage limit never reports;
#                                         a normal end sends nothing, as the worker's own turn end already wakes you. Elsewhere: prints
#                                         the instruction, and with --watchdog what can wake you there
#   runtime.sh quota [provider]           each pool account's usage windows, reset times and a verdict: ok, near limit (a window of a day or
#                                         less at 85% or more, a longer one at 90% or more), limited (used up, rejected, or the account not
#                                         ready), unknown (no window observed yet) or disabled; a model family's own weekly limit follows
#                                         (`→ ok, fable limited`) and rules out only that family. Then one line per provider, as good as its
#                                         best account (`claude: ok, fable limited`). provider: a bb provider id (claude-code, codex) or a
#                                         pool provider (claude). bb: from bb pool account list --json; elsewhere: prints that quota is unknown here
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
spawn       runtime.sh spawn --role R --effort E --brief FILE [--slice S] [--isolated] [--helper]; the model is the roster's work or helper model, as the role card says (--helper: a work card on the helper model); a review: --role reviewer --author P:ID [--size 2|3] [--limited P,...] (the Reviewer then spawns its council members with --role council-member); the runtime links it to you as parent
nesting     one helper per worker for its own lookup; a Reviewer spawns its council members, one level deep; members never spawn (runtime.sh refuses); never a coordinator under a coordinator (every child turn wakes its parent)
helper      the Agent tool (Claude Code hosted), only for a read-only lookup of your own: subagent_type "Explore", model "haiku"; any other job is a worker (mechanical edits: a worker with --helper)
wait        end your turn: each child's turn end wakes you with its result; watchdog: runtime.sh wait <id> --watchdog (detached; only a timeout arrives, as a message in your thread)
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
wait        a foreground Agent call, or its completion notification; watchdog: a background shell command that sleeps the timeout wakes you when it exits
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
wait        wait-agent tool; repeat after a timeout (the timeout is the watchdog)
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
wait        none; nothing wakes you after your turn ends, so no watchdog: do the work yourself
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
    researcher|prototyper|designer|implementer|tester|architect|reviewer|council-chair|council-member) echo work ;;
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
  am=$(same_model "${1#*:}"); tf_=" " tm_=" " fam_=1 au_= dup_=
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
# is in never, its provider is not --limited and is present, it is not the author's model (through any provider; allowed once
# au_ is set), its model is not seated yet (allowed once dup_ is set), and its family differs from every taken entry (the chair
# and existing members; dropped once fam_ is empty). Else appends the reason to why= and returns 1.
council_ok() {
  e=$1; ep=${e%%:*}; ef=$(family "$e")
  case " $2 " in *" $e "*) why="$why $e(failed)"; return 1 ;; esac
  case "$never" in *" $ep "*|*" $ef "*) why="$why $e(never)"; return 1 ;; esac
  case "$lim" in *" $ep "*) why="$why $e(limited)"; return 1 ;; esac
  case $have in *" $ep "*) ;; *) why="$why $e(missing)"; return 1 ;; esac
  case "${auto_:- $ep }" in *" $ep "*) ;; *) why="$why $e(no auto mode)"; noauto_="$noauto_ $e"; return 1 ;; esac
  [ -n "$au_" ] || [ "$(same_model "${e#*:}")" != "$am" ] || { why="$why $e(author)"; return 1; }
  [ -n "$dup_" ] || case "$tm_" in *" $(same_model "${e#*:}") "*) why="$why $e(seated)"; return 1 ;; esac
  [ -z "$fam_" ] || case "$tf_" in *" $ef "*) why="$why $e(family $ef taken)"; return 1 ;; esac
}

# council_pick <author P:ID> <taken P:ID ...> [failed P:ID ...]: sets pick= to the first eligible council entry
# (council_ok). Returns 1 when none is left; why= lists what was skipped.
# Four passes, each only when the one before finds nothing: 1. an entry of a family not yet seated; 2. any entry whose model is
# not seated yet (same family allowed); 3. the author's model too; 4. (members only) a model already seated, a second seat.
# same_ names how the pick falls short: the seat it shares a family with, "author's model", or the seat whose model it repeats.
council_pick() {
  council_ctx "$1" "$2"; pick= why= same_=
  council_walk "$3" && return 0
  fam_=
  if [ -n "$2" ]; then why=; council_walk "$3" && { same_=$(same_as "$pick" "$2"); return 0; }; fi
  au_=1; why=
  if council_walk "$3"; then
    s_=$(same_as "$pick" "$2"); same_="author's model${s_:+, $s_}"; return 0
  fi
  [ -n "$2" ] || return 1
  dup_=1; why=
  council_walk "$3" || return 1
  same_=$(same_model_as "$pick" "$2")
}
council_walk() {
  for e in $(council_list); do
    council_ok "$e" "$1" || continue
    pick=$e; return 0
  done
  return 1
}
# same_model_as <P:ID> <seated P:ID ...>: "second seat of <model>, same model as Reviewer|<member>" for the first seat it repeats.
same_model_as() {
  m_=$(same_model "${1#*:}"); for x in $2; do
    [ "$(same_model "${x#*:}")" = "$m_" ] || continue
    if [ "$x" = "$chair" ]; then echo "second seat of $m_, same model as Reviewer"; else echo "second seat of $m_, same model as $x"; fi; return 0
  done
}
# same_as <P:ID> <seated P:ID ...>: "same family as Reviewer" or "same family as <member>" for the first seat sharing its family.
same_as() {
  f_=$(family "$1"); for x in $2; do
    [ "$(family "$x")" = "$f_" ] || continue
    if [ "$x" = "$chair" ]; then echo "same family as Reviewer"; else echo "same family as $x"; fi; return 0
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
# skipped (failed: the launch failed; no-auto: the provider lists no auto mode). A lost seat (see council_reconcile), a retired
# one (retired:<id>, given up to a replacement) and the row this spawn replaces (--replace, line rl_) are neither.
council_seats() {
  awk -F'\t' -v c="$chair" -v w="$1" -v rl="${rl_:-0}" '$1 == c && $3 != "lost" && $3 !~ /^retired:/ && NR != rl &&
    (w == "failed") == ($3 == "failed" || $3 == "no-auto") { print $2 }' "$cdir/council.log" 2>/dev/null || true
}

# council_retire (under the lock unless a dry run; once per spawn): --replace names exactly one occupied seat of this chair: on bb
# by its thread id (a provider:model names no seat there), elsewhere, where seats have no id, by its P:ID. A real spawn on bb
# stops that thread first; if the stop fails, the seat is given up only when the lookup fails too with a top-level error.code of
# thread_not_found (json_error_code). A lookup that succeeds, or fails any other way, keeps the seat and the spawn exits 1, so a
# member that may still run is never doubled. The seat is then logged retired:<id>, and a failure to write that stops the spawn. The replacement is picked like any member, the same model included.
council_retire() {
  [ -n "$replace" ] && [ -z "$rpdone_" ] || return 0
  rpdone_=1
  rdie_() { [ -z "$rs_" ] || council_unlock 2>/dev/null || true; die "spawn: --replace $replace: $*"; }
  if [ "$h" = bb ]; then
    case $replace in thr_*) ;; *) rdie_ "on bb a seat is named by its member's thread id (the third column of $cdir/council.log), not its provider:model" ;; esac
  fi
  rows_=$(awk -F'\t' -v c="$chair" -v r="$replace" -v b="$([ "$h" = bb ] && echo 1)" '$1 == c && (b ? $3 == r : ($2 == r && $3 !~ /^(lost|failed|no-auto|pending:.*|retired:.*)$/)) { print NR }' \
    "$cdir/council.log" 2>/dev/null || true)
  nr_=$(printf '%s' "$rows_" | grep -c . || true)
  [ "$nr_" != 0 ] || rdie_ "no seat of this council holds it ($cdir/council.log); pass the member's thread id, or its P:ID where seats have no id"
  [ "$nr_" = 1 ] || rdie_ "it names $nr_ seats in $cdir/council.log; fix the log so each seat is listed once"
  rl_=$rows_
  [ -n "$rs_" ] || return 0
  if [ "$h" = bb ] && ! bb thread stop "$replace" >/dev/null 2>&1; then
    if gj_=$(bb thread get "$replace" --json 2>/dev/null); then gc_=; else gc_=$(printf '%s\n' "$gj_" | json_error_code); fi
    [ "$gc_" = thread_not_found ] ||
      rdie_ "could not stop $replace and bb still shows it (or could not be asked), so it keeps its seat; rule without a replacement, or run this again once it has stopped"
    printf 'note: could not stop %s; bb no longer has it, so its seat is given up\n' "$replace" >&2
  fi
  { awk -F'\t' -v OFS='\t' -v rl="$rl_" 'NR == rl { $3 = "retired:" $3 } { print }' "$cdir/council.log" > "$cdir/council.log.$$" &&
    mv "$cdir/council.log.$$" "$cdir/council.log"; } 2>/dev/null || {
    rm -f "$cdir/council.log.$$" 2>/dev/null
    rdie_ "could not record the retired seat in $cdir/council.log; its seat stays; fix the folder, then run this again"
  }
}

# json_error_code: the top-level error.code string of the JSON object on stdin (bb's --json error shape), or nothing. Strings are
# read whole, so the same words in a title, a message or a nested object never count.
json_error_code() {
  awk 'BEGIN { RS = "\001" } {
    s = $0; n = length(s); d = 0
    for (i = 1; i <= n; i++) {
      c = substr(s, i, 1)
      if (c == "\"") {
        str = ""; j = i + 1
        while (j <= n && (ch = substr(s, j, 1)) != "\"") { if (ch == "\\") { str = str substr(s, j, 2); j += 2 } else { str = str ch; j++ } }
        i = j; k = i + 1
        while (substr(s, k, 1) ~ /[ \t\r\n]/) k++
        if (substr(s, k, 1) == ":") { key[d] = str; i = k }
        else if (d == 2 && inerr && key[2] == "code") { print str; exit }
      } else if (c == "{" || c == "[") { d++; key[d] = ""; if (d == 2) inerr = (c == "{" && key[1] == "error") }
      else if (c == "}" || c == "]") d--
    }
  }'
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

# chair_first: sets pick= to the first entry of the roster's council line (not the built-in list) when it is the author's model
# and passes every other council_ok check (an explicit --provider/--model must name that entry). Else returns 1 with why= and
# noauto_ untouched, so the usual pick follows.
chair_first() {
  c_=$(roster_rule council); [ -n "$c_" ] || return 1
  set -- $c_; e1_=$1
  [ -z "$explicit" ] || { [ "${explicit%%:*}" = "${e1_%%:*}" ] && [ "$(same_model "${explicit#*:}")" = "$(same_model "${e1_#*:}")" ]; } || return 1
  council_ctx "$author" ""; [ "$(same_model "${e1_#*:}")" = "$am" ] || return 1
  am= w_=$why n_=$noauto_
  council_ok "$e1_" "$failed" || { why=$w_ noauto_=$n_; return 1; }
  pick=$e1_
}

# council_choose: sets cmodel= for this launch. A chair: the first council entry when it is the author's model and otherwise
# eligible (chair_first), else the explicit model if eligible, else the first eligible entry not yet failed in this run;
# achair_=1 when the chair runs the author's model. A member: the same, against the chair and its seated members, skipping
# failed seats; the seat is reserved in council.log (tok=) unless this is a dry run.
council_choose() {
  why= noauto_= rs_= same_= achair_=
  if [ "$council" = council-chair ]; then
    if chair_first; then
      cmodel=$pick; achair_=1
      printf 'spawn: seating %s as Reviewer, the author'"'"'s model (first council entry; mark it on the verdict Council line)\n' "$cmodel" >&2
    elif [ -n "$explicit" ]; then
      council_ctx "$author" ""; council_ok "$explicit" "$failed" || { noauto_report; die "spawn: $explicit cannot be the Reviewer (skipped:$why)"; }
      cmodel=$explicit
    else
      if council_pick "$author" "" "$failed"; then rc_=0; else rc_=1; fi; noauto_report
      [ -z "$same_" ] || printf 'spawn: no other model is eligible; the Reviewer runs on %s, %s (mark it on the verdict Council line)\n' "$pick" "$same_" >&2
      [ "$rc_" = 0 ] || die "spawn: no council model is eligible to be the Reviewer (skipped:$why); wait for a reset, or pass --provider P --model ID"
      cmodel=$pick; [ -z "$same_" ] || achair_=1
    fi
    return 0
  fi
  [ -n "$WORKFLOW_DRY_RUN" ] || { rs_=1; council_lock; council_reconcile; }
  council_retire
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
# Council member · <slice>" (or Reviewer; older threads: Council chair); any " › " segment starting that way counts, whatever is appended after it, and
# member wins over chair (a member's parent title holds its chair's segment). unknown: bb could not be asked or gave no title
# field; the guards then refuse to spawn unless a marker exists.
self_council() {
  [ "$(detect)" = bb ] && [ -n "$BB_THREAD_ID" ] || return 0
  j_=$(bb thread get "$BB_THREAD_ID" --json 2>/dev/null) || { echo unknown; return 0; }
  printf '%s\n' "$j_" | grep -q '^ *"title": ' || { echo unknown; return 0; }
  printf '%s\n' "$j_" | sed -n 's/^ *"title": "\(.*\)",*$/\1/p' | head -1 | awk -F' › ' '{
    for (i = 1; i <= NF; i++) { if ($i ~ /^Council member · /) m = 1; else if ($i ~ /^(Reviewer|Council chair) · /) c = 1 }
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

# brief_cut <file>: "<n> raw|composed|edited", n = the number of lines its author wrote. A brief this script composed ends in blocks
# it added (a blank line, "---", then "<Thread setup|Council|Assignment> (added by runtime.sh; do not edit)") and, since this
# version, a last line "<!-- runtime.sh added the last <t> lines -->": composed when those t lines start with that separator, edited
# when they no longer do (the spawn refuses it, so author text is never cut by a guess). An older composed brief has no count; its
# blocks are recognised from the end, each in its generated shape and order (Thread setup, Council, Assignment last, with or without
# the blank line a source with no final newline left out). Anything else is raw. Marker lines quoted in the author's text are
# never mistaken for the blocks: the count, or the shape at the very end, decides.
brief_cut() {
  awk 'function rank(x) {
      if (x == "Thread setup (added by runtime.sh; do not edit)") return 1
      if (x == "Council (added by runtime.sh; do not edit)") return 2
      if (x == "Assignment (added by runtime.sh; do not edit)") return 3
      return 0 }
    function shaped(x) { return x == "" || x ~ /^[A-Z][A-Za-z ]*: / || x ~ /^- (DONE|BLOCKED|FAILED): / || x ~ /^   *[^ ]/ }
    { l[NR] = $0 }
    END {
      if (l[NR] ~ /^<!-- runtime\.sh added the last [0-9]+ lines -->$/) {
        t = l[NR]; sub(/^<!-- runtime\.sh added the last /, "", t); sub(/ .*/, "", t); a = NR - t
        if (t + 0 >= 4 && a >= 0 && l[a + 1] == "" && l[a + 2] == "---" && rank(l[a + 3])) print a, "composed"
        else print NR, "edited"
        exit
      }
      e = NR; last = 4; cut = 0
      while (1) {
        for (i = e; i > 1 && !(rank(l[i]) && l[i - 1] == "---"); i--) ;
        if (i <= 1 || (r = rank(l[i])) >= last || l[i + 1] != "") break
        if (r == 3) { if (e != i + 2 || l[e] !~ /^Running on: /) break }
        else { for (j = i + 2; j <= e && shaped(l[j]); j++) ; if (j <= e) break }
        cut = i - 1; last = r; e = i - 2
      }
      if (!cut) { print NR, "raw"; exit }
      a = cut - 1; if (a >= 1 && l[a] == "") a--
      print a, "composed"
    }' "$1"
}
# brief_body <file>: the brief as its author wrote it (the first n lines brief_cut names).
brief_body() { n_=$(brief_cut "$1") || return 1; awk -v n="${n_%% *}" 'NR <= n' "$1"; }

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
  role= effort= brief= slice= goal= isolated= prov= author= mod= limited= helper= size= chair= replace= rpdone_= rl_=
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
      --replace) replace=$2; shift ;;
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
  # Reviewer is the role name; council-chair, its older name, stays an alias. Inside, the Reviewer is the council's chair.
  [ "$rl" != reviewer ] || { rl=council-chair; role=council-chair; }
  # Nesting guards: a council stays one level deep (SKILL.md, Verify). Under bb the role is in this thread's title from the moment
  # bb creates it (spawn --title), so it holds before the marker the spawn writes once it returns; the marker is a second signal.
  self_role=$(self_council)
  if [ "$self_role" = unknown ] && [ ! -f "$me/.council-member" ] && [ ! -f "$me/.council-chair" ]; then
    die "spawn: this thread's council role is unknown (bb thread get $BB_THREAD_ID failed or gave no title) and it has no marker; refusing to spawn until bb answers"
  fi
  if [ -f "$me/.council-member" ] || [ "$self_role" = council-member ]; then
    die "spawn: a council member never spawns ($me is a council member); review alone and answer the Reviewer"
  fi
  if { [ -f "$me/.council-chair" ] || [ "$self_role" = council-chair ]; } && { [ "$mode" != child ] || [ "$rl" != council-member ]; }; then
    die "spawn: a Reviewer spawns only --role council-member ($me is a Reviewer)"
  fi
  council=
  [ "$mode" != child ] || case $rl in council-chair|council-member) council=$rl ;; esac
  [ -z "$size" ] || [ "$council" = council-chair ] || die "spawn: --size is for --role reviewer"
  [ -z "$chair" ] || [ "$council" = council-member ] || die "spawn: --chair is for --role council-member"
  [ -z "$replace" ] || [ "$council" = council-member ] || die "spawn: --replace is for --role council-member"
  [ -z "$author$limited" ] || [ -n "$council" ] || die "spawn: --author and --limited are for --role reviewer|council-member"
  if [ "$mode" = child ]; then
    [ -n "$role" ] || die "spawn: --role --effort --brief are required"
    kind=$(role_model "$role")
    if [ -z "$kind" ]; then
      case $rl in
        consultant) die "spawn: the Consultant role was removed; ask a Reviewer instead (--role reviewer)" ;;
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
        [ "$h" != bb ] || die "spawn: only a Reviewer spawns council members ($me has no .council-chair)"
        die "spawn: no council chaired by $chair under $me/workers/; spawn the Reviewer first"
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
  # A brief in <storage>/workers/<folder>/ makes <folder> the slice: the title, the report.md lookup (retry check, tell) and the
  # council markers all use it, so an explicit --slice may only repeat it.
  bdir=$(cd "$(dirname "$brief")" && pwd -P); wroot=$(cd "$d/workers" 2>/dev/null && pwd -P || true)
  if [ -n "$wroot" ] && [ "${bdir%/*}" = "$wroot" ]; then
    f_=${bdir##*/}
    [ -z "$slice" ] || [ "$slice" = "$f_" ] || die "spawn: --slice $slice, but the brief is in $d/workers/$f_/; that folder is the slice (title, report.md, retry check), so omit --slice or pass $f_"
    slice=$f_
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
    case $council in council-chair) rt='Reviewer' ;; council-member) rt='Council member' ;; *) rt=$role ;; esac
    if [ -n "$goal" ]; then title="$goal › $rt · $slice"; else title="$rt · $slice"; fi
  else
    title=$goal
  fi
  # A slice spawned before whose report.md is missing is retried, not re-spawned (a duplicate thread).
  if [ "$mode" = child ] && [ -z "$force" ] && [ ! -f "$d/workers/$slice/report.md" ]; then
    prev=$(awk -F'\t' -v s="$slice" '$1 == s { id = $2; f = 1 } END { if (f) print (id == "" ? "-" : id) }' "$d/spawned.log" 2>/dev/null || true)
    if [ -n "$prev" ]; then
      [ "$prev" != - ] || prev='<id>'
      die "spawn: slice '$slice' was spawned before ($prev) and $d/workers/$slice/report.md is missing; run \`runtime.sh retry $prev\` on the earlier worker (--force spawns a new one anyway)"
    fi
  fi
  origin=${BB_THREAD_ID:-}
  after_tracked=
  if [ -n "$after" ]; then
    [ "$mode" != fresh ] && grep -qF "| @thread:$after |" "$d/spin-offs.md" 2>/dev/null && after_tracked=1
  fi
  bkind_=$(brief_cut "$brief" 2>/dev/null) || bkind_=
  case $bkind_ in
    *' edited') die "spawn: $brief ends in blocks added by runtime.sh that were edited since (the count on its last line no longer matches); pass the brief as its author wrote it, without them" ;;
  esac
  if [ "$ctx" = none ] && brief_body "$brief" | grep -Eqi '^[#*[:space:]-]*(context|reference)s?([*]*:|[[:space:]]*$)'; then
    die "spawn: --context none, but $brief has a Context:/Reference: section; remove it (the goal only) or use --context this"
  fi
  # A composed brief = the agent's brief + the runtime-owned setup block (modes, hold, context), the council block, and the
  # assignment: the model and effort this spawn picked, so the brief never carries a guess written before the spawn.
  setup=
  [ "$mode" = child ] && [ -z "$wait_go$after" ] && [ "$ctx" = this ] || setup=1
  if [ -n "$setup$council" ]; then
    [ "$h" != bb ] || [ -n "$origin" ] || die "spawn: BB_THREAD_ID unset"
  fi
  mkdir -p "$d/briefs"
  src=$brief failed= tok= tries=0
  case $bkind_ in
    *' composed') printf 'spawn: %s was composed by an earlier launch; its blocks added by runtime.sh are dropped and this launch adds its own\n' "$src" >&2 ;;
  esac
  # Launch loop: one pass, except a council seat whose bb launch fails: it is logged failed and the next eligible seat is tried.
  while :; do
    tries=$((tries + 1)); [ $tries -le 10 ] || die "spawn: 10 launches failed (${failed# }); see the errors above"
    [ -z "$council" ] || { council_choose; prov=${cmodel%%:*}; mod=${cmodel#*:}; }
    # A new file per launch attempt (the first unused <n>), so a source that is itself an earlier composed brief is never
    # truncated, and no launched worker has its brief rewritten under it. Only the source's author text is copied (brief_body).
    k_=1
    while :; do
      sent=$d/briefs/$slice-$mode-$k_.md
      if [ ! -e "$sent" ]; then
        (set -C; : > "$sent") 2>/dev/null && break
        [ -e "$sent" ] || die "spawn: could not create $sent"
      fi
      k_=$((k_ + 1))
    done
    brief_body "$src" > "$sent" 2>/dev/null || { rm -f "$sent"; die "spawn: could not copy the brief $src to $sent"; }
    # The added blocks end with their own line count (brief_cut), so a later launch drops exactly them.
    n0_=$(wc -l < "$sent")
    { [ -z "$setup" ] || brief_extra; [ -z "$council" ] || council_block; assignment_block; } >> "$sent"
    printf '<!-- runtime.sh added the last %s lines -->\n' "$(($(wc -l < "$sent") - n0_ + 1))" >> "$sent"
    brief=$sent
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
    [ "$council" != council-chair ] || council_parent_note
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
    [ "$council" != council-chair ] || council_parent_note
    ;;
  *) [ -z "$council" ] || die "spawn: no workers in this runtime, so no council: when the work is done, review it yourself in a separate pass, following the Method and Findings format of roles/council-member.md, write verdict.md in your storage marked \"council: 0 of $size\", and tell the user it was a self-check"
     die "spawn: no workers in this runtime; play the role yourself from $brief" ;;
  esac
}

# assignment_block: the runtime-owned last part of every composed brief: what this spawn actually picked.
assignment_block() {
  case $council in
    council-chair) k="council · Reviewer, council of $size" ;;
    council-member) k="council · member" ;;
    *) k=$kind ;;
  esac
  printf '\n---\nAssignment (added by runtime.sh; do not edit)\n\nRunning on:  %s · %s/%s · %s\n' "$k" "$prov" "$mod" "$effort"
}

# council_parent_note: outside bb the Reviewer cannot nest, so the main thread seats the members and carries the discussion.
council_parent_note() {
  printf 'Then:     seat the members yourself: run the Members command in that brief once per member (at most %s) and make each call it prints.\n' "$((size - 1))"
  printf '          The discussion runs through files: each member writes findings.md in its storage; the Reviewer writes exchange-<n>.md and\n'
  printf '          asks you to resume each member with that path (tell); members append their answers to findings.md; the Reviewer writes verdict.md.\n'
}

# council_block: the runtime-owned council part of a chair's or member's brief.
council_block() {
  self=$(cd "$(dirname "$0")" && pwd)/runtime.sh
  printf '\n---\nCouncil (added by runtime.sh; do not edit)\n\n'
  if [ "$council" = council-chair ]; then
    printf 'You:      Reviewer, chairing the council, on %s%s\n' "$cmodel" "${achair_:+ (author's model${same_:+, no other model was eligible}: you may not refute a member's finding alone)}"
    printf 'Author:   %s (a member only when no other model is eligible)\n' "$author"
    printf 'Size:     %s: you and %s member(s)\n' "$size" "$((size - 1))"
    printf 'Limited:  %s\n' "${limited:-none}"
    # A member's brief folder is a workers/<member name>/ folder of the storage that spawns it, so its name is the slice and the
    # spawn, retry check and tell find its report.md there. On bb that is the Reviewer's own thread storage (runtime.sh storage
    # in its thread), not the Storage: folder its parent gave it; elsewhere the parent spawns, from its own storage.
    cmd=$(q sh "$self" spawn --role council-member --author "$author" --chair "$cmodel" ${limited:+--limited "$limited"} --effort "$effort")
    if [ "$h" = bb ]; then
      cmd="$cmd--brief \"\$($(q sh "$self")storage)/workers/<member name>/brief.md\""
      printf 'Members:  write each member'"'"'s brief to workers/<member name>/brief.md in the folder `%s` prints (the script'"'"'s storage for\n' "$(q sh "$self" storage | sed 's/ $//')"
      printf '          your thread, not your own Storage: folder; create the folder) and put that folder on the brief'"'"'s Storage: line, so the\n'
      printf '          member writes findings.md and report.md where the script looks for them. Then spawn it with this command, changing only\n'
      printf '          --effort and <member name>; it picks the model and refuses more than %s:\n          %s\n' "$((size - 1))" "$cmd"
      printf '          A member seated from a family already on the council, on the author'"'"'s model, or on a model already seated ("same family as …",\n'
      printf '          "author'"'"'s model" or "second seat of …" in its spawn output): mark it so on the Council line.\n'
      printf '          Exit 1 "no council model left": rule with the members you have, mark the verdict as the error says, and name the gap under Council: missing.\n'
      printf '          A member that cannot be resumed: add --replace <its thread id> to stop it and seat its replacement in the same seat;\n'
      printf '          exit 1 "keeps its seat": it could not be stopped and still exists, so rule without it and name the gap under Council: missing.\n'
      printf 'End:      after verdict.md and your report, stop the members: %s\n' "$(q sh "$self" council-stop)"
    else
      cmd="$cmd$(q --brief "$d/workers/<member name>/brief.md")"
      printf 'Members:  write each member'"'"'s brief to %s/workers/<member name>/brief.md (create the folder) and put that folder on the\n' "$d"
      printf '          brief'"'"'s Storage: line, so the member writes findings.md and report.md there; your parent spawns them (no nesting here) with:\n          %s\n' "$cmd"
      printf '          A member that cannot be resumed: ask your parent to run it again with --replace <that member'"'"'s provider:model>.\n'
      printf '          Discussion: once your findings.md and every member'"'"'s are in, write the merged list as exchange-<n>.md in your storage and\n'
      printf '          end your turn asking your parent to resume each member with its path; they append their answers to findings.md. Members on other models of this vendor are\n'
      printf '          marked "same family as …"; when that command exits 1 with no member seated, rule alone and mark the verdict "council: 1 of %s".\n' "$size"
    fi
  else
    printf 'You:      council member on %s%s\n' "$cmodel" "${same_:+ ($same_: no model of a new family was eligible)}"
    printf 'Chair:    %s · author: %s\n' "$chair" "$author"
    printf "Rules:    review alone first; write findings.md with your score in your storage; answer the Reviewer's agree / dispute / add request; never spawn (runtime.sh refuses).\n"
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
    [ -f "$me/.council-chair" ] || die "council-stop: not a Reviewer ($me has no .council-chair); pass the Reviewer's thread id"
    ids=$(awk -F'\t' '{ sub(/^retired:/, "", $3) } $3 ~ /^thr_/ { print $3 }' "$me/council.log" 2>/dev/null || true)
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

# threads [--project ID] [query]: search (with a query) or list a project's threads; outside bb there are no threads to list.
threads() {
  p_= qy=
  while [ $# -gt 0 ]; do
    case $1 in
      --project) [ $# -ge 2 ] || die "threads: --project needs an id"; p_=$2; shift ;;
      -*) die "threads: unknown argument $1" ;;
      *) [ -z "$qy" ] || die "threads: one query only (quote it)"; qy=$1 ;;
    esac; shift
  done
  if [ "$(detect)" != bb ]; then
    echo "no thread list here; your workers are the agents you started in this session (IDs in your ledger)"; return
  fi
  if [ -n "$qy" ]; then bb thread search "$qy"
  else bb thread list --project "${p_:-${BB_PROJECT_ID:?BB_PROJECT_ID unset; pass --project}}"; fi
}

bb_or_print() {  # $1 = what to do outside bb; the rest = bb thread arguments
  msg=$1; shift
  case $(detect) in
    bb) bb thread "$@" ;;
    *) printf '%s\n' "$msg" ;;
  esac
}

# whole_json: succeeds only when stdin is one complete JSON object or array: every bracket outside a string closed by its match,
# nothing after the last. A response cut short fails it.
whole_json() {
  awk '{ l = $0; gsub(/\\./, "", l); gsub(/"[^"]*"/, "", l); if (l ~ /"/) bad = 1; gsub(/[^][{}]/, "", l)
      for (i = 1; i <= length(l); i++) { c = substr(l, i, 1)
        if (c == "{" || c == "[") { if (st == "" && seen) bad = 1; st = st c; seen = 1 }
        else if (st == "" || substr(st, length(st)) != (c == "}" ? "{" : "[")) bad = 1
        else st = substr(st, 1, length(st) - 1) } }
    END { exit !(seen && st == "" && !bad) }'
}

# wait_log <id> [<seq>]: the thread's events after seq (all without one) as "<last seq> <last turn end> <turn begun after it>",
# with 0 for none and 1 for yes; fails, printing bb's error, when the log can't be read or is not one complete JSON array.
wait_log() {
  wl_=$(bb thread log "$1" --json --all ${2:+--after-seq "$2"} 2>&1) && case $wl_ in "["*) ;; *) false ;; esac &&
    printf '%s\n' "$wl_" | whole_json || { printf '%s\n' "$wl_"; return 1; }
  printf '%s\n' "$wl_" | awk 'function v(l) { sub(/^[^:]*: */, "", l); sub(/,$/, "", l); gsub(/"/, "", l); return l }
    /^    "seq":/ { s = v($0) + 0 } /^    "type":/ { t = v($0) }
    /^  \}/ { if (s > m) m = s; if (t == "turn/completed") { c = s; b = 0 } else if (t == "client/turn/requested" || t == "turn/started") b = 1; s = 0; t = "" }
    END { print m + 0, c + 0, b + 0 }'
}

# wait <id> [--timeout <duration>] [--watchdog]: block until the worker has finished all its work (idle, nothing queued)
# or the timeout passes, and say which. --watchdog returns at once and leaves a detached wait that, on timeout or failure
# only, tells this thread; --notify <thread> is that detached wait.
wait_for() {
  id_= to_= wd_= nt_=
  while [ $# -gt 0 ]; do
    case $1 in
      --timeout) [ $# -ge 2 ] || die "wait: --timeout needs a duration (500ms, 90s, 60m, 2h)"; to_=$2; shift ;;
      --watchdog) wd_=1 ;;
      --notify) [ $# -ge 2 ] || die "wait: --notify needs a thread id"; nt_=$2; shift ;;
      -*) die "wait: unknown option: $1" ;;
      *) [ -z "$id_" ] || die "wait <id> [--timeout <duration>] [--watchdog]"; id_=$1 ;;
    esac
    shift
  done
  [ -n "$id_" ] || die "wait <id> [--timeout <duration>] [--watchdog]"
  [ -z "$to_" ] || printf '%s\n' "$to_" | grep -Eq '^[0-9]+(ms|s|m|h)?$' || die "wait: bad --timeout '$to_' (500ms, 90s, 60m, 2h)"
  if [ "$(detect)" != bb ]; then
    if [ -n "$wd_" ]; then
      printf 'no detached watchdog here. Claude Code: a background shell command that sleeps %s wakes you when it exits; then check the agent. Codex: wait-agent with a %s timeout, repeated. Where nothing can wake you once your turn ends, wait in the foreground with the timeout, or end the turn telling the user which worker you wait on and when to check it\n' "${to_:-60m}" "${to_:-60m}"
    else
      printf 'end your turn; the completion notification wakes you (Claude Code: foreground Agent call; Codex: wait-agent tool%s)\n' "${to_:+ with a $to_ timeout}"
    fi
    return 0
  fi
  if [ -n "$wd_" ]; then
    : "${BB_THREAD_ID:?BB_THREAD_ID unset; the watchdog tells this thread}"
    set -- sh "$0" wait "$id_" --timeout "${to_:-60m}" --notify "$BB_THREAD_ID"
    if [ -n "$WORKFLOW_DRY_RUN" ]; then q "$@"; return 0; fi
    nohup "$@" </dev/null >/dev/null 2>&1 &
    printf 'watchdog: armed on %s for %s (pid %s); only a timeout or a failed wait arrives, as a message in this thread. Its own turn end still wakes you\n' "$id_" "${to_:-60m}" "$!"
    return 0
  fi
  # Done is an event, not a status snapshot: a turn that ended after this wait began (the anchor: the log's last seq now),
  # then one lookup showing the thread idle with an explicit zero queue, then no turn begun after that end in a log read
  # after the lookup. A lookup that fails, is cut short or lacks a field is unknown (exit 1), never "ended".
  since_=$(date +%H:%M) rc_=0
  an_=$(wait_log "$id_") || { rc_=1; o_="the event log of $id_ is unknown: $an_"; }
  an_=${an_%% *}
  # The deadline, in seconds; bb takes a plain number as seconds and defaults to 1200s.
  case ${to_:-1200} in
    *ms) s_=$(( (${to_%ms} + 999) / 1000 )) ;; *s) s_=${to_%s} ;; *m) s_=$(( ${to_%m} * 60 )) ;; *h) s_=$(( ${to_%h} * 3600 )) ;; *) s_=${to_:-1200} ;;
  esac
  dl_=$(( $(date +%s) + s_ )) t_=$to_
  while [ "$rc_" = 0 ]; do
    set +e; o_=$(bb thread wait "$id_" ${t_:+--timeout "$t_"} --json 2>&1); rc_=$?; set -e
    [ "$rc_" = 0 ] || break
    st_=
    g_=$(bb thread get "$id_" --json 2>&1) && printf '%s\n' "$g_" | whole_json && st_=$(printf '%s\n' "$g_" | awk '/^  "thread": \{/ { i = 1; next } i && /^  \}/ { i = 0 }
      i && /^    "status":/ { s = $2 } i && /^    "queuedMessageCount":/ { q = $2 }
      END { gsub(/[",]/, "", s); gsub(/,/, "", q); if (s != "" && q ~ /^[0-9]+$/) print s, q }')
    ev_=$(wait_log "$id_" "$an_") || st_=
    [ -n "$st_" ] || { rc_=1; o_="the state of $id_ is unknown (a lookup failed, was cut short, or lacked its status or queue count); check it (runtime.sh show $id_)"; break; }
    set -- $st_ $ev_  # status, queued, last seq, last turn end after the anchor, a turn begun after that end
    if [ "$1 $2 $5" = "idle 0 0" ] && [ "$4" -gt 0 ]; then [ -n "$nt_" ] || printf 'ended: %s\n' "$id_"; return 0; fi
    l_=$(( dl_ - $(date +%s) ))
    [ "$l_" -gt 0 ] || { rc_=2; break; }
    sleep 1; t_=${l_}s
  done
  if [ "$rc_" = 2 ]; then  # bb thread wait exits 2 on timeout, and only then
    m_="timeout: $id_ has not finished the work pending at $since_ after ${to_:-20m}; check it (runtime.sh show $id_, runtime.sh quota); a worker paused on a usage limit never reports"
  else
    m_=$o_
  fi
  if [ -n "$nt_" ]; then
    [ "$rc_" = 2 ] || m_="waiting on $id_ failed: $m_"
    bb thread tell "$nt_" --mode auto "watchdog: $m_ (stale only if a report from $id_ reached you after $since_)" >/dev/null 2>&1 || true
    exit 0
  fi
  if [ "$rc_" = 2 ]; then printf '%s\n' "$m_"; exit 2; fi
  printf '%s\n' "$m_" >&2; exit 1
}

# quota [provider]: each pool account's usage windows and reset times, with a verdict (ok | near limit | limited).
quota() {
  [ $# -le 1 ] || die "quota [provider]"
  if [ "$(detect)" != bb ]; then echo "quota: unknown here; this runtime reports no usage windows. At a usage limit, move to the roster's fallback"; return 0; fi
  case ${1:-} in claude-code) want=claude ;; *) want=${1:-} ;; esac
  j_=$(bb pool account list --json) || die "quota: bb pool account list failed"
  printf '%s\n' "$j_" | awk -v want="$want" -v now="$(date +%s)" '
    function ind(l) { match(l, /^ */); return RLENGTH }
    function val(l) { sub(/^[^:]*: */, "", l); sub(/,$/, "", l); gsub(/"/, "", l); return l }
    function span(m) { return (m % 1440 == 0) ? (m / 1440) "d" : (m % 60 == 0) ? (m / 60) "h" : m "m" }
    function left(ms,   s) { if (ms == "null" || ms == "") return "no reset time"; s = int(ms / 1000) - now
      if (s <= 0) return "reset due"
      if (s >= 86400) return "resets in " int(s / 86400) "d" int(s % 86400 / 3600) "h"
      if (s >= 3600) return "resets in " int(s / 3600) "h" int(s % 3600 / 60) "m"
      return "resets in " int(s / 60) "m" }
    # Verdicts, worst first: 0 disabled, 1 limited, 2 near limit, 3 ok, 4 unknown (no reading). A window at 100%, or with a status
    # other than allowed, is limited; one of a day or less at 85%+, or longer at 90%+, is near. Shared windows (limitWindows) rate
    # the account; the weekly window of a model family (familyWeekly) rates only that family.
    function win(name, u, r, st, mins, fam,   v) { pct = (u == "null" || u == "") ? "?" : int(u * 100 + 0.5) "%"
      out = out (out == "" ? "" : " · ") name " " pct " (" left(r) ")"
      if ((u == "null" || u == "") && (st == "null" || st == "")) return
      v = (st != "" && st != "null" && st !~ /^allowed/ || u + 0 >= 1) ? 1 : (u + 0 >= (mins + 0 <= 1440 ? 0.85 : 0.90)) ? 2 : 3
      if (fam == "") { seen = 1; if (v < sv) sv = v } else { fseen[fam] = 1; if (!((na + 1, fam) in af) || v < af[na + 1, fam]) af[na + 1, fam] = v } }
    function word(v) { return v == 0 ? "disabled" : v == 1 ? "limited" : v == 2 ? "near limit" : v == 3 ? "ok" : "unknown" }
    function rank(v) { return v == 4 ? 2.5 : v }  # ok > unknown > near limit > limited > disabled
    function flush(   v, f, fl) { if (prov == "" || (want != "" && prov != want)) return
      v = (enabled == "false") ? 0 : (status != "ready") ? 1 : !seen ? 4 : sv
      na++; ap[na] = prov; av[na] = v; fl = ""
      for (f in fseen) if ((na, f) in af && af[na, f] < 3) fl = fl ", " f " " word(af[na, f])
      printf "%s  %s  %s  %s → %s%s\n", prov, label, status, (out == "" ? "no windows observed" : out), word(v), fl }
    /"provider":/ { flush(); for (f in fseen) delete af[na + 1, f]; prov = val($0); pi = ind($0); label = status = enabled = out = sec = ""; seen = 0; sv = 3; next }
    prov == "" { next }
    ind($0) == pi && /"label":/ { label = val($0); next }
    ind($0) == pi && /"enabled":/ { enabled = val($0); next }
    ind($0) == pi && /"status":/ { status = val($0); next }
    ind($0) == pi && /"limitWindows":/ { sec = "win"; next }
    ind($0) == pi && /"familyWeekly":/ { sec = "fam"; next }
    ind($0) == pi { sec = ""; next }
    sec == "fam" && /": \{$/ { fam = $0; sub(/^ *"/, "", fam); sub(/".*/, "", fam); wm = 10080; u = r = st = ""; next }
    sec == "win" && /"windowMinutes":/ { wm = val($0); u = r = st = ""; next }
    sec != "" && /"utilization":/ { u = val($0); next }
    sec != "" && /"resetAt":/ { r = val($0); next }
    sec != "" && /"status":/ { st = val($0); win(sec == "fam" ? fam " " span(wm) : span(wm), u, r, st, wm, sec == "fam" ? fam : ""); next }
    END { flush(); if (!na) { print "quota: no pool accounts" (want != "" ? " for " want : "") "; unknown"; exit }
      # The pool sends work to any usable account, so a provider is as good as its best account, and a model family on it
      # as good as its best account for that family (an account with no reading for the family counts as the account).
      for (i = 1; i <= na; i++) { p = ap[i]; if (!(p in best)) { pn[++np] = p; best[p] = av[i] } else if (rank(av[i]) > rank(best[p])) best[p] = av[i] }
      for (j = 1; j <= np; j++) { p = pn[j]; fl = ""
        for (f in fseen) { fb = -1
          for (i = 1; i <= na; i++) if (ap[i] == p) { x = ((i, f) in af && af[i, f] < av[i]) ? af[i, f] : av[i]; if (fb < 0 || rank(x) > rank(fb)) fb = x }
          if (fb >= 0 && rank(fb) < rank(best[p])) fl = fl ", " f " " word(fb) }
        printf "%s: %s%s\n", p, word(best[p]), fl } }'
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
  threads) shift; threads "$@" ;;
  show) [ -n "$2" ] || die "show <id>"; bb_or_print "no thread details here; your workers are the agents you started in this session (IDs in your ledger)" get "$2" ;;
  retry) [ -n "$2" ] || die "retry <id>"; bb_or_print "resume agent $2 (SendMessage on Claude Code, send-message on Codex) asking it to continue its brief; if it is gone, make the spawn call again with the same brief" retry "$2" ;;
  wait) shift; wait_for "$@" ;;
  quota) shift; quota "$@" ;;
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
