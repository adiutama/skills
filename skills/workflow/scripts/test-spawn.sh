#!/bin/sh
# test-spawn.sh — checks runtime.sh spawn (all modes) and spawn-check.sh with WORKFLOW_DRY_RUN; no real threads.
here=$(cd "$(dirname "$0")" && pwd)
H="sh $here/runtime.sh"; C="sh $here/spawn-check.sh"
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
export CLAUDECODE=1 WORKFLOW_RUNTIME=bb WORKFLOW_DRY_RUN=1 BB_THREAD_ID=thr_origin BB_PROJECT_ID=proj_1 BB_ENVIRONMENT_ID=env_1 BB_THREAD_STORAGE=$t/st FAKE_STATE=$t/fs
mkdir -p "$t/st/workers/s1"; echo "Role: Implementer" > "$t/b.md"
fail=0
ok() { if [ "$1" = 0 ]; then echo "ok   $2"; else echo "FAIL $2"; fail=1; fi; }
has() { printf '%s\n' "$1" | grep -qF -- "$2"; }
hasnt() { ! has "$1" "$2"; }

# fake bb: project kind, provider list ($FAKE_PROVIDERS; --json: permission modes, the providers in $FAKE_NOAUTO have no auto) and models,
# roster memory ($FAKE_ROSTER file, absent = no roster; named $FAKE_ROSTER_NAME, default agent-roster-v2; add/update logged to $FAKE_MEM_LOG),
# thread spawn (prints $FAKE_ID, default thr_new1; records the title for thread get; fails for a provider in $FAKE_SPAWN_FAIL or
# an unsupported permission mode; sleeps $FAKE_SPAWN_SLEEP; runs $FAKE_SPAWN_CHILD as the new thread before returning),
# thread get (the recorded title; fails with $FAKE_GET_FAIL), thread list ($FAKE_CHILDREN with their recorded titles; fails with
# $FAKE_LIST_FAIL), thread stop (logged to $FAKE_STOPPED; runs $FAKE_STOP_RUN first; fails for an id in $FAKE_STOP_FAIL),
# thread get of an id in $FAKE_GONE (thread_not_found, shaped like bb's), or a failed get printing $FAKE_GET_JSON,
# thread wait (args logged to $FAKE_STATE/wait.args, calls to wait.log; $FAKE_WAIT=timeout prints bb's timeout and exits 2, fail exits 1,
# conn prints a connection failure whose message says "Timed out" and exits 1; each call runs the next line of
# $FAKE_STATE/steps.<id>, or else, unless $FAKE_QUEUE_STUCK, ends a turn: one message queued in $FAKE_STATE/queued.<id> starts and a
# turn/completed joins $FAKE_STATE/log.<id>, lines "<seq> <type>"), thread get (runs the next line of $FAKE_STATE/getsteps.<id> first;
# status from status.<id>, default idle; that queue count, omitted with $FAKE_GET_NOQUEUE; $FAKE_GET_PARTIAL cuts the payload after the
# thread block and exits with its value), thread log --json [--after-seq N] (the events of log.<id> after N, shaped like bb's; fails
# with $FAKE_LOG_FAIL; $FAKE_LOG_TRUNC drops the closing bracket of an --after-seq read), thread tell (logged to tell.log),
# pool account list --json (prints the file $FAKE_POOL)
mkdir -p "$t/bin"
cat > "$t/bin/bb" <<'FAKE'
#!/bin/sh
pop() { tail -n +2 "$1" > "$1.t"; mv "$1.t" "$1"; }
case "$1 $2" in
  "project show")
    if [ "$3" = proj_personal ]; then k=personal; else k=standard; fi
    printf '{\n  "id": "%s",\n  "kind": "%s",\n  "name": "x"\n}\n' "$3" "$k" ;;
  "provider list")
    if [ "$3" = --json ]; then
      printf '[\n'; for p in ${FAKE_PROVIDERS-claude-code codex acp-opencode}; do
        case " ${FAKE_NOAUTO-} " in *" $p "*) ms="accept-edits full" ;; *) ms="accept-edits auto full" ;; esac
        printf '  {\n    "id": "%s",\n    "capabilities": {\n      "permissionModes": [\n' "$p"; for m in $ms; do printf '        "%s",\n' "$m"; done
        printf '      ],\n    },\n    "reasoningLevels": [\n      {\n        "id": "low",\n      },\n    ],\n  },\n'
      done; printf ']\n'
    else printf 'ID    Name\n----  ----\n'; for p in ${FAKE_PROVIDERS-claude-code codex acp-opencode}; do printf '%s  x\n------  ----\n' "$p"; done; fi ;;
  "provider models")
    case $3 in
      claude-code) ms="claude-opus-5-5 claude-sonnet-5-5 claude-haiku-5-5 claude-fable-5-2" ;;
      codex) ms="gpt-6.2-sol gpt-6-luna" ;;
      acp-opencode) ms="opencode-go/grok-4.7 opencode-go/glm-5.3" ;;
    esac
    printf '{\n  "models": [\n'; for m in $ms; do printf '    "id": "%s",\n' "$m"; done; printf '  ]\n}\n' ;;
  "thread spawn")
    id=${FAKE_ID:-thr_new1} ti= pv= pm=; shift 2
    while [ $# -gt 0 ]; do case $1 in --title) ti=$2; shift ;; --provider) pv=$2; shift ;; --permission-mode) pm=$2; shift ;; esac; shift; done
    case " ${FAKE_SPAWN_FAIL-} " in *" $pv "*) echo "HTTP 500: launch failed on $pv" >&2; exit 1 ;; esac
    case " ${FAKE_NOAUTO-} " in *" $pv "*) [ "$pm" != auto ] || { echo "HTTP 400: permission mode auto is not supported by $pv" >&2; exit 1; } ;; esac
    mkdir -p "$FAKE_STATE/titles"; printf '%s\n' "$ti" > "$FAKE_STATE/titles/$id"
    [ -z "$FAKE_SPAWN_SLEEP" ] || sleep "$FAKE_SPAWN_SLEEP"
    if [ -n "$FAKE_SPAWN_CHILD" ]; then
      (BB_THREAD_ID=$id BB_THREAD_STORAGE=${BB_THREAD_STORAGE%/*}/$id; export BB_THREAD_ID BB_THREAD_STORAGE; mkdir -p "$BB_THREAD_STORAGE"
       sh -c "$FAKE_SPAWN_CHILD" > "$FAKE_STATE/child.out" 2>&1; echo $? > "$FAKE_STATE/child.rc")
    fi
    printf '{\n  "id": "%s",\n  "title": "x"\n}\n' "$id" ;;
  "thread get") case " ${FAKE_GONE-} " in *" $3 "*) printf '{\n  "ok": false,\n  "error": {\n    "code": "thread_not_found",\n    "message": "HTTP 404: Thread not found"\n  }\n}\n'; exit 1 ;; esac
    [ -z "$FAKE_GET_JSON" ] || { printf '%s\n' "$FAKE_GET_JSON"; exit 1; }
    [ -z "$FAKE_GET_FAIL" ] || { printf '{"ok": false, "error": {"code": "unavailable"}}\n'; exit 1; }
    [ ! -s "$FAKE_STATE/getsteps.$3" ] || { sh -c "$(head -1 "$FAKE_STATE/getsteps.$3")"; pop "$FAKE_STATE/getsteps.$3"; }
    printf '{\n  "thread": {\n    "id": "%s",\n    "title": "%s",\n    "status": "%s",\n' "$3" "$(cat "$FAKE_STATE/titles/$3" 2>/dev/null)" "$(cat "$FAKE_STATE/status.$3" 2>/dev/null || echo idle)"
    [ -n "${FAKE_GET_NOQUEUE-}" ] || printf '    "queuedMessageCount": %s\n' "$(cat "$FAKE_STATE/queued.$3" 2>/dev/null || echo 0)"
    [ -z "${FAKE_GET_PARTIAL-}" ] || { printf '  },\n'; exit "$FAKE_GET_PARTIAL"; }
    printf '  },\n  "environment": {\n    "status": "ready"\n  }\n}\n' ;;
  "thread log") id=$3; [ -z "${FAKE_LOG_FAIL-}" ] || { printf '{\n  "ok": false,\n  "error": {\n    "code": "unavailable"\n  }\n}\n'; exit 1; }
    a=0; while [ $# -gt 0 ]; do [ "$1" != --after-seq ] || a=$2; shift; done
    e=$([ ! -f "$FAKE_STATE/log.$id" ] || while read -r sq ty; do [ "$sq" -le "$a" ] || printf '  {\n    "id": "evt_%s",\n    "seq": %s,\n    "type": "%s",\n    "data": {\n      "item": {\n        "type": "turn/completed"\n      }\n    }\n  },\n' "$sq" "$sq" "$ty"; done < "$FAKE_STATE/log.$id")
    if [ -n "$e" ] && [ -n "${FAKE_LOG_TRUNC-}" ] && [ "$a" != 0 ]; then printf '[\n%s\n' "$e"
    elif [ -n "$e" ]; then printf '[\n%s\n]\n' "$e"; else echo '[]'; fi ;;  # bb prints an empty log as []
  "thread list") [ -z "$FAKE_LIST_FAIL" ] || { printf '{"ok": false, "error": {"code": "unavailable"}}\n'; exit 1; }
    printf '[\n'; for c in $FAKE_CHILDREN; do printf '  {\n    "id": "%s",\n    "title": "%s",\n  },\n' "$c" "$(cat "$FAKE_STATE/titles/$c" 2>/dev/null)"; done; printf ']\n' ;;
  "thread stop") [ -z "$FAKE_STOP_RUN" ] || sh -c "$FAKE_STOP_RUN"
    case " ${FAKE_STOP_FAIL-} " in *" $3 "*) echo "HTTP 500: stop failed" >&2; exit 1 ;; esac
    echo "$3" >> "$FAKE_STOPPED" ;;
  "thread wait") mkdir -p "$FAKE_STATE"; shift 2; echo "$*" > "$FAKE_STATE/wait.args"; echo "$*" >> "$FAKE_STATE/wait.log"
    case ${FAKE_WAIT-} in
      timeout) echo "Error: Timed out waiting for thread $1 to reach status idle."; exit 2 ;;
      fail) echo "Error: HTTP 404: Thread not found"; exit 1 ;;
      conn) printf '{"ok": false, "error": {"code": "connection_failed", "message": "Timed out connecting to controller"}}\n'; exit 1 ;;
    esac
    if [ -s "$FAKE_STATE/steps.$1" ]; then sh -c "$(head -1 "$FAKE_STATE/steps.$1")"; pop "$FAKE_STATE/steps.$1"
    elif [ -z "${FAKE_QUEUE_STUCK-}" ]; then
      n=$(cat "$FAKE_STATE/queued.$1" 2>/dev/null || echo 0); [ "$n" = 0 ] || echo $((n - 1)) > "$FAKE_STATE/queued.$1"
      echo "$(( $(tail -1 "$FAKE_STATE/log.$1" 2>/dev/null | cut -d' ' -f1) + 1 )) turn/completed" >> "$FAKE_STATE/log.$1"
    fi
    printf '{\n  "threadId": "%s",\n  "matched": true\n}\n' "$1" ;;
  "pool account") cat "$FAKE_POOL" ;;
  "thread tell") echo "$*" >> "$FAKE_STATE/tell.log" ;;
  "memory search")
    [ -f "$FAKE_ROSTER" ] && printf '{\n  "memories": [\n    {\n      "id": "mem_r",\n    }\n  ]\n}\n' ;;
  "memory get")
    [ -f "$FAKE_ROSTER" ] && printf '{\n  "memory": {\n    "id": "mem_r",\n    "name": "%s",\n    "details": "%s",\n    "version": 1\n  }\n}\n' "${FAKE_ROSTER_NAME:-agent-roster-v2}" "$(awk '{printf "%s\\n", $0}' "$FAKE_ROSTER")" ;;
  "memory add"|"memory update") echo "$*" >> "$FAKE_MEM_LOG" ;;
esac
FAKE
chmod +x "$t/bin/bb"; PATH=$t/bin:$PATH
# A1
c=$($H spawn --role Implementer --effort medium --brief "$t/b.md" --slice s1 --isolated); has "$c" "--parent-self"; ok $? "A1 child has --parent-self"
s=$($H spawn --mode spin-off --goal G --provider claude-code --model sonnet --effort high --brief "$t/b.md" --slice sp); hasnt "$s" "--parent-self" && has "$s" "--new-environment worktree" && has "$s" "--title G"; ok $? "A1 spin-off top-level, worktree, title=goal"
f=$($H spawn --mode fresh --goal G --provider codex --model gpt-6.2-sol --effort high --brief "$t/b.md" --slice fr); hasnt "$f" "--parent-self" && has "$f" "bb thread update thr_origin --parent-thread '<new>' --parent-notifications off"; ok $? "A1 fresh re-parents origin"
# A2
b=$(cat "$t/st/briefs/sp-spin-off-1.md"); has "$b" "@thread:thr_origin" && has "$b" "DONE" && has "$b" "BLOCKED" && has "$b" "FAILED" && has "$b" "bb thread tell thr_origin"; ok $? "A2 spin-off brief reporting"
$H spawn --mode spin-off --goal G --effort high --brief "$t/b.md" --slice sm --report-after-merge >/dev/null; has "$(cat "$t/st/briefs/sm-spin-off-1.md")" "only after your PR has merged"; ok $? "A2 after-merge trigger"
# A3
$H spawn --mode spin-off --goal G --effort high --brief "$t/b.md" --slice w --wait-go >/dev/null; has "$(cat "$t/st/briefs/w-spin-off-1.md")" "Hold:"; ok $? "A3 --wait-go hold"
a=$($H spawn --mode spin-off --goal G --effort high --brief "$t/b.md" --slice af --after thr_x); has "$(cat "$t/st/briefs/af-spin-off-1.md")" "thr_x" && has "$a" "bb thread tell thr_x"; ok $? "A3 --after untracked tells X"
printf '| @thread:thr_y | t |\n' > "$t/st/spin-offs.md"
a=$($H spawn --mode spin-off --goal G --effort high --brief "$t/b.md" --slice ay --after thr_y); hasnt "$a" "bb thread tell thr_y"; ok $? "A3 --after tracked: no tell"
# A4
$H spawn --mode spin-off --goal G --effort high --brief "$t/b.md" --slice nc --context none >/dev/null; hasnt "$(cat "$t/st/briefs/nc-spin-off-1.md")" "Context:"; ok $? "A4 --context none"
# W1: waiting-on column must not count as tracked
printf '| @thread:thr_z | t | d | done | thr_w | running | - |\n' > "$t/st/spin-offs.md"
a=$($H spawn --mode spin-off --goal G --effort high --brief "$t/b.md" --slice wz --after thr_w); has "$a" "bb thread tell thr_w" && has "$(cat "$t/st/briefs/wz-spin-off-1.md")" "tells you \"go\" directly"; ok $? "W1 waiting-on is not tracked"
printf '| @thread:thr_y | t |\n' > "$t/st/spin-offs.md"
# W2: none rejects a brief with a Context section
printf 'Goal: x\nContext: from the origin\n' > "$t/ctx.md"
$H spawn --mode spin-off --goal G --effort high --brief "$t/ctx.md" --slice cx --context none >/dev/null 2>&1; [ $? != 0 ]; ok $? "W2 none rejects Context: brief"
# W5: fresh always names the origin
$H spawn --mode fresh --goal G --effort high --brief "$t/b.md" --slice fo --context none --wait-go >/dev/null; has "$(cat "$t/st/briefs/fo-fresh-1.md")" "@thread:thr_origin"; ok $? "W5 fresh names origin"
# Personal project: personal workspace, not worktree
pp=$($H spawn --mode spin-off --goal G --effort high --brief "$t/b.md" --slice pp --project proj_personal); has "$pp" "--new-environment personal" && hasnt "$pp" "worktree"; ok $? "personal project uses --new-environment personal"
pf=$($H spawn --mode fresh --goal G --effort high --brief "$t/b.md" --slice pf --project proj_personal --env new); has "$pf" "--new-environment personal"; ok $? "personal project, fresh"
pi=$($H spawn --role Implementer --effort medium --brief "$t/b.md" --slice pi --isolated --project proj_personal); has "$pi" "--new-environment personal"; ok $? "personal project, isolated child"
# W4: quoting and --json
mkdir -p "$t/sp ace"; echo x > "$t/sp ace/b.md"
q=$(BB_THREAD_STORAGE="$t/st x" $H spawn --mode spin-off --goal "Fix queued status" --effort high --brief "$t/sp ace/b.md" --slice qs); has "$q" "--title 'Fix queued status'" && has "$q" "--json" && has "$q" "--prompt-file '$t/st x/briefs/qs-spin-off-1.md'"; ok $? "W4 dry-run quotes args, has --json"
# A5
for r in "$c" "$s" "$f"; do has "$r" " → @thread:<new> · " && printf '%s\n' "$r" | grep -Eq 'high|medium' ; [ $? = 0 ] || fail=1; done
has "$s" "Spun off → @thread:<new> · top-level · " && has "$s" "claude-code/claude-sonnet-5-5 · high"; ok $? "A5 receipt line"
# A6
printf 's1\tthr_old\n' > "$t/st/spawned.log"
e=$($H spawn --role Implementer --effort medium --brief "$t/b.md" --slice s1 2>&1); r=$?
[ $r != 0 ] && has "$e" "runtime.sh retry thr_old"; ok $? "A6 re-spawn refused, pointing at runtime.sh retry"
$H spawn --role Implementer --effort medium --brief "$t/b.md" --slice s1 --force >/dev/null 2>&1; ok $? "A6 --force passes"
# host passthrough
hh=$($H spawn --mode spin-off --goal G --effort high --brief "$t/b.md" --slice hh --host mac1); has "$hh" "--host mac1"; ok $? "host passed to bb thread spawn"
hn=$($H spawn --mode spin-off --goal G --effort high --brief "$t/b.md" --slice hn); hasnt "$hn" "--host"; ok $? "no --host by default"
# adopt
ad=$($H adopt thr_x); has "$ad" "bb thread update thr_x --parent-thread thr_origin --parent-notifications auto" && has "$ad" "Adopted → @thread:thr_x · child · reports every outcome"; ok $? "adopt re-parents, notifications auto"
aq=$($H adopt thr_x --quiet); has "$aq" "--parent-notifications off" && has "$aq" "reports off"; ok $? "adopt --quiet"
$H adopt thr_origin >/dev/null 2>&1; [ $? != 0 ]; ok $? "adopt refuses self"
ac=$(WORKFLOW_RUNTIME=claude-code $H adopt thr_x); has "$ac" "adopt needs bb"; ok $? "adopt outside bb prints instruction"
# release
rl=$($H release thr_x); has "$rl" "bb thread update thr_x --clear-parent-thread" && has "$rl" "Released → @thread:thr_x · top-level"; ok $? "release clears the parent"
$H release thr_origin >/dev/null 2>&1; [ $? != 0 ]; ok $? "release refuses self"
rc=$(WORKFLOW_RUNTIME=claude-code $H release thr_x); has "$rc" "release needs bb"; ok $? "release outside bb prints instruction"
# environment: fresh reuses this one by default, spin-off gets a new one, child takes --isolated not --env
has "$f" "--environment env_1" && hasnt "$f" "--new-environment" && has "$f" "env: reused"; ok $? "fresh reuses this environment by default"
has "$s" "--new-environment worktree" && hasnt "$s" "--environment env_1" && has "$s" "env: new"; ok $? "spin-off gets a new environment by default"
eh=$($H spawn --mode spin-off --goal G --effort high --brief "$t/b.md" --slice eh --env this); has "$eh" "--environment env_1" && hasnt "$eh" "--new-environment" && has "$eh" "env: reused"; ok $? "spin-off --env this reuses"
en=$($H spawn --mode fresh --goal G --effort high --brief "$t/b.md" --slice en --env new); has "$en" "--new-environment worktree" && has "$en" "env: new"; ok $? "fresh --env new"
ei=$($H spawn --mode spin-off --goal G --effort high --brief "$t/b.md" --slice ei --env env_9); has "$ei" "--environment env_9" && has "$ei" "env: env_9"; ok $? "--env <id>"
$H spawn --role Implementer --effort medium --brief "$t/b.md" --slice ec --force --env new >/dev/null 2>&1; [ $? != 0 ]; ok $? "--env rejected on child"
hasnt "$c" "env:"; ok $? "child receipt has no env field"
# model ids: bb gets full ids, not aliases
has "$($H spawn --mode spin-off --goal G --effort high --brief "$t/b.md" --slice md)" "--model claude-opus-5-5"; ok $? "default work model maps to the full model id"
# Roster v2: work / helper / council / never / fallback
cat > "$t/roster" <<'R'
Fixed format read by the workflow skill; do not merge or reword.
work      codex:gpt-6.2-sol
helper    claude-code:claude-haiku-5-5
council   codex:gpt-6.2-sol  acp-opencode:opencode-go/grok-4.7  claude-code:claude-fable-5-2  claude-code:claude-opus-5-5
never     gemini
fallback  codex>claude-code
R
sp() { FAKE_ROSTER=${RF:-none} $H spawn --effort medium --brief "$t/b.md" --force "$@" 2>"$t/err"; }
r=$(RF=$t/roster sp --role Implementer --slice v1); has "$r" "--provider codex --model gpt-6.2-sol"; ok $? "V1 roster v2: a work card runs on the work model"
r=$(RF=$t/roster sp --role Explorer --slice v1e); has "$r" "--provider claude-code --model claude-haiku-5-5"; ok $? "V1 roster v2: Explorer runs on the helper model"
r=$(RF=$t/roster sp --role Implementer --slice v1h --helper); has "$r" "--provider claude-code --model claude-haiku-5-5"; ok $? "V1 --helper puts a work card on the helper model"
r=$(RF=$t/roster sp --mode spin-off --goal G --slice v1s); has "$r" "--provider codex --model gpt-6.2-sol"; ok $? "V1 spin-off defaults to the work model"
r=$(RF=$t/roster sp --role Implementer --slice v1o --provider acp-opencode --model opencode-go/glm-5.3); has "$r" "--provider acp-opencode --model opencode-go/glm-5.3"; ok $? "V1 --provider/--model override the roster"
FAKE_ROSTER=$t/roster $H roster >"$t/out" 2>"$t/err"; has "$(cat "$t/out")" "council   codex:gpt-6.2-sol" && [ ! -s "$t/err" ]; ok $? "V1 roster prints the rules, no warnings when every model is listed"
printf 'tier.deep  claude-code:claude-opus-5-5\nreviewer.order  codex:gpt-6.2-sol\nwork  codex:gpt-6.2-sol\n' > "$t/old"
FAKE_ROSTER=$t/old $H roster >/dev/null 2>"$t/err"; has "$(cat "$t/err")" "stale: old roster format (tier./role./reviewer. lines); suggest a v2 roster"; ok $? "V2 old format warns on stderr"
printf 'tier.fast  codex:gpt-6-luna\nrole.explorer  codex:gpt-6-luna\n' > "$t/old2"
r=$(RF=$t/old2 sp --role Explorer --slice v2); has "$r" "--provider claude-code --model claude-haiku-5-5"; ok $? "V2 old tier./role. lines are not read"
printf 'work  claude-code:claude-nope\ncouncil  zed:z-1  codex:gpt-6.2-sol\nnever  gemini\nfallback  claude-code>ghost\n' > "$t/bad"
FAKE_ROSTER=$t/bad $H roster >/dev/null 2>"$t/err"; e=$(cat "$t/err"); has "$e" "stale: claude-code:claude-nope not in providers" && has "$e" "stale: zed:z-1 not in providers" && has "$e" "stale: fallback ghost not in providers" && hasnt "$e" "gemini" && hasnt "$e" "gpt-6.2-sol"; ok $? "V3 roster flags models missing from providers, not never"
r=$(sp --role Implementer --slice d1); has "$r" "--provider claude-code --model claude-opus-5-5"; ok $? "D1 no roster: work = this vendor's deep model"
r=$(sp --role Explorer --slice d2); has "$r" "--model claude-haiku-5-5"; ok $? "D1 no roster: helper = this vendor's fast model"
[ "$($H model work)" = opus ] && [ "$($H model helper codex)" = gpt-6-luna ] && [ "$($H model work codex)" = gpt-6.2-sol ]; ok $? "D2 model work|helper"
$H model deep >/dev/null 2>&1; [ $? != 0 ]; ok $? "D2 model <old tier> fails"
sp --role Implementer --slice tt --tier deep >/dev/null; [ $? != 0 ]; ok $? "T1 removed --tier fails loudly"
sp --role Implementer --slice tw --why x >/dev/null; [ $? != 0 ]; ok $? "T1 removed --why fails loudly"
r=$(RF=$t/roster sp --role Reviewer --slice rr --author claude-code:claude-opus-5-5); has "$r" "--provider codex --model gpt-6.2-sol" && has "$(cat "$t/st/briefs/rr-child-1.md")" "Reviewer, chairing the council"; ok $? "T2 --role reviewer chairs a council"
r=$(RF=$t/roster sp --role council-chair --slice rr2 --author claude-code:claude-opus-5-5); has "$r" "--provider codex --model gpt-6.2-sol"; ok $? "T2 --role council-chair stays an alias for reviewer"
sp --role Consultant --slice rc >/dev/null; [ $? != 0 ]; ok $? "T2 Consultant role is gone"
# Council chair: first council entry that is not the author's model, nor never/limited/missing
ch() { sp --role reviewer "$@"; }
r=$(RF=$t/roster ch --slice c1 --author claude-code:claude-opus-5-5); has "$r" "--provider codex --model gpt-6.2-sol"; ok $? "C1 chair: first council entry"
r=$(RF=$t/roster ch --slice c2 --author codex:gpt-6.2-sol); has "$r" "--provider acp-opencode --model opencode-go/grok-4.7"; ok $? "C1 chair skips the author's model"
r=$(RF=$t/roster ch --slice c3 --author claude-code:claude-opus-5-5 --limited codex,acp-opencode); has "$r" "--provider claude-code --model claude-fable-5-2"; ok $? "C1 chair skips limited vendors"
r=$(FAKE_PROVIDERS="claude-code acp-opencode" RF=$t/roster ch --slice c4 --author claude-code:claude-opus-5-5); has "$r" "--provider acp-opencode"; ok $? "C1 chair skips missing providers"
printf 'council  gemini:g-3  codex:gpt-6.2-sol\nnever  gemini\n' > "$t/roster3"
r=$(RF=$t/roster3 ch --slice c5 --author claude-code:claude-opus-5-5); has "$r" "--provider codex"; ok $? "C1 chair skips never"
r=$(RF=$t/roster ch --slice c6 --author claude-code:opus); has "$r" "--provider codex"; ok $? "C1 author alias matches the full id"
r=$(RF=$t/roster ch --slice c7 --author codex:gpt-6.2-sol --limited acp-opencode,claude-code 2>&1); [ $? != 0 ] && has "$(cat "$t/err")" "no council model"; ok $? "C1 no eligible chair fails"
r=$(ch --slice c8 --author codex:gpt-6.2-sol); has "$r" "--provider claude-code --model claude-opus-5-5"; ok $? "C1 no roster: default council is the other vendor's deep model, then this vendor's"
r=$(ch --slice c9 --author claude-code:claude-opus-5-5); has "$r" "--provider codex --model gpt-6.2-sol"; ok $? "C1 no roster, Claude-authored: codex chairs"
ch --slice c10 >/dev/null; [ $? != 0 ]; ok $? "C2 chair needs --author"
ch --slice c11 --author codex:gpt-6.2-sol --size 4 >/dev/null; [ $? != 0 ]; ok $? "C2 --size is 2 or 3"
(RF=$t/roster ch --slice c12 --author claude-code:claude-opus-5-5 --size 3 --limited acp-opencode) >/dev/null; b=$(cat "$t/st/briefs/c12-child-1.md"); has "$b" "Size:     3" && has "$b" "--role council-member --author claude-code:claude-opus-5-5 --chair codex:gpt-6.2-sol --limited acp-opencode"; ok $? "C2 size and member command recorded in the chair's brief"
(RF=$t/roster ch --slice c13 --author claude-code:claude-opus-5-5) >/dev/null; has "$(cat "$t/st/briefs/c13-child-1.md")" "Size:     2"; ok $? "C2 size defaults to 2"
sp --role Implementer --slice c14 --size 3 >/dev/null; [ $? != 0 ]; ok $? "C2 --size only for council-chair"
r=$(RF=$t/roster ch --slice c15 --author claude-code:claude-opus-5-5 --helper); [ $? != 0 ]; ok $? "C2 --helper refused on council roles"
# W7: the Reviewer's Council block names the member-brief folder, the one the script reads the member's report from
b=$(cat "$t/st/briefs/c13-child-1.md"); has "$b" "--brief \"\$(sh $here/runtime.sh storage)/workers/<member name>/brief.md\"" && hasnt "$b" "--slice '<member name>'" && has "$b" "Storage: line"; ok $? "W7 on bb the member command puts the brief in the Reviewer's script storage"
# Markers: a real spawn writes them into the worker's storage (the brief folder and the new thread's own storage)
mkdir -p "$t/live/st"
(BB_THREAD_STORAGE=$t/live/st WORKFLOW_DRY_RUN= FAKE_ROSTER=$t/roster $H spawn --role council-chair --author claude-code:claude-opus-5-5 --size 3 --effort medium --brief "$t/b.md" --slice m1 >/dev/null 2>&1)
grep -q '^size 3$' "$t/live/st/workers/m1/.council-chair" 2>/dev/null && grep -q '^chair codex:gpt-6.2-sol$' "$t/live/thr_new1/.council-chair" 2>/dev/null; ok $? "M1 chair marker written to both storages"
grep -q "Reviewer · m1$" "$FAKE_STATE/titles/thr_new1" 2>/dev/null; ok $? "M1 a Reviewer is titled … › Reviewer · <slice>"
# Member pick, run inside a chair (its storage holds .council-chair)
mkdir -p "$t/chair"; printf 'chair codex:gpt-6.2-sol\nauthor claude-code:claude-opus-5-5\nsize 3\nlimited -\n' > "$t/chair/.council-chair"
mb() { BB_THREAD_STORAGE=$t/chair sp --role council-member --author claude-code:claude-opus-5-5 --chair codex:gpt-6.2-sol "$@"; }
r=$(RF=$t/roster mb --slice k1); has "$r" "--provider acp-opencode --model opencode-go/grok-4.7"; ok $? "K1 member skips the chair's family and the author"
has "$r" "--lifecycle-owner-thread thr_origin"; ok $? "L0 a member's lifecycle owner is its chair (archiving the chair archives and stops it)"
r=$(RF=$t/roster ch --slice l0 --author claude-code:claude-opus-5-5); hasnt "$r" "--lifecycle-owner-thread"; ok $? "L0 a chair has no lifecycle owner"
mkdir -p "$t/chair/workers/mx"; echo "Role: council-member" > "$t/chair/workers/mx/brief.md"
r=$(BB_THREAD_STORAGE=$t/chair FAKE_ROSTER=$t/roster $H spawn --role council-member --author claude-code:claude-opus-5-5 --chair codex:gpt-6.2-sol --effort medium --brief "$t/chair/workers/mx/brief.md" 2>&1); has "$r" "Council member · mx"; ok $? "W7 a member brief in that folder names the member, so report.md is looked up there"
printf 'codex:gpt-6.2-sol\tacp-opencode:opencode-go/grok-4.7\tthr_m1\n' > "$t/chair/council.log"
r=$(RF=$t/roster mb --slice k2); has "$r" "--provider claude-code --model claude-fable-5-2"; ok $? "K1 member skips existing members"
has "$(cat "$t/chair/briefs/k2-child-1.md")" "council member on claude-code:claude-fable-5-2"; ok $? "K1 member brief names its model and chair"
printf 'codex:gpt-6.2-sol\tacp-opencode:opencode-go/grok-4.7\tthr_m1\ncodex:gpt-6.2-sol\tclaude-code:claude-fable-5-2\tthr_m2\n' > "$t/chair/council.log"
(RF=$t/roster mb --slice k3) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "council is full"; ok $? "K2 size cap: at most size-1 members"
# K5 W4: a member that cannot resume gives its seat to a replacement (--replace <thread id | P:ID>); the size cap holds
(RF=$t/roster mb --slice k6r --replace thr_m1) >"$t/out" 2>"$t/err"; [ $? = 0 ] && has "$(cat "$t/out")" "--provider acp-opencode"; ok $? "K5 --replace seats a member in a full council in place of that seat"
(RF=$t/roster mb --slice k7r --replace thr_nope) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "no seat"; ok $? "K5 --replace needs a seat of this council"
(RF=$t/roster mb --slice k8r) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "council is full"; ok $? "K5 a dry run leaves the seat in place"
(RF=$t/roster sp --role Implementer --slice k9r --replace thr_m1) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "--replace is for --role council-member"; ok $? "K5 --replace is for council members only"
: > "$t/stopped"; (BB_THREAD_STORAGE=$t/chair WORKFLOW_DRY_RUN= FAKE_ID=thr_m3 FAKE_STOPPED=$t/stopped FAKE_ROSTER=$t/roster $H spawn --role council-member --author claude-code:claude-opus-5-5 --chair codex:gpt-6.2-sol --effort medium --brief "$t/b.md" --slice k10r --replace thr_m1 >/dev/null 2>"$t/err")
grep -q "	retired:thr_m1$" "$t/chair/council.log" && grep -q "	thr_m3$" "$t/chair/council.log" && grep -qx thr_m1 "$t/stopped"; ok $? "K5 the replaced seat is logged retired, its thread stopped, the new member seated"
(RF=$t/roster mb --slice k11r) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "council is full"; ok $? "K5 after a replacement the council is full again"
printf 'codex:gpt-6.2-sol\tacp-opencode:opencode-go/grok-4.7\tthr_m1\n' > "$t/chair/council.log"
(RF=$t/roster mb --slice k4 --limited claude-code) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "rule with fewer"; ok $? "K3 no member left fails, chair rules with fewer"
(RF=$t/roster mb --slice k5 --chair acp-opencode:opencode-go/grok-4.7) >/dev/null; [ $? != 0 ]; ok $? "K4 --chair must match the chair's marker"
rm -f "$t/chair/council.log"
# S: a council needs 2 seats on different models; a new family is preferred, the same family is allowed when none is left
mkdir -p "$t/sc"; printf 'chair claude-code:claude-fable-5-2\nauthor claude-code:claude-opus-5-5\nsize 3\nlimited -\n' > "$t/sc/.council-chair"
ms() { BB_THREAD_STORAGE=$t/sc sp --role council-member --author claude-code:claude-opus-5-5 --chair claude-code:claude-fable-5-2 "$@"; }
printf 'council  claude-code:claude-opus-5-5  claude-code:claude-fable-5-2  claude-code:claude-sonnet-5-5\n' > "$t/rs1"
r=$(RF=$t/rs1 ch --slice s1c --author claude-code:claude-opus-5-5); has "$r" "--model claude-fable-5-2"; ok $? "S1 single-family roster: the chair is the first model that is not the author's"
r=$(RF=$t/rs1 ms --slice s1m); has "$r" "--model claude-sonnet-5-5" && has "$(cat "$t/err")" "same family as Reviewer"; ok $? "S1 single-family roster seats a second, distinct model, marked same family as chair"
has "$(cat "$t/sc/briefs/s1m-child-1.md")" "same family as Reviewer"; ok $? "S1 the member's brief carries the same-family mark"
printf 'council  codex:gpt-6.2-sol  codex:gpt-6-luna  claude-code:claude-fable-5-2\n' > "$t/rs2"
r=$(RF=$t/rs2 mb --slice s2); has "$r" "--model claude-fable-5-2" && hasnt "$(cat "$t/err")" "same family"; ok $? "S2 mixed roster: a new family is preferred over a same-family model listed first"
(RF=$t/rs2 mb --slice s2e --provider codex --model gpt-6-luna) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "family openai taken"; ok $? "S2 an explicit same-family member is refused while a new family is eligible"
printf 'claude-code:claude-fable-5-2\tclaude-code:claude-sonnet-5-5\tthr_s1\n' > "$t/sc/council.log"
printf 'council  claude-code:claude-sonnet-5-5  claude-code:sonnet  claude-code:claude-fable-5-2  claude-code:claude-opus-5-5\n' > "$t/rs3"
(RF=$t/rs3 ms --slice s3) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "claude-code:sonnet(seated)"; ok $? "S3 a model already seated is never seated again, even by alias"
(RF=$t/rs3 ms --slice s3e --model claude-sonnet-5-5) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "(seated)"; ok $? "S3 an explicit duplicate model is refused"
rm -f "$t/sc/council.log"
printf 'council  claude-code:claude-fable-5-2  claude-code:claude-opus-5-5\n' > "$t/rs4"
(RF=$t/rs4 ms --slice s4) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "claude-code:claude-opus-5-5(author)"; ok $? "S4 the author's model is refused in the same-family pass"
has "$(cat "$t/err")" 'council: 1 of 3' && hasnt "$(cat "$t/err")" "too few families"; ok $? "S5 fewer than 2 seats: the verdict is marked council: 1 of 3"
r=$(FAKE_PROVIDERS=claude-code ch --slice s6c --author claude-code:claude-opus-5-5); has "$r" "--model claude-fable-5-2"; ok $? "S6 no roster, claude-code only, Opus author: the built-in chair is fable"
r=$(FAKE_PROVIDERS=claude-code ms --slice s6m); has "$r" "--model claude-sonnet-5-5"; ok $? "S6 no roster, claude-code only: the built-in member is sonnet"
mkdir -p "$t/sx"; printf 'chair codex:gpt-6.2-astra\nauthor codex:gpt-6.2-sol\nsize 2\nlimited -\n' > "$t/sx/.council-chair"
r=$(CLAUDECODE= FAKE_PROVIDERS=codex ch --slice s7c --author codex:gpt-6.2-sol); has "$r" "--provider codex --model gpt-6.2-astra"; ok $? "S7 no roster, codex only, sol author: the built-in chair is astra"
r=$(CLAUDECODE= FAKE_PROVIDERS=codex BB_THREAD_STORAGE=$t/sx sp --role council-member --author codex:gpt-6.2-sol --chair codex:gpt-6.2-astra --slice s7m); has "$r" "--provider codex --model gpt-6-luna"; ok $? "S7 no roster, codex only: the built-in member is luna"
# Family = the model's maker (from the model id, any "<vendor>/" prefix stripped), else the provider id
printf 'council  acp-opencode:opencode/gpt-6.2-sol  acp-opencode:opencode-go/grok-5  acp-opencode:opencode-go/glm-5.3  claude-code:claude-fable-5-2\n' > "$t/rf"
r=$(RF=$t/rf mb --slice f1); has "$r" "--provider acp-opencode --model opencode-go/grok-5"; ok $? "F1 opencode/gpt-6.2-sol is rejected when the chair is codex:gpt-6.2-sol (same maker)"
printf 'codex:gpt-6.2-sol\tacp-opencode:opencode-go/grok-4.7\tthr_m1\n' > "$t/chair/council.log"
r=$(RF=$t/rf mb --slice f2); has "$r" "--provider acp-opencode --model opencode-go/glm-5.3"; ok $? "F2 a member differs in family from every existing member"
rm -f "$t/chair/council.log"
mkdir -p "$t/chair2"; printf 'chair acp-opencode:opencode-go/grok-4.7\nauthor claude-code:claude-opus-5-5\nsize 3\nlimited -\n' > "$t/chair2/.council-chair"
m2() { BB_THREAD_STORAGE=$t/chair2 sp --role council-member --author claude-code:claude-opus-5-5 --chair acp-opencode:opencode-go/grok-4.7 "$@"; }
printf 'council  acp-opencode:opencode-go/grok-4.7  acp-opencode:opencode-go/glm-5.3\n' > "$t/rf2"
r=$(RF=$t/rf2 m2 --slice f3); has "$r" "--provider acp-opencode --model opencode-go/glm-5.3"; ok $? "F3 two opencode models of different makers both sit on one council"
printf 'council  acp-opencode:x/mystery-1  acp-opencode:y/mystery-2  codex:gpt-6-luna\n' > "$t/rf3"
r=$(RF=$t/rf3 m2 --slice f4); has "$r" "--model x/mystery-1"; ok $? "F4 an unknown model's family is its provider (differs from the chair's xai)"
printf 'acp-opencode:opencode-go/grok-4.7\tacp-opencode:x/mystery-1\tthr_m1\n' > "$t/chair2/council.log"
r=$(RF=$t/rf3 m2 --slice f5); has "$r" "--provider codex --model gpt-6-luna"; ok $? "F4 two unknown models on one provider share a family"
rm -f "$t/chair2/council.log"
printf 'council  claude-code:claude-fable-5-2  acp-opencode:opencode-go/grok-4.7  acp-opencode:opencode-go/glm-5.3\nnever  anthropic xai\n' > "$t/rf4"
r=$(RF=$t/rf4 ch --slice f6 --author codex:gpt-6.2-sol); has "$r" "--model opencode-go/glm-5.3"; ok $? "F5 never matches the family as well as the provider"
r=$(RF=$t/rf ch --slice f7 --author codex:gpt-6.2-sol); has "$r" "--model opencode-go/grok-5"; ok $? "F6 the author's model is excluded through any provider (opencode/gpt-6.2-sol = codex:gpt-6.2-sol)"
r=$(RF=$t/rf3 ch --slice f8 --author codex:gpt-6.2-sol); has "$r" "--model x/mystery-1" && r=$(printf 'council  codex:gpt-6-luna\n' > "$t/rf5"; RF=$t/rf5 ch --slice f9 --author codex:gpt-6.2-sol) && has "$r" "--model gpt-6-luna"; ok $? "F6 the author is excluded by model, not by family"
# W1: an explicit --provider/--model goes through the same eligibility rules as a pick
(RF=$t/roster mb --slice w1a --model opus) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "(author)"; ok $? "W1 an explicit member model that is the author's (alias) is refused"
(RF=$t/roster mb --slice w1b --provider codex --model gpt-6-luna) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "family openai taken"; ok $? "W1 an explicit member model of the chair's family is refused"
(RF=$t/roster ch --slice w1c --author claude-code:claude-opus-5-5 --provider claude-code --model opus) >/dev/null; [ $? != 0 ]; ok $? "W1 an explicit chair model that is the author's is refused"
(RF=$t/rf4 ch --slice w1e --author codex:gpt-6.2-sol --provider claude-code --model claude-fable-5-2) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "(never)"; ok $? "W1 an explicit chair model in never is refused"
r=$(RF=$t/roster mb --slice w1d --provider claude-code --model claude-fable-5-2); has "$r" "--model claude-fable-5-2"; ok $? "W1 an eligible explicit member model passes"
# W2: concurrent member spawns reserve their seat and family under a lock before the launch
cm() { mkdir -p "$t/root/$1"; printf 'chair codex:gpt-6.2-sol\nauthor claude-code:claude-opus-5-5\nsize %s\nlimited -\n' "$2" > "$t/root/$1/.council-chair"; }
live() { c_=$1 s_=$2; shift 2; BB_THREAD_STORAGE=$t/root/$c_ WORKFLOW_DRY_RUN= FAKE_ROSTER=$t/roster $H spawn --role council-member --author claude-code:claude-opus-5-5 --chair codex:gpt-6.2-sol --effort medium --brief "$t/b.md" --force --slice "$s_" "$@" >"$t/$s_.out" 2>&1; }
cm cz 2; (FAKE_SPAWN_SLEEP=2 live cz z1) & (FAKE_SPAWN_SLEEP=2 live cz z2) & wait
[ "$(grep -c . "$t/root/cz/council.log")" = 1 ] && cat "$t/z1.out" "$t/z2.out" | grep -q "council is full"; ok $? "W2 two concurrent members in a size-2 council: one seat, the other is refused"
cm c3 3; (FAKE_SPAWN_SLEEP=2 live c3 y1) & (FAKE_SPAWN_SLEEP=2 live c3 y2) & wait
[ "$(cut -f2 "$t/root/c3/council.log" | sort -u | grep -c .)" = 2 ] && [ "$(grep -c thr_new1 "$t/root/c3/council.log")" = 2 ]; ok $? "W2 two concurrent members in a size-3 council take two families, no pending seat left"
# W2: a pending seat whose wrapper died stays taken unless the chair's live children prove its launch failed
sh -c 'exit 0' & dp=$!; wait $dp
cm cd 2; printf 'codex:gpt-6.2-sol\tacp-opencode:opencode-go/grok-4.7\tpending:%s:dz\n' "$dp" > "$t/root/cd/council.log"
(FAKE_LIST_FAIL=1 live cd dz2); has "$(cat "$t/dz2.out")" "council is full"; ok $? "W2 a dead pending seat stays taken when the chair's children cannot be listed"
(live cd dz3); ! has "$(cat "$t/dz3.out")" "council is full" && grep -q "	thr_new1" "$t/root/cd/council.log"; ok $? "W2 a dead pending seat with no child thread is released"
cm ck 2; rm -f "$t/fs/titles/thr_k1"
env BB_THREAD_STORAGE=$t/root/ck WORKFLOW_DRY_RUN= FAKE_ROSTER=$t/roster FAKE_SPAWN_SLEEP=3 FAKE_ID=thr_k1 sh "$here/runtime.sh" spawn --role council-member --author claude-code:claude-opus-5-5 --chair codex:gpt-6.2-sol --effort medium --brief "$t/b.md" --force --slice k1 >/dev/null 2>&1 & kp=$!
i=0; until grep -q pending "$t/root/ck/council.log" 2>/dev/null && [ -f "$t/fs/titles/thr_k1" ] || [ $i -ge 50 ]; do sleep 0.1; i=$((i + 1)); done
kill $kp 2>/dev/null; wait $kp 2>/dev/null; sleep 3
(FAKE_CHILDREN=thr_k1 FAKE_ID=thr_k2 live ck k2); has "$(cat "$t/k2.out")" "council is full" && [ ! -f "$t/fs/titles/thr_k2" ]; ok $? "W2 a killed wrapper whose thread exists keeps its seat; no second member is launched"
(FAKE_CHILDREN=thr_k1 FAKE_ID=thr_k3 live ck k3 --model claude-fable-5-2 --provider claude-code); has "$(cat "$t/k3.out")" "council is full"; ok $? "W2 a killed wrapper's seat also blocks an explicit pick"
# W3: v2 reads agent-roster-v2; without it, agent-roster (the 1.x memory) with a stale warning; roster-save writes agent-roster-v2 only
FAKE_ROSTER_NAME=agent-roster FAKE_ROSTER=$t/roster $H roster >"$t/out" 2>"$t/err"; has "$(cat "$t/out")" "council   codex:gpt-6.2-sol" && has "$(cat "$t/err")" "stale: no agent-roster-v2 memory; read agent-roster"; ok $? "R1 no agent-roster-v2: reads agent-roster and warns stale"
r=$(FAKE_ROSTER_NAME=agent-roster RF=$t/old2 sp --role Explorer --slice r1o); has "$r" "--model claude-haiku-5-5"; ok $? "R1 agent-roster fallback ignores the old lines"
r=$(FAKE_ROSTER_NAME=agent-roster RF=$t/roster sp --role Implementer --slice r1w); has "$r" "--provider codex --model gpt-6.2-sol"; ok $? "R1 agent-roster fallback reads its v2 lines"
: > "$t/memlog"; printf 'work  codex:gpt-6.2-sol\n' | FAKE_MEM_LOG=$t/memlog FAKE_ROSTER_NAME=agent-roster FAKE_ROSTER=$t/roster $H roster-save >/dev/null
ml=$(cat "$t/memlog"); has "$ml" "memory add" && has "$ml" "--name agent-roster-v2" && hasnt "$ml" "memory update"; ok $? "R2 roster-save adds agent-roster-v2 and leaves the 1.x agent-roster alone"
: > "$t/memlog"; printf 'work  codex:gpt-6.2-sol\n' | FAKE_MEM_LOG=$t/memlog FAKE_ROSTER=$t/roster $H roster-save >/dev/null; has "$(cat "$t/memlog")" "memory update mem_r"; ok $? "R2 roster-save updates an existing agent-roster-v2"
# W4: the role restriction holds from creation (bb's thread title), before spawn returns and writes the marker
kid="WORKFLOW_DRY_RUN=1 sh $here/runtime.sh spawn --role Implementer --effort medium --brief $t/b.md --slice kid --force"
cm c4 3; rm -f "$t/fs/child.rc"
live c4 m4; (FAKE_SPAWN_CHILD=$kid FAKE_ID=thr_kid1 live c4 m4b)
[ -f "$t/fs/child.rc" ] && [ "$(cat "$t/fs/child.rc")" != 0 ] && has "$(cat "$t/fs/child.out")" "council member never spawns"; ok $? "W4 a member that runs before its spawn returns cannot spawn"
has "$(cat "$t/fs/titles/thr_kid1")" "Council member · m4b"; ok $? "W4 a member's title names the role"
rm -f "$t/fs/child.rc"; mkdir -p "$t/root/main"
(BB_THREAD_STORAGE=$t/root/main WORKFLOW_DRY_RUN= FAKE_ROSTER=$t/roster FAKE_SPAWN_CHILD=$kid FAKE_ID=thr_kid2 $H spawn --role council-chair --author claude-code:claude-opus-5-5 --effort medium --brief "$t/b.md" --slice c4 >/dev/null 2>&1)
[ -f "$t/fs/child.rc" ] && [ "$(cat "$t/fs/child.rc")" != 0 ] && has "$(cat "$t/fs/child.out")" "Reviewer spawns only"; ok $? "W4 a chair that runs before its spawn returns spawns only members"
printf 'Review › Council member · eligibility › follow-up\n' > "$t/fs/titles/thr_fu1"; printf 'Review › Council chair · eligibility › follow-up\n' > "$t/fs/titles/thr_fu2"
mkdir -p "$t/fu"; (BB_THREAD_ID=thr_fu1 BB_THREAD_STORAGE=$t/fu sp --role Implementer --slice fu1) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "council member never spawns"; ok $? "W4 a member titled '… › Council member · eligibility › follow-up' cannot spawn"
(BB_THREAD_ID=thr_fu2 BB_THREAD_STORAGE=$t/fu sp --role Implementer --slice fu2) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "Reviewer spawns only"; ok $? "W4 a chair titled '… › Council chair · eligibility › follow-up' spawns only members"
printf 'Review › Reviewer · eligibility\n' > "$t/fs/titles/thr_fu7"; (BB_THREAD_ID=thr_fu7 BB_THREAD_STORAGE=$t/fu sp --role Implementer --slice fu7) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "Reviewer spawns only"; ok $? "W4 a thread titled '… › Reviewer · eligibility' spawns only members"
printf 'Review › Council chair · e › Council member · m1 › follow-up\n' > "$t/fs/titles/thr_fu3"
(BB_THREAD_ID=thr_fu3 BB_THREAD_STORAGE=$t/fu sp --role Implementer --slice fu3) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "council member never spawns"; ok $? "W4 a member under a chair's title is a member"
(FAKE_GET_FAIL=1 BB_THREAD_STORAGE=$t/fu sp --role Implementer --slice fu4) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "role is unknown"; ok $? "W4 a failed bb lookup without a marker refuses to spawn"
r=$(FAKE_GET_FAIL=1 RF=$t/roster mb --slice fu5); has "$r" "--role council-member" || has "$r" "bb thread spawn"; ok $? "W4 a failed bb lookup with a chair marker still lets the chair seat members"
(FAKE_GET_FAIL=1 BB_THREAD_STORAGE=$t/chair sp --role Implementer --slice fu6) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "Reviewer spawns only"; ok $? "W4 a failed bb lookup with a chair marker keeps the chair rule"
# W5: council roles run in auto; a provider without auto is no council seat (skipped, logged, reported), never full
r=$(RF=$t/roster mb --slice p1); has "$r" "--provider acp-opencode" && has "$r" "--permission-mode auto"; ok $? "W5 a council member runs in auto"
r=$(FAKE_NOAUTO=acp-opencode RF=$t/roster mb --slice p1n); has "$r" "--provider claude-code --model claude-fable-5-2" && has "$r" "--permission-mode auto" && has "$(cat "$t/err")" "acp-opencode:opencode-go/grok-4.7: acp-opencode lists no auto permission mode"; ok $? "W5 a member seat on a provider without auto is skipped and reported"
r=$(FAKE_NOAUTO=codex RF=$t/roster ch --slice p1c --author claude-code:claude-opus-5-5); has "$r" "--provider acp-opencode" && has "$r" "--permission-mode auto"; ok $? "W5 a chair seat on a provider without auto is skipped"
(FAKE_NOAUTO=acp-opencode RF=$t/roster mb --slice p1e --provider acp-opencode --model opencode-go/glm-5.3) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "(no auto mode)"; ok $? "W5 an explicit council model on a provider without auto is refused"
r=$(FAKE_NOAUTO="acp-opencode claude-code" RF=$t/roster mb --slice p1f 2>&1); [ $? != 0 ] && hasnt "$r" "--permission-mode full" && has "$(cat "$t/err")" "council: 1 of 3"; ok $? "W5 no seat with auto left: a smaller council, never full"
cm c6 3; (FAKE_NOAUTO=acp-opencode live c6 p1l)
l=$(cat "$t/root/c6/council.log"); has "$l" "acp-opencode:opencode-go/grok-4.7	no-auto" && has "$l" "claude-code:claude-fable-5-2	thr_new1" && has "$(cat "$t/p1l.out")" "lists no auto permission mode" && hasnt "$(cat "$t/p1l.out")" "HTTP 400"; ok $? "W5 a skipped no-auto seat is logged in council.log"
(BB_THREAD_STORAGE=$t/root/c6 RF=$t/roster sp --role council-member --author claude-code:claude-opus-5-5 --chair codex:gpt-6.2-sol --slice p1m) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "no council model left" && hasnt "$(cat "$t/err")" "mark the verdict"; ok $? "W5 a no-auto row holds no seat"
r=$(FAKE_NOAUTO=acp-opencode sp --role Implementer --slice p2 --provider acp-opencode --model opencode-go/glm-5.3); has "$r" "--permission-mode accept-edits"; ok $? "W5 a worker on a provider without auto gets a mode it supports"
r=$(sp --role Implementer --slice p3); has "$r" "--permission-mode auto"; ok $? "W5 other workers keep auto"
cm c5 3; (FAKE_SPAWN_FAIL=acp-opencode live c5 p4)
l=$(cat "$t/root/c5/council.log"); has "$l" "acp-opencode:opencode-go/grok-4.7	failed" && has "$l" "claude-code:claude-fable-5-2	thr_new1" && has "$(cat "$t/p4.out")" "HTTP 500"; ok $? "W5 a failed launch is logged failed, reported, and the next seat is tried"
(BB_THREAD_STORAGE=$t/root/c5 RF=$t/roster sp --role council-member --author claude-code:claude-opus-5-5 --chair codex:gpt-6.2-sol --slice p5) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "no council model left" && hasnt "$(cat "$t/err")" "too few families"; ok $? "W5 the next pick skips the failed seat; two seats are a council, no mark"
# Nesting guards
mkdir -p "$t/mem"; printf 'member acp-opencode:opencode-go/grok-4.7\nchair codex:gpt-6.2-sol\nauthor claude-code:claude-opus-5-5\n' > "$t/mem/.council-member"
(BB_THREAD_STORAGE=$t/mem sp --role Implementer --slice g1) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "council member never spawns"; ok $? "G1 a member cannot spawn a worker"
(BB_THREAD_STORAGE=$t/mem sp --mode spin-off --goal G --slice g1s) >/dev/null; [ $? != 0 ]; ok $? "G1 a member cannot spin off"
(BB_THREAD_STORAGE=$t/mem RF=$t/roster sp --role council-member --author claude-code:claude-opus-5-5 --chair codex:gpt-6.2-sol --slice g1m) >/dev/null; [ $? != 0 ]; ok $? "G1 a member cannot spawn a member"
(BB_THREAD_STORAGE=$t/chair RF=$t/roster sp --role council-chair --author claude-code:claude-opus-5-5 --slice g2) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "Reviewer spawns only"; ok $? "G2 a chair cannot spawn a chair"
(BB_THREAD_STORAGE=$t/chair sp --role Implementer --slice g2i) >/dev/null; [ $? != 0 ]; ok $? "G2 a chair cannot spawn other roles"
(BB_THREAD_STORAGE=$t/chair sp --mode fresh --goal G --slice g2f) >/dev/null; [ $? != 0 ]; ok $? "G2 a chair cannot start a top-level thread"
(RF=$t/roster sp --role council-member --author claude-code:claude-opus-5-5 --chair codex:gpt-6.2-sol --slice g3) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "only a Reviewer"; ok $? "G3 a non-chair cannot spawn a member"
# Outside bb: the main thread spawns members itself, naming the chair; the chair's brief folder holds the council
o=$t/home/.agents/workflow/ob; mkdir -p "$o/workers/chair" "$o/workers/chair2" "$o/workers/chair3"
printf 'chair codex:gpt-6.2-sol\nauthor claude-code:claude-opus-5-5\nsize 2\nlimited -\n' > "$o/workers/chair/.council-chair"
ob() { HOME=$t/home WORKFLOW_TASK=ob WORKFLOW_RUNTIME=claude-code WORKFLOW_DRY_RUN= $H spawn --role council-member --author claude-code:claude-opus-5-5 --chair "${OBC:-codex:gpt-6.2-sol}" --effort medium --brief "$t/b.md" "$@" 2>"$t/err"; }
r=$(ob --slice o1 --model sonnet); has "$r" 'model: "sonnet"' && grep -q 'claude-code:sonnet	-' "$o/workers/chair/council.log"; ok $? "O1 outside bb: main spawns a member with --chair, logged in the chair's folder"
ob --slice o2 --model haiku >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "council is full"; ok $? "O1 outside bb: size cap holds"
printf 'chair claude-code:claude-fable-5-2\nauthor claude-code:claude-opus-5-5\nsize 2\nlimited -\n' > "$o/workers/chair2/.council-chair"
r=$(OBC=claude-code:claude-fable-5-2 ob --slice o4); has "$r" 'model: "sonnet"' && has "$(cat "$t/err")" "same family as Reviewer"; ok $? "S1 outside bb, one vendor: the built-in council seats sonnet beside a fable chair, marked same family"
: > "$o/workers/chair2/council.log"; r=$(OBC=claude-code:claude-fable-5-2 ob --slice o5 --model sonnet); has "$r" 'model: "sonnet"'; ok $? "S1 outside bb: an explicit same-vendor member is seated when no other family is eligible"
: > "$o/workers/chair2/council.log"; (OBC=claude-code:claude-fable-5-2 ob --slice o6 --model fable) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "(seated)"; ok $? "S3 outside bb: the chair's own model is refused as a member"
r=$(HOME=$t/home WORKFLOW_TASK=ob WORKFLOW_RUNTIME=claude-code $H spawn --role council-chair --author claude-code:claude-opus-5-5 --effort medium --brief "$t/b.md" --slice o3 2>&1); has "$r" 'model: "fable"'; ok $? "W6 outside bb, Opus author: the built-in council has a default chair"
b=$(cat "$o/briefs/o3-child-1.md"); has "$b" "'$o/workers/<member name>/brief.md'" && has "$b" "Storage: line"; ok $? "W7 outside bb the member command names the brief folder in the parent's storage"
# K5 W4: on bb the seat is named by its thread id, and it is given up only once its thread is stopped or gone
two='codex:gpt-6.2-sol\tacp-opencode:opencode-go/grok-4.7\tthr_m1\ncodex:gpt-6.2-sol\tclaude-code:claude-fable-5-2\tthr_m2\n'
lr() { BB_THREAD_STORAGE=$t/chair WORKFLOW_DRY_RUN= FAKE_ID=thr_m3 FAKE_STOPPED=$t/stopped FAKE_ROSTER=$t/roster $H spawn --role council-member --author claude-code:claude-opus-5-5 --chair codex:gpt-6.2-sol --effort medium --brief "$t/b.md" --force "$@" >/dev/null 2>"$t/err"; }
printf "$two" > "$t/chair/council.log"; cp "$t/chair/council.log" "$t/log0"; : > "$t/stopped"; rm -f "$t/fs/titles/thr_m3"
(FAKE_STOP_FAIL=thr_m1 lr --slice k13r --replace thr_m1); [ $? != 0 ] && has "$(cat "$t/err")" "could not stop thr_m1" && cmp -s "$t/log0" "$t/chair/council.log" && [ ! -f "$t/fs/titles/thr_m3" ]; ok $? "K5 a failed stop of a thread that still exists keeps its seat and launches no replacement"
printf "$two" > "$t/chair/council.log"
(FAKE_STOP_FAIL=thr_m1 FAKE_GONE=thr_m1 lr --slice k14r --replace thr_m1); [ $? = 0 ] && grep -q "	retired:thr_m1$" "$t/chair/council.log" && grep -q "	thr_m3$" "$t/chair/council.log"; ok $? "K5 a failed stop of a thread bb no longer has gives up the seat"
printf "$two" > "$t/chair/council.log"; : > "$t/stopped"; rm -f "$t/fs/titles/thr_m3"
printf "$two" > "$t/chair/council.log"; rm -f "$t/fs/titles/thr_m3"; echo thread_not_found > "$t/fs/titles/thr_m1"
(FAKE_STOP_FAIL=thr_m1 lr --slice k18r --replace thr_m1); [ $? != 0 ] && has "$(cat "$t/err")" "keeps its seat" && cmp -s "$t/log0" "$t/chair/council.log" && [ ! -f "$t/fs/titles/thr_m3" ]; ok $? "K5 a live thread whose lookup merely contains thread_not_found keeps its seat"
rm -f "$t/fs/titles/thr_m1"
(FAKE_STOP_FAIL=thr_m1 FAKE_GET_JSON='{"ok": false, "error": {"code": "unavailable", "message": "thread_not_found"}, "thread_not_found": 1}' lr --slice k19r --replace thr_m1); [ $? != 0 ] && cmp -s "$t/log0" "$t/chair/council.log" && [ ! -f "$t/fs/titles/thr_m3" ]; ok $? "K5 a failed lookup with another error code keeps its seat"
(FAKE_STOP_FAIL=thr_m1 FAKE_GET_JSON='{"ok": false, "detail": {"error": {"code": "thread_not_found"}}, "error": {"code": "unavailable"}}' lr --slice k20r --replace thr_m1); [ $? != 0 ] && cmp -s "$t/log0" "$t/chair/council.log"; ok $? "K5 only the top-level error.code counts, not a nested one"
(FAKE_STOP_FAIL=thr_m1 FAKE_GET_JSON='{"ok":false,"error":{"message":"gone","code":"thread_not_found"}}' lr --slice k21r --replace thr_m1); [ $? = 0 ] && grep -q "	retired:thr_m1$" "$t/chair/council.log"; ok $? "K5 a compact thread_not_found error gives up the seat too"
printf "$two" > "$t/chair/council.log"; : > "$t/stopped"; rm -f "$t/fs/titles/thr_m3"
(lr --slice k15r --replace acp-opencode:opencode-go/grok-4.7); [ $? != 0 ] && has "$(cat "$t/err")" "thread id" && cmp -s "$t/log0" "$t/chair/council.log" && [ ! -s "$t/stopped" ] && [ ! -f "$t/fs/titles/thr_m3" ]; ok $? "K5 on bb a provider:model does not name a seat"
(RF=$t/roster mb --slice k16r --replace acp-opencode:opencode-go/grok-4.7) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "thread id"; ok $? "K5 a dry run on bb refuses a provider:model too"
(FAKE_STOP_RUN="chmod 500 $t/chair" lr --slice k17r --replace thr_m1); rc=$?; chmod 700 "$t/chair"; rm -rf "$t/chair/.council.lock"
[ $rc != 0 ] && has "$(cat "$t/err")" "could not record" && cmp -s "$t/log0" "$t/chair/council.log" && [ ! -f "$t/fs/titles/thr_m3" ]; ok $? "K5 a seat change that cannot be written stops the spawn"
sleep 1; printf 'chair codex:gpt-6.2-sol\nauthor claude-code:claude-opus-5-5\nsize 3\nlimited -\n' > "$o/workers/chair3/.council-chair"  # the newest marker of this chair: outside bb its folder holds the council
printf 'codex:gpt-6.2-sol\tacp-opencode:opencode-go/grok-4.7\t-\ncodex:gpt-6.2-sol\tclaude-code:claude-fable-5-2\t-\n' > "$o/workers/chair3/council.log"
(ob --slice o7 --replace acp-opencode:opencode-go/grok-4.7) >/dev/null; [ $? = 0 ] && grep -q "	retired:-$" "$o/workers/chair3/council.log" && [ "$(grep -c "	-$" "$o/workers/chair3/council.log")" = 2 ]; ok $? "K5 outside bb a seat with no thread id is replaced by its model"
printf 'codex:gpt-6.2-sol\tacp-opencode:opencode-go/grok-4.7\t-\ncodex:gpt-6.2-sol\tacp-opencode:opencode-go/grok-4.7\t-\n' > "$o/workers/chair3/council.log"; cp "$o/workers/chair3/council.log" "$t/log1"
(ob --slice o8 --replace acp-opencode:opencode-go/grok-4.7) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "2 seats" && cmp -s "$t/log1" "$o/workers/chair3/council.log"; ok $? "K5 a provider:model that names two seats is refused"
printf 'codex:gpt-6.2-sol\tacp-opencode:opencode-go/grok-4.7\tfailed\ncodex:gpt-6.2-sol\tacp-opencode:opencode-go/grok-4.7\t-\n' > "$o/workers/chair3/council.log"
(ob --slice o9 --replace acp-opencode:opencode-go/grok-4.7) >/dev/null; [ $? = 0 ] && [ "$(sed -n 1p "$o/workers/chair3/council.log" | cut -f3)" = failed ] && [ "$(sed -n 2p "$o/workers/chair3/council.log" | cut -f3)" = retired:- ]; ok $? "K5 only the occupied row is retired, not a failed row of the same model"
# Lifecycle: council-stop ends the members
: > "$t/stopped"; printf 'codex:gpt-6.2-sol\tacp-opencode:opencode-go/grok-4.7\tthr_m1\n' > "$t/chair/council.log"
BB_THREAD_STORAGE=$t/chair WORKFLOW_DRY_RUN= FAKE_STOPPED=$t/stopped $H council-stop >/dev/null; grep -qx thr_m1 "$t/stopped"; ok $? "L1 chair's council-stop stops its members"
: > "$t/stopped"; WORKFLOW_DRY_RUN= FAKE_STOPPED=$t/stopped FAKE_CHILDREN="thr_a thr_b" $H council-stop thr_ch >/dev/null; [ "$(tr '\n' ' ' < "$t/stopped")" = "thr_a thr_b thr_ch " ]; ok $? "L1 council-stop <chair> stops members, then the chair"
rm -f "$t/chair/council.log"
# A7
$C "bb thread spawn --help" 2>/dev/null; ok $? "A7 spawn --help allowed"
$C "bb thread create -h" 2>/dev/null; ok $? "A7 create -h allowed"
$C "bb thread spawn --prompt x" 2>/dev/null; [ $? = 2 ]; ok $? "A7 raw spawn blocked"
$C "bb thread spawn --help; bb thread spawn --prompt x" 2>/dev/null; [ $? = 2 ]; ok $? "A7 help + raw blocked"
$C "sh /x/scripts/runtime.sh spawn --mode fresh" 2>/dev/null; ok $? "A7 runtime.sh allowed"
$C "sh /x/scripts/harness.sh spawn --mode fresh" 2>/dev/null; ok $? "A7 old harness.sh name still allowed"
# B1 every composed brief ends with the assignment the spawn picked (model, effort; a council's size)
$H spawn --role Implementer --effort high --brief "$t/b.md" --slice as1 --force >"$t/out"; b=$(cat "$t/st/briefs/as1-child-1.md")
has "$b" "Role: Implementer" && has "$b" "Running on:  work · claude-code/" && has "$b" " · high" && hasnt "$b" "Thread setup" && has "$(cat "$t/out")" "--prompt-file $t/st/briefs/as1-child-1.md"; ok $? "B1 a plain child brief gets its Running on line"
$H spawn --role Implementer --helper --effort low --brief "$t/b.md" --slice as2 --force >/dev/null; has "$(cat "$t/st/briefs/as2-child-1.md")" "Running on:  helper · "; ok $? "B1 --helper shows the helper model"
FAKE_ROSTER=none $H spawn --role reviewer --author claude-code:claude-opus-5-5 --size 3 --effort medium --brief "$t/b.md" --slice as3 --force >/dev/null 2>&1; has "$(cat "$t/st/briefs/as3-child-1.md")" "Running on:  council · Reviewer, council of 3 · "; ok $? "B1 a Reviewer brief shows the council size"
# B5 C4: every launch attempt composes into a new file, so a composed brief passed back as the source is never truncated
mkdir -p "$t/st/briefs"; printf 'Role: Implementer\nGoal: keep me\n' > "$t/st/briefs/rc-child.md"
o1=$($H spawn --role Implementer --effort medium --brief "$t/st/briefs/rc-child.md" --slice rc --force); p1=$(printf '%s\n' "$o1" | sed -n 's/.*--prompt-file \([^ ]*\).*/\1/p')
has "$(cat "$t/st/briefs/rc-child.md")" "Goal: keep me" && has "$(cat "$p1")" "Goal: keep me" && has "$(cat "$p1")" "Running on:"; ok $? "B5 a composed brief reused as the source keeps its text"
o2=$($H spawn --role Implementer --effort medium --brief "$p1" --slice rc --force 2>/dev/null); p2=$(printf '%s\n' "$o2" | sed -n 's/.*--prompt-file \([^ ]*\).*/\1/p')
[ -n "$p2" ] && [ "$p2" != "$p1" ] && has "$(cat "$p1")" "Goal: keep me" && has "$(cat "$p2")" "Goal: keep me"; ok $? "B5 each launch gets its own composed path"
# B5 W12: a composed brief passed back as the source keeps only its author's text; this launch adds its own setup and assignment
printf 'Role: Implementer\nGoal: keep me\n' > "$t/w12.md"
o1=$($H spawn --mode spin-off --goal G --effort medium --brief "$t/w12.md" --slice wg --wait-go); p1=$(printf '%s\n' "$o1" | sed -n 's/^brief: //p')
has "$(cat "$p1")" "Hold:" && has "$(cat "$p1")" "Running on:  work · "; ok $? "B5 the first launch holds for go on the work model"
o2=$($H spawn --role Implementer --helper --effort low --brief "$p1" --slice wh --force 2>"$t/err"); p2=$(printf '%s\n' "$o2" | sed -n 's/.*--prompt-file \([^ ]*\).*/\1/p')
b=$(cat "$p2"); hasnt "$b" "Hold:" && hasnt "$b" "Thread setup" && [ "$(grep -c '^Running on:' "$p2")" = 1 ] && [ "$(grep -c '^Assignment (added by runtime.sh' "$p2")" = 1 ] && has "$b" "Running on:  helper · " && has "$b" " · low" && has "$b" "Goal: keep me"; ok $? "B5 a reused composed brief drops the old hold and assignment and gets exactly one new one"
has "$(cat "$t/err")" "added by runtime.sh"; ok $? "B5 the spawn says it dropped the earlier launch's blocks"
(RF=$t/roster ch --slice wc --author claude-code:claude-opus-5-5) >/dev/null; pc=$(ls "$t/st/briefs"/wc-child-*.md | head -1)
$H spawn --role Implementer --effort medium --brief "$pc" --slice wp --force >/dev/null 2>&1; b=$(cat "$t/st/briefs/wp-child-1.md"); hasnt "$b" "Council (added" && [ "$(grep -c '^Running on:' "$t/st/briefs/wp-child-1.md")" = 1 ]; ok $? "B5 a reused Reviewer brief loses its Council block in a plain spawn"
$H spawn --mode spin-off --goal G --effort medium --brief "$p1" --slice wn --context none >/dev/null 2>"$t/err"; ok $? "B5 --context none checks the author's text, not the earlier launch's Context line"
# B5 W12: literal marker examples in an author's brief are kept; earlier launches' blocks are found by the count they end with, or,
# in briefs composed before that count existed, by their shape at the very end (with or without the blank line before ---)
pf() { sed -n 's/.*--prompt-file \([^ ]*\).*/\1/p'; }
body_is() { head -n "$(wc -l < "$2" | tr -d ' ')" "$1" | cmp -s - "$2" && [ "$(sed -n "$(($(wc -l < "$2") + 1))p" "$1")" = "" ] && [ "$(sed -n "$(($(wc -l < "$2") + 2))p" "$1")" = --- ]; }
printf 'Role: Implementer\nGoal: show the block\n\n```\n---\nAssignment (added by runtime.sh; do not edit)\n\nRunning on:  work · x/y · high\n```\nConstraints: keep me\n' > "$t/ex.md"
p=$($H spawn --role Implementer --effort medium --brief "$t/ex.md" --slice ex1 --force 2>"$t/err" | pf); body_is "$p" "$t/ex.md" && hasnt "$(cat "$t/err")" "dropped"; ok $? "B5 a raw brief quoting the Assignment block keeps its closing fence and Constraints"
printf 'Role: Implementer\n\n```\n---\nThread setup (added by runtime.sh; do not edit)\n\nHold: example\n\n---\nAssignment (added by runtime.sh; do not edit)\n\nRunning on:  x\n```\nConstraints: keep me\n\n' > "$t/ex2.md"
p=$($H spawn --mode spin-off --goal G --wait-go --effort medium --brief "$t/ex2.md" --slice ex2 2>/dev/null | sed -n 's/^brief: //p')
p2=$($H spawn --role Implementer --helper --effort low --brief "$p" --slice ex3 --force 2>"$t/err" | pf); body_is "$p2" "$t/ex2.md" && [ "$(grep -c '^Running on:  helper' "$p2")" = 1 ] && [ "$(grep -c '^Hold: read' "$p2")" = 0 ] && has "$(cat "$t/err")" "dropped"; ok $? "B5 a reused brief quoting the blocks keeps its author text exactly and loses only the earlier launch's blocks"
tl=$(tail -1 "$p"); n=${tl#*the last }; n=${n%% *}; sed '$d' "$p" > "$t/ed.md"; printf '<!-- runtime.sh added the last %s lines -->\n' "$((n + 1))" >> "$t/ed.md"
$H spawn --role Implementer --effort medium --brief "$t/ed.md" --slice ex4 --force >/dev/null 2>"$t/err"; [ $? != 0 ] && has "$(cat "$t/err")" "edited" && [ ! -e "$t/st/briefs/ex4-child-1.md" ]; ok $? "B5 a brief whose added blocks no longer match their count is refused before launching"
printf 'Role: Implementer\nGoal: keep me' > "$t/lg.src"; printf 'Role: Implementer\nGoal: keep me\n' > "$t/lg.body"
{ cat "$t/lg.src"; printf '\n---\nThread setup (added by runtime.sh; do not edit)\n\nOrigin: @thread:thr_o spun this thread off.\nHold: read and plan only\n\n---\nAssignment (added by runtime.sh; do not edit)\n\nRunning on:  work · claude-code/claude-opus-5-5 · medium\n'; } > "$t/lg1.md"
p=$($H spawn --role Implementer --helper --effort low --brief "$t/lg1.md" --slice lg1 --force 2>"$t/err" | pf); body_is "$p" "$t/lg.body" && [ "$(grep -c '^Running on:' "$p")" = 1 ] && has "$(cat "$p")" "Running on:  helper" && hasnt "$(cat "$p")" "Hold:" && has "$(cat "$t/err")" "dropped"; ok $? "B5 an older composed brief without the blank line before --- loses its hold and work assignment"
{ cat "$t/ex.md"; printf '\n---\nCouncil (added by runtime.sh; do not edit)\n\nYou:      Reviewer, chairing the council, on codex:gpt-6.2-sol\nMembers:  write each brief\n          then spawn\n\n---\nAssignment (added by runtime.sh; do not edit)\n\nRunning on:  council · Reviewer, council of 2 · codex/gpt-6.2-sol · medium\n'; } > "$t/lg2.md"
p=$($H spawn --role Implementer --effort medium --brief "$t/lg2.md" --slice lg2 --force 2>/dev/null | pf); body_is "$p" "$t/ex.md" && hasnt "$(cat "$p")" "Council (added" && [ "$(grep -c '^Running on:' "$p")" = 2 ]; ok $? "B5 an older composed brief with the blank line drops its blocks and keeps the quoted example"
{ cat "$t/ex.md"; printf '\n---\nThread setup (added by runtime.sh; do not edit)\n\nOrigin: @thread:thr_o spun this thread off.\n'; } > "$t/lg3.md"
p=$($H spawn --role Implementer --effort medium --brief "$t/lg3.md" --slice lg3 --force 2>/dev/null | pf); body_is "$p" "$t/ex.md" && hasnt "$(cat "$p")" "Thread setup"; ok $? "B5 a 2.1.0 brief (setup block, no assignment) drops its setup block"
printf 'Role: Implementer\n' > "$t/locked.md"; chmod 000 "$t/locked.md"
$H spawn --role Implementer --effort medium --brief "$t/locked.md" --slice lk --force >/dev/null 2>"$t/err"; [ $? != 0 ] && has "$(cat "$t/err")" "could not copy"; ok $? "B5 a brief that cannot be read stops the spawn"
chmod 600 "$t/locked.md"
# B2 a brief in workers/<folder>/ makes the folder the slice; report.md is looked up there; a finished slice can be spawned again
mkdir -p "$t/st/workers/review-x"; echo "Role: Implementer" > "$t/st/workers/review-x/brief.md"
e=$($H spawn --role Implementer --effort medium --brief "$t/st/workers/review-x/brief.md" --slice x 2>&1); [ $? != 0 ] && has "$e" "omit --slice or pass review-x"; ok $? "B2 a --slice that differs from the brief folder is refused"
r=$($H spawn --role Implementer --effort medium --brief "$t/st/workers/review-x/brief.md"); has "$r" "Implementer · review-x"; ok $? "B2 the folder names the slice"
printf 'review-x\tthr_rx\n' >> "$t/st/spawned.log"
$H spawn --role Implementer --effort medium --brief "$t/st/workers/review-x/brief.md" >/dev/null 2>&1; [ $? != 0 ]; ok $? "B2 a slice with no report.md is retried, not spawned again"
touch "$t/st/workers/review-x/report.md"
$H spawn --role Implementer --effort medium --brief "$t/st/workers/review-x/brief.md" >/dev/null 2>&1; ok $? "B2 a finished slice (report.md present) can be spawned again"
mkdir -p "$t/fs/titles"; echo "G › Implementer · review-x" > "$t/fs/titles/thr_rx"
PATH=$t/bin:$PATH $H tell thr_rx hi >/dev/null 2>"$t/err"; hasnt "$(cat "$t/err")" "warning"; ok $? "B2 tell finds report.md in the slice folder"
echo "G › Implementer · gone" > "$t/fs/titles/thr_gn"
PATH=$t/bin:$PATH $H tell thr_gn hi >/dev/null 2>"$t/err"; has "$(cat "$t/err")" "workers/gone does not exist"; ok $? "B2 tell warns when the slice folder is missing"
# B3 list, show and retry threads through the script; outside bb they print the instruction
r=$($H help threads); has "$r" "runtime.sh threads" && has "$($H help retry)" "runtime.sh retry <id>" && has "$($H help show)" "runtime.sh show <id>"; ok $? "B3 help documents threads, show, retry"
r=$(WORKFLOW_RUNTIME=claude-code $H retry agent_1); has "$r" "resume agent agent_1"; ok $? "B3 retry outside bb prints the instruction"
r=$(WORKFLOW_RUNTIME=codex $H threads); has "$r" "no thread list here"; ok $? "B3 threads outside bb"
r=$(FAKE_ROSTER=none $H spawn --role reviewer --author user:human --effort medium --brief "$t/b.md" --slice pr1 --force 2>&1); [ $? = 0 ] && has "$r" "Delegated → "; ok $? "B4 a review of a person's PR: --author user:human seats a council"
# B4 no workers: a review becomes a marked self-check
e=$(WORKFLOW_RUNTIME=none FAKE_ROSTER=none $H spawn --role reviewer --author claude-code:claude-opus-5-5 --effort medium --brief "$t/b.md" --slice nw --force 2>&1); [ $? != 0 ] && has "$e" "council: 0 of 2" && has "$e" "self-check"; ok $? "B4 no workers: the review is a self-check marked council: 0 of <size>"

# Q1 quota: each pool account's windows, reset times and verdict; filtered by provider; unknown outside bb
rs=$(( ($(date +%s) + 3 * 3600 + 1800) * 1000 ))
acct() { # provider label status 5h-utilization 5h-status 7d-utilization
  printf '    {\n      "id": "a_%s",\n      "provider": "%s",\n      "label": "%s",\n      "enabled": %s,\n      "extraUsage": {\n        "status": "rejected"\n      },\n      "familyWeekly": {\n        "fable": null\n      },\n      "limitWindows": [\n' "$2" "$1" "$2" "$( [ "$3" = disabled ] && echo false || echo true)"
  printf '        {\n          "windowMinutes": 300,\n          "utilization": %s,\n          "resetAt": %s,\n          "status": %s\n        },\n' "$4" "$rs" "$5"
  printf '        {\n          "windowMinutes": 10080,\n          "utilization": %s,\n          "resetAt": null,\n          "status": null\n        }\n      ],\n      "status": "%s"\n    },\n' "$6" "$3"
}
{ printf '{\n  "accounts": [\n'; acct claude c-ok ready 0.5 '"allowed"' 0.4; acct claude c-near ready 0.86 '"allowed"' 0.1; acct codex x-week ready 0.1 null 0.91
  acct codex x-rej ready 0.2 '"rejected"' 0.1; acct claude c-held held 0.1 '"allowed"' 0.1; acct claude c-off disabled 0 null 0; printf '  ]\n}\n'; } > "$t/pool.json"
export FAKE_POOL=$t/pool.json
q=$($H quota); has "$q" "claude  c-ok  ready  5h 50% (resets in 3h" && has "$q" "7d 40% (no reset time) → ok" && hasnt "$q" "rejected"; ok $? "Q1 quota prints each window, its reset time and ok"
has "$q" "c-near  ready  5h 86%" && has "$(printf '%s\n' "$q" | grep c-near)" "→ near limit" && has "$(printf '%s\n' "$q" | grep x-week)" "→ near limit"; ok $? "Q1 near limit: a 5h window at 85%+ or a 7d window at 90%+"
has "$(printf '%s\n' "$q" | grep x-rej)" "→ limited" && has "$(printf '%s\n' "$q" | grep c-held)" "→ limited" && has "$(printf '%s\n' "$q" | grep c-off)" "→ disabled"; ok $? "Q1 limited: a rejected window or an account not ready; disabled accounts say so"
q=$($H quota claude-code); has "$q" "c-ok" && hasnt "$q" "x-week"; ok $? "Q1 quota claude-code shows only the claude pool accounts"
q=$($H quota acp-opencode); has "$q" "no pool accounts for acp-opencode; unknown"; ok $? "Q1 a provider with no pool account is unknown"
q=$(WORKFLOW_RUNTIME=claude-code $H quota codex); has "$q" "quota: unknown here"; ok $? "Q1 quota outside bb is unknown"
# Q2 wait --timeout: says whether the turn ended or the timeout passed
r=$($H wait thr_w --timeout 60m); [ $? = 0 ] && [ "$r" = "ended: thr_w" ] && [ "$(cat "$t/fs/wait.args")" = "thr_w --timeout 60m --json" ]; ok $? "Q2 wait --timeout passes the timeout to bb thread wait and reports ended"
r=$($H wait --timeout 90s thr_w); [ $? = 0 ] && [ "$(cat "$t/fs/wait.args")" = "thr_w --timeout 90s --json" ]; ok $? "Q2 --timeout before the id"
r=$(FAKE_WAIT=timeout $H wait thr_w --timeout 60m); [ $? = 2 ] && has "$r" "timeout: thr_w has not finished the work pending at" && has "$r" "after 60m" && has "$r" "runtime.sh quota"; ok $? "Q2 a timeout exits 2 and says so"
r=$(FAKE_WAIT=fail $H wait thr_w 2>&1); [ $? = 1 ] && has "$r" "Thread not found"; ok $? "Q2 a failed wait exits 1 with bb's error"
r=$($H wait thr_w); [ $? = 0 ] && [ "$(cat "$t/fs/wait.args")" = "thr_w --json" ]; ok $? "Q2 wait without --timeout keeps bb's default"
$H wait thr_w --timeout soon >/dev/null 2>&1; [ $? = 1 ]; ok $? "Q2 a bad duration is refused"
r=$(WORKFLOW_RUNTIME=codex $H wait a1 --timeout 60m); has "$r" "wait-agent tool with a 60m timeout"; ok $? "Q2 wait outside bb prints the instruction with the timeout"
r=$($H help wait); has "$r" "--timeout <duration>" && has "$r" "Watchdog" && has "$($H help quota)" "near limit"; ok $? "Q2 help documents wait --timeout and quota"

# W18 wait covers queued work: idle with a message still queued (a re-check not started) is not the end
echo 2 > "$t/fs/queued.thr_q"; : > "$t/fs/wait.log"
r=$($H wait thr_q --timeout 30s); [ $? = 0 ] && [ "$r" = "ended: thr_q" ] && [ "$(wc -l < "$t/fs/wait.log")" -eq 2 ]; ok $? "W18 wait waits through queued turns until nothing is queued"
echo 1 > "$t/fs/queued.thr_s"
r=$(FAKE_QUEUE_STUCK=1 $H wait thr_s --timeout 2s); [ $? = 2 ] && has "$r" "timeout: thr_s has not finished the work pending at"; ok $? "W18 a queued turn that never starts times out instead of ending"
r=$($H wait thr_w --watchdog); has "$r" "--notify thr_origin" && has "$r" "--timeout 60m"; ok $? "W18 --watchdog (dry run) is a detached wait that tells this thread, 60m by default"
: > "$t/fs/tell.log"
r=$(FAKE_WAIT=timeout WORKFLOW_DRY_RUN= $H wait thr_w --watchdog --timeout 1s); pid=${r#*pid }; pid=${pid%%)*}
i=0; while kill -0 "$pid" 2>/dev/null && [ $i -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
has "$r" "watchdog: armed on thr_w for 1s" && has "$(cat "$t/fs/tell.log")" "tell thr_origin --mode auto watchdog: timeout: thr_w has not finished the work pending at" && has "$(cat "$t/fs/tell.log")" "stale only if a report from thr_w reached you after"; ok $? "W18 the watchdog returns at once and tells this thread on a timeout, naming when the pending work began"
: > "$t/fs/tell.log"
r=$(WORKFLOW_DRY_RUN= $H wait thr_w --watchdog --timeout 5s); pid=${r#*pid }; pid=${pid%%)*}
i=0; while kill -0 "$pid" 2>/dev/null && [ $i -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
! kill -0 "$pid" 2>/dev/null && [ ! -s "$t/fs/tell.log" ]; ok $? "W18 a watchdog whose worker ends sends nothing (its turn end is the one wake)"
# W18 round 10: done is a turn end logged after the wait began, then idle with an explicit zero queue, then no turn begun after it
fs=$t/fs; : > "$fs/wait.log"; echo "10 turn/completed" > "$fs/log.thr_r"; echo 1 > "$fs/queued.thr_r"
printf '%s\n' "echo '11 turn/completed' >> $fs/log.thr_r" "echo idle > $fs/status.thr_r; echo '13 turn/completed' >> $fs/log.thr_r" > "$fs/steps.thr_r"
echo "echo active > $fs/status.thr_r; echo 0 > $fs/queued.thr_r; echo '12 turn/started' >> $fs/log.thr_r" > "$fs/getsteps.thr_r"
r=$($H wait thr_r --timeout 30s); [ $? = 0 ] && [ "$r" = "ended: thr_r" ] && [ "$(wc -l < "$fs/wait.log")" -eq 2 ] && [ ! -s "$fs/steps.thr_r" ]; ok $? "W18 a queued turn that starts before the lookup (active, none queued) is waited for, not ended"
: > "$fs/wait.log"; echo "20 turn/completed" > "$fs/log.thr_d"
echo "echo '21 turn/completed' >> $fs/log.thr_d" > "$fs/steps.thr_d"; echo "echo '22 client/turn/requested' >> $fs/log.thr_d" > "$fs/getsteps.thr_d"
r=$($H wait thr_d --timeout 30s); [ $? = 0 ] && [ "$r" = "ended: thr_d" ] && [ "$(wc -l < "$fs/wait.log")" -eq 2 ]; ok $? "W18 a turn begun after the idle lookup (in the log read after it) is waited for"
echo "5 turn/completed" > "$fs/log.thr_e"
r=$(FAKE_QUEUE_STUCK=1 $H wait thr_e --timeout 2s); [ $? = 2 ] && has "$r" "timeout: thr_e"; ok $? "W18 a turn that ended before the wait began is not its end"
r=$(FAKE_GET_FAIL=1 $H wait thr_w --timeout 30s 2>&1); [ $? = 1 ] && has "$r" "state of thr_w is unknown" && hasnt "$r" "ended"; ok $? "W18 a failed status lookup is unknown (exit 1), not ended"
r=$(FAKE_GET_NOQUEUE=1 $H wait thr_w --timeout 30s 2>&1); [ $? = 1 ] && has "$r" "unknown" && hasnt "$r" "ended"; ok $? "W18 a lookup without a queue count is unknown (exit 1), not ended"
r=$(FAKE_LOG_FAIL=1 $H wait thr_w --timeout 30s 2>&1); [ $? = 1 ] && has "$r" "event log of thr_w is unknown" && hasnt "$r" "ended"; ok $? "W18 an unreadable event log is unknown (exit 1), not ended"
# W18 round 11: a lookup that fails after printing its fields, or a log cut short after a turn end, is unknown, never ended
echo "30 turn/completed" > "$fs/log.thr_p"; r=$(FAKE_GET_PARTIAL=1 $H wait thr_p --timeout 30s 2>&1); [ $? = 1 ] && has "$r" "state of thr_p is unknown" && hasnt "$r" "ended"; ok $? "W18 a lookup that prints idle and zero queued, then exits 1, is unknown (exit 1), not ended"
echo "35 turn/completed" > "$fs/log.thr_p"; r=$(FAKE_GET_PARTIAL=0 $H wait thr_p --timeout 30s 2>&1); [ $? = 1 ] && has "$r" "state of thr_p is unknown" && hasnt "$r" "ended"; ok $? "W18 a lookup cut short with exit 0 is unknown (exit 1), not ended"
echo "40 turn/completed" > "$fs/log.thr_l"; r=$(FAKE_LOG_TRUNC=1 $H wait thr_l --timeout 30s 2>&1); [ $? = 1 ] && has "$r" "state of thr_l is unknown" && hasnt "$r" "ended"; ok $? "W18 a log that holds a turn end but lacks its closing bracket is unknown (exit 1), not ended"
: > "$fs/tell.log"; FAKE_LOG_FAIL=1 $H wait thr_w --timeout 30s --notify thr_origin; has "$(cat "$fs/tell.log")" "watchdog: waiting on thr_w failed"; ok $? "W18 a watchdog whose lookup fails tells this thread"
r=$(WORKFLOW_RUNTIME=claude-code $H wait a1 --watchdog); has "$r" "no detached watchdog here" && has "$r" "Where nothing can wake you"; ok $? "W18 outside bb --watchdog says what can wake you"
# W20 only bb's timeout exit code is a timeout; a connection failure that says "Timed out" stays a failure
r=$(FAKE_WAIT=conn $H wait thr_w 2>&1); [ $? = 1 ] && has "$r" "Timed out connecting to controller" && hasnt "$r" "timeout: thr_w"; ok $? "W20 a failed lookup is exit 1 with bb's error, not a timeout"
# W19 a model family's limit is not the account's; no window observed is unknown, not ok
{ printf '{\n  "accounts": [\n'
  printf '    {\n      "provider": "claude",\n      "label": "f-fable",\n      "enabled": true,\n      "familyWeekly": {\n        "fable": {\n          "utilization": 1,\n          "resetAt": null,\n          "status": "allowed"\n        },\n        "opus": null\n      },\n      "limitWindows": [\n        {\n          "windowMinutes": 300,\n          "utilization": 0.12,\n          "resetAt": null,\n          "status": "allowed"\n        }\n      ],\n      "status": "ready"\n    },\n'
  printf '  ]\n}\n'; } > "$t/pool-fam.json"
q=$(FAKE_POOL=$t/pool-fam.json $H quota); has "$q" "5h 12% (no reset time) → ok, fable limited" && has "$q" "claude: ok, fable limited"; ok $? "W19 a family at 100% limits only that family; the shared window keeps the account ok"
{ printf '{\n  "accounts": [\n    {\n      "provider": "codex",\n      "label": "x-new",\n      "enabled": true,\n      "familyWeekly": {\n        "fable": null\n      },\n      "limitWindows": [],\n      "status": "ready"\n    },\n  ]\n}\n'; } > "$t/pool-none.json"
q=$(FAKE_POOL=$t/pool-none.json $H quota); has "$q" "no windows observed → unknown" && has "$q" "codex: unknown"; ok $? "W19 a ready account with no window observed is unknown"
cat "$t/pool-fam.json" | sed '$d' | sed '$d' > "$t/pool-two.json"; printf '    {\n      "provider": "claude",\n      "label": "c-out",\n      "enabled": true,\n      "limitWindows": [\n        {\n          "windowMinutes": 300,\n          "utilization": 1,\n          "resetAt": null,\n          "status": "rejected"\n        }\n      ],\n      "status": "ready"\n    }\n  ]\n}\n' >> "$t/pool-two.json"
q=$(FAKE_POOL=$t/pool-two.json $H quota); has "$q" "c-out" && has "$q" "→ limited" && has "$q" "claude: ok, fable limited"; ok $? "W19 the provider line is its best account: one limited account does not rule it out"
# W19 a provider whose accounts are all disabled has a routing rule, as near limit and limited do
{ printf '{\n  "accounts": [\n    {\n      "provider": "claude",\n      "label": "c-off",\n      "enabled": false,\n      "limitWindows": [],\n      "status": "ready"\n    },\n  ]\n}\n'; } > "$t/pool-off.json"
q=$(FAKE_POOL=$t/pool-off.json $H quota); d=$(grep -F "Never sit idle" "$here/../references/delegating.md")
has "$q" "claude: disabled" && has "$d" '`disabled`' && has "$d" '`near limit`' && has "$d" '`limited`'; ok $? "W19 delegating.md routes every verdict that rules a provider out: near limit, limited, disabled"

# H1 help
H="sh $(dirname "$0")/runtime.sh"
r=$($H help spawn); has "$r" "--env this|new" && ! has "$r" "runtime.sh tell"; ok $? "H1 help spawn: only spawn usage"
r=$($H help tell); has "$r" "runtime.sh tell <id>"; ok $? "H1 help tell"
$H help nope >/dev/null 2>&1; [ $? != 0 ]; ok $? "H1 help unknown command fails"
r=$($H help); has "$r" "WORKFLOW_HARNESS"; ok $? "H1 help prints the whole header"
[ $fail = 0 ] && echo "all passed" || { echo "FAILED"; exit 1; }
