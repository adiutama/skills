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
# $FAKE_LIST_FAIL), thread stop (logged to $FAKE_STOPPED)
mkdir -p "$t/bin"
cat > "$t/bin/bb" <<'FAKE'
#!/bin/sh
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
  "thread get") [ -z "$FAKE_GET_FAIL" ] || { printf '{"ok": false, "error": {"code": "unavailable"}}\n'; exit 1; }
    printf '{\n  "thread": {\n    "id": "%s",\n    "title": "%s"\n  }\n}\n' "$3" "$(cat "$FAKE_STATE/titles/$3" 2>/dev/null)" ;;
  "thread list") [ -z "$FAKE_LIST_FAIL" ] || { printf '{"ok": false, "error": {"code": "unavailable"}}\n'; exit 1; }
    printf '[\n'; for c in $FAKE_CHILDREN; do printf '  {\n    "id": "%s",\n    "title": "%s",\n  },\n' "$c" "$(cat "$FAKE_STATE/titles/$c" 2>/dev/null)"; done; printf ']\n' ;;
  "thread stop") echo "$3" >> "$FAKE_STOPPED" ;;
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
b=$(cat "$t/st/briefs/sp-spin-off.md"); has "$b" "@thread:thr_origin" && has "$b" "DONE" && has "$b" "BLOCKED" && has "$b" "FAILED" && has "$b" "bb thread tell thr_origin"; ok $? "A2 spin-off brief reporting"
$H spawn --mode spin-off --goal G --effort high --brief "$t/b.md" --slice sm --report-after-merge >/dev/null; has "$(cat "$t/st/briefs/sm-spin-off.md")" "only after your PR has merged"; ok $? "A2 after-merge trigger"
# A3
$H spawn --mode spin-off --goal G --effort high --brief "$t/b.md" --slice w --wait-go >/dev/null; has "$(cat "$t/st/briefs/w-spin-off.md")" "Hold:"; ok $? "A3 --wait-go hold"
a=$($H spawn --mode spin-off --goal G --effort high --brief "$t/b.md" --slice af --after thr_x); has "$(cat "$t/st/briefs/af-spin-off.md")" "thr_x" && has "$a" "bb thread tell thr_x"; ok $? "A3 --after untracked tells X"
printf '| @thread:thr_y | t |\n' > "$t/st/spin-offs.md"
a=$($H spawn --mode spin-off --goal G --effort high --brief "$t/b.md" --slice ay --after thr_y); hasnt "$a" "bb thread tell thr_y"; ok $? "A3 --after tracked: no tell"
# A4
$H spawn --mode spin-off --goal G --effort high --brief "$t/b.md" --slice nc --context none >/dev/null; hasnt "$(cat "$t/st/briefs/nc-spin-off.md")" "Context:"; ok $? "A4 --context none"
# W1: waiting-on column must not count as tracked
printf '| @thread:thr_z | t | d | done | thr_w | running | - |\n' > "$t/st/spin-offs.md"
a=$($H spawn --mode spin-off --goal G --effort high --brief "$t/b.md" --slice wz --after thr_w); has "$a" "bb thread tell thr_w" && has "$(cat "$t/st/briefs/wz-spin-off.md")" "tells you \"go\" directly"; ok $? "W1 waiting-on is not tracked"
printf '| @thread:thr_y | t |\n' > "$t/st/spin-offs.md"
# W2: none rejects a brief with a Context section
printf 'Goal: x\nContext: from the origin\n' > "$t/ctx.md"
$H spawn --mode spin-off --goal G --effort high --brief "$t/ctx.md" --slice cx --context none >/dev/null 2>&1; [ $? != 0 ]; ok $? "W2 none rejects Context: brief"
# W5: fresh always names the origin
$H spawn --mode fresh --goal G --effort high --brief "$t/b.md" --slice fo --context none --wait-go >/dev/null; has "$(cat "$t/st/briefs/fo-fresh.md")" "@thread:thr_origin"; ok $? "W5 fresh names origin"
# Personal project: personal workspace, not worktree
pp=$($H spawn --mode spin-off --goal G --effort high --brief "$t/b.md" --slice pp --project proj_personal); has "$pp" "--new-environment personal" && hasnt "$pp" "worktree"; ok $? "personal project uses --new-environment personal"
pf=$($H spawn --mode fresh --goal G --effort high --brief "$t/b.md" --slice pf --project proj_personal --env new); has "$pf" "--new-environment personal"; ok $? "personal project, fresh"
pi=$($H spawn --role Implementer --effort medium --brief "$t/b.md" --slice pi --isolated --project proj_personal); has "$pi" "--new-environment personal"; ok $? "personal project, isolated child"
# W4: quoting and --json
mkdir -p "$t/sp ace"; echo x > "$t/sp ace/b.md"
q=$(BB_THREAD_STORAGE="$t/st x" $H spawn --mode spin-off --goal "Fix queued status" --effort high --brief "$t/sp ace/b.md" --slice qs); has "$q" "--title 'Fix queued status'" && has "$q" "--json" && has "$q" "--prompt-file '$t/st x/briefs/qs-spin-off.md'"; ok $? "W4 dry-run quotes args, has --json"
# A5
for r in "$c" "$s" "$f"; do has "$r" " → @thread:<new> · " && printf '%s\n' "$r" | grep -Eq 'high|medium' ; [ $? = 0 ] || fail=1; done
has "$s" "Spun off → @thread:<new> · top-level · " && has "$s" "claude-code/claude-sonnet-5-5 · high"; ok $? "A5 receipt line"
# A6
printf 's1\tthr_old\n' > "$t/st/spawned.log"
e=$($H spawn --role Implementer --effort medium --brief "$t/b.md" --slice s1 2>&1); r=$?
[ $r != 0 ] && has "$e" "bb thread retry thr_old"; ok $? "A6 re-spawn refused"
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
sp --role Reviewer --slice rr >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "council-chair"; ok $? "T2 old Reviewer role points at the council"
sp --role Consultant --slice rc >/dev/null; [ $? != 0 ]; ok $? "T2 Consultant role is gone"
# Council chair: first council entry that is not the author's model, nor never/limited/missing
ch() { sp --role council-chair "$@"; }
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
(RF=$t/roster ch --slice c12 --author claude-code:claude-opus-5-5 --size 3 --limited acp-opencode) >/dev/null; b=$(cat "$t/st/briefs/c12-child.md"); has "$b" "Size:     3" && has "$b" "--role council-member --author claude-code:claude-opus-5-5 --chair codex:gpt-6.2-sol --limited acp-opencode"; ok $? "C2 size and member command recorded in the chair's brief"
(RF=$t/roster ch --slice c13 --author claude-code:claude-opus-5-5) >/dev/null; has "$(cat "$t/st/briefs/c13-child.md")" "Size:     2"; ok $? "C2 size defaults to 2"
sp --role Implementer --slice c14 --size 3 >/dev/null; [ $? != 0 ]; ok $? "C2 --size only for council-chair"
r=$(RF=$t/roster ch --slice c15 --author claude-code:claude-opus-5-5 --helper); [ $? != 0 ]; ok $? "C2 --helper refused on council roles"
# Markers: a real spawn writes them into the worker's storage (the brief folder and the new thread's own storage)
mkdir -p "$t/live/st"
(BB_THREAD_STORAGE=$t/live/st WORKFLOW_DRY_RUN= FAKE_ROSTER=$t/roster $H spawn --role council-chair --author claude-code:claude-opus-5-5 --size 3 --effort medium --brief "$t/b.md" --slice m1 >/dev/null 2>&1)
grep -q '^size 3$' "$t/live/st/workers/m1/.council-chair" 2>/dev/null && grep -q '^chair codex:gpt-6.2-sol$' "$t/live/thr_new1/.council-chair" 2>/dev/null; ok $? "M1 chair marker written to both storages"
# Member pick, run inside a chair (its storage holds .council-chair)
mkdir -p "$t/chair"; printf 'chair codex:gpt-6.2-sol\nauthor claude-code:claude-opus-5-5\nsize 3\nlimited -\n' > "$t/chair/.council-chair"
mb() { BB_THREAD_STORAGE=$t/chair sp --role council-member --author claude-code:claude-opus-5-5 --chair codex:gpt-6.2-sol "$@"; }
r=$(RF=$t/roster mb --slice k1); has "$r" "--provider acp-opencode --model opencode-go/grok-4.7"; ok $? "K1 member skips the chair's family and the author"
has "$r" "--lifecycle-owner-thread thr_origin"; ok $? "L0 a member's lifecycle owner is its chair (archiving the chair archives and stops it)"
r=$(RF=$t/roster ch --slice l0 --author claude-code:claude-opus-5-5); hasnt "$r" "--lifecycle-owner-thread"; ok $? "L0 a chair has no lifecycle owner"
printf 'codex:gpt-6.2-sol\tacp-opencode:opencode-go/grok-4.7\tthr_m1\n' > "$t/chair/council.log"
r=$(RF=$t/roster mb --slice k2); has "$r" "--provider claude-code --model claude-fable-5-2"; ok $? "K1 member skips existing members"
has "$(cat "$t/chair/briefs/k2-child.md")" "council member on claude-code:claude-fable-5-2"; ok $? "K1 member brief names its model and chair"
printf 'codex:gpt-6.2-sol\tacp-opencode:opencode-go/grok-4.7\tthr_m1\ncodex:gpt-6.2-sol\tclaude-code:claude-fable-5-2\tthr_m2\n' > "$t/chair/council.log"
(RF=$t/roster mb --slice k3) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "council is full"; ok $? "K2 size cap: at most size-1 members"
printf 'codex:gpt-6.2-sol\tacp-opencode:opencode-go/grok-4.7\tthr_m1\n' > "$t/chair/council.log"
(RF=$t/roster mb --slice k4 --limited claude-code) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "rule with fewer"; ok $? "K3 no member left fails, chair rules with fewer"
(RF=$t/roster mb --slice k5 --chair acp-opencode:opencode-go/grok-4.7) >/dev/null; [ $? != 0 ]; ok $? "K4 --chair must match the chair's marker"
rm -f "$t/chair/council.log"
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
(RF=$t/roster mb --slice w1b --provider codex --model gpt-6.2-sol) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "family openai taken"; ok $? "W1 an explicit member model of the chair's family is refused"
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
[ -f "$t/fs/child.rc" ] && [ "$(cat "$t/fs/child.rc")" != 0 ] && has "$(cat "$t/fs/child.out")" "chair spawns only"; ok $? "W4 a chair that runs before its spawn returns spawns only members"
printf 'Review › Council member · eligibility › follow-up\n' > "$t/fs/titles/thr_fu1"; printf 'Review › Council chair · eligibility › follow-up\n' > "$t/fs/titles/thr_fu2"
mkdir -p "$t/fu"; (BB_THREAD_ID=thr_fu1 BB_THREAD_STORAGE=$t/fu sp --role Implementer --slice fu1) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "council member never spawns"; ok $? "W4 a member titled '… › Council member · eligibility › follow-up' cannot spawn"
(BB_THREAD_ID=thr_fu2 BB_THREAD_STORAGE=$t/fu sp --role Implementer --slice fu2) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "chair spawns only"; ok $? "W4 a chair titled '… › Council chair · eligibility › follow-up' spawns only members"
printf 'Review › Council chair · e › Council member · m1 › follow-up\n' > "$t/fs/titles/thr_fu3"
(BB_THREAD_ID=thr_fu3 BB_THREAD_STORAGE=$t/fu sp --role Implementer --slice fu3) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "council member never spawns"; ok $? "W4 a member under a chair's title is a member"
(FAKE_GET_FAIL=1 BB_THREAD_STORAGE=$t/fu sp --role Implementer --slice fu4) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "role is unknown"; ok $? "W4 a failed bb lookup without a marker refuses to spawn"
r=$(FAKE_GET_FAIL=1 RF=$t/roster mb --slice fu5); has "$r" "--role council-member" || has "$r" "bb thread spawn"; ok $? "W4 a failed bb lookup with a chair marker still lets the chair seat members"
(FAKE_GET_FAIL=1 BB_THREAD_STORAGE=$t/chair sp --role Implementer --slice fu6) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "chair spawns only"; ok $? "W4 a failed bb lookup with a chair marker keeps the chair rule"
# W5: council roles run in auto; a provider without auto is no council seat (skipped, logged, reported), never full
r=$(RF=$t/roster mb --slice p1); has "$r" "--provider acp-opencode" && has "$r" "--permission-mode auto"; ok $? "W5 a council member runs in auto"
r=$(FAKE_NOAUTO=acp-opencode RF=$t/roster mb --slice p1n); has "$r" "--provider claude-code --model claude-fable-5-2" && has "$r" "--permission-mode auto" && has "$(cat "$t/err")" "acp-opencode:opencode-go/grok-4.7: acp-opencode lists no auto permission mode"; ok $? "W5 a member seat on a provider without auto is skipped and reported"
r=$(FAKE_NOAUTO=codex RF=$t/roster ch --slice p1c --author claude-code:claude-opus-5-5); has "$r" "--provider acp-opencode" && has "$r" "--permission-mode auto"; ok $? "W5 a chair seat on a provider without auto is skipped"
(FAKE_NOAUTO=acp-opencode RF=$t/roster mb --slice p1e --provider acp-opencode --model opencode-go/glm-5.3) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "(no auto mode)"; ok $? "W5 an explicit council model on a provider without auto is refused"
r=$(FAKE_NOAUTO="acp-opencode claude-code" RF=$t/roster mb --slice p1f 2>&1); [ $? != 0 ] && hasnt "$r" "--permission-mode full" && has "$(cat "$t/err")" "too few families"; ok $? "W5 no seat with auto left: a smaller council, never full"
cm c6 3; (FAKE_NOAUTO=acp-opencode live c6 p1l)
l=$(cat "$t/root/c6/council.log"); has "$l" "acp-opencode:opencode-go/grok-4.7	no-auto" && has "$l" "claude-code:claude-fable-5-2	thr_new1" && has "$(cat "$t/p1l.out")" "lists no auto permission mode" && hasnt "$(cat "$t/p1l.out")" "HTTP 400"; ok $? "W5 a skipped no-auto seat is logged in council.log"
(BB_THREAD_STORAGE=$t/root/c6 RF=$t/roster sp --role council-member --author claude-code:claude-opus-5-5 --chair codex:gpt-6.2-sol --slice p1m) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "council: 2 of 3, too few families"; ok $? "W5 a no-auto row holds no seat"
r=$(FAKE_NOAUTO=acp-opencode sp --role Implementer --slice p2 --provider acp-opencode --model opencode-go/glm-5.3); has "$r" "--permission-mode accept-edits"; ok $? "W5 a worker on a provider without auto gets a mode it supports"
r=$(sp --role Implementer --slice p3); has "$r" "--permission-mode auto"; ok $? "W5 other workers keep auto"
cm c5 3; (FAKE_SPAWN_FAIL=acp-opencode live c5 p4)
l=$(cat "$t/root/c5/council.log"); has "$l" "acp-opencode:opencode-go/grok-4.7	failed" && has "$l" "claude-code:claude-fable-5-2	thr_new1" && has "$(cat "$t/p4.out")" "HTTP 500"; ok $? "W5 a failed launch is logged failed, reported, and the next seat is tried"
(BB_THREAD_STORAGE=$t/root/c5 RF=$t/roster sp --role council-member --author claude-code:claude-opus-5-5 --chair codex:gpt-6.2-sol --slice p5) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "council: 2 of 3, too few families"; ok $? "W5 the next pick skips the failed seat; W6 too few families names the verdict mark"
# Nesting guards
mkdir -p "$t/mem"; printf 'member acp-opencode:opencode-go/grok-4.7\nchair codex:gpt-6.2-sol\nauthor claude-code:claude-opus-5-5\n' > "$t/mem/.council-member"
(BB_THREAD_STORAGE=$t/mem sp --role Implementer --slice g1) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "council member never spawns"; ok $? "G1 a member cannot spawn a worker"
(BB_THREAD_STORAGE=$t/mem sp --mode spin-off --goal G --slice g1s) >/dev/null; [ $? != 0 ]; ok $? "G1 a member cannot spin off"
(BB_THREAD_STORAGE=$t/mem RF=$t/roster sp --role council-member --author claude-code:claude-opus-5-5 --chair codex:gpt-6.2-sol --slice g1m) >/dev/null; [ $? != 0 ]; ok $? "G1 a member cannot spawn a member"
(BB_THREAD_STORAGE=$t/chair RF=$t/roster sp --role council-chair --author claude-code:claude-opus-5-5 --slice g2) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "chair spawns only"; ok $? "G2 a chair cannot spawn a chair"
(BB_THREAD_STORAGE=$t/chair sp --role Implementer --slice g2i) >/dev/null; [ $? != 0 ]; ok $? "G2 a chair cannot spawn other roles"
(BB_THREAD_STORAGE=$t/chair sp --mode fresh --goal G --slice g2f) >/dev/null; [ $? != 0 ]; ok $? "G2 a chair cannot start a top-level thread"
(RF=$t/roster sp --role council-member --author claude-code:claude-opus-5-5 --chair codex:gpt-6.2-sol --slice g3) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "only a council chair"; ok $? "G3 a non-chair cannot spawn a member"
# Outside bb: the main thread spawns members itself, naming the chair; the chair's brief folder holds the council
o=$t/home/.agents/workflow/ob; mkdir -p "$o/workers/chair" "$o/workers/chair2"
printf 'chair codex:gpt-6.2-sol\nauthor claude-code:claude-opus-5-5\nsize 2\nlimited -\n' > "$o/workers/chair/.council-chair"
ob() { HOME=$t/home WORKFLOW_TASK=ob WORKFLOW_RUNTIME=claude-code WORKFLOW_DRY_RUN= $H spawn --role council-member --author claude-code:claude-opus-5-5 --chair "${OBC:-codex:gpt-6.2-sol}" --effort medium --brief "$t/b.md" "$@" 2>"$t/err"; }
r=$(ob --slice o1 --model sonnet); has "$r" 'model: "sonnet"' && grep -q 'claude-code:sonnet	-' "$o/workers/chair/council.log"; ok $? "O1 outside bb: main spawns a member with --chair, logged in the chair's folder"
ob --slice o2 --model haiku >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "council is full"; ok $? "O1 outside bb: size cap holds"
printf 'chair claude-code:claude-fable-5-2\nauthor claude-code:claude-opus-5-5\nsize 2\nlimited -\n' > "$o/workers/chair2/.council-chair"
(OBC=claude-code:claude-fable-5-2 ob --slice o4) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "council: 1 of 2, too few families"; ok $? "W6 outside bb: one vendor, no member; the chair rules marked too few families"
(OBC=claude-code:claude-fable-5-2 ob --slice o5 --model sonnet) >/dev/null; [ $? != 0 ] && has "$(cat "$t/err")" "family anthropic taken"; ok $? "W6 outside bb: no same-vendor substitute member"
r=$(HOME=$t/home WORKFLOW_TASK=ob WORKFLOW_RUNTIME=claude-code $H spawn --role council-chair --author claude-code:claude-opus-5-5 --effort medium --brief "$t/b.md" --slice o3 2>&1); has "$r" 'model: "fable"'; ok $? "W6 outside bb, Opus author: the built-in council has a default chair"
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
# H1 help
H="sh $(dirname "$0")/runtime.sh"
r=$($H help spawn); has "$r" "--env this|new" && ! has "$r" "runtime.sh tell"; ok $? "H1 help spawn: only spawn usage"
r=$($H help tell); has "$r" "runtime.sh tell <id>"; ok $? "H1 help tell"
$H help nope >/dev/null 2>&1; [ $? != 0 ]; ok $? "H1 help unknown command fails"
r=$($H help); has "$r" "WORKFLOW_HARNESS"; ok $? "H1 help prints the whole header"
[ $fail = 0 ] && echo "all passed" || { echo "FAILED"; exit 1; }
