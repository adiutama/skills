#!/bin/sh
# test-spawn.sh — checks harness.sh spawn (all modes) and spawn-check.sh with WORKFLOW_DRY_RUN; no real threads.
here=$(cd "$(dirname "$0")" && pwd)
H="sh $here/harness.sh"; C="sh $here/spawn-check.sh"
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
export WORKFLOW_HARNESS=bb WORKFLOW_DRY_RUN=1 BB_THREAD_ID=thr_origin BB_PROJECT_ID=proj_1 BB_ENVIRONMENT_ID=env_1 BB_THREAD_STORAGE=$t/st
mkdir -p "$t/st/workers/s1"; echo "Role: Implementer" > "$t/b.md"
fail=0
ok() { if [ "$1" = 0 ]; then echo "ok   $2"; else echo "FAIL $2"; fail=1; fi; }
has() { printf '%s\n' "$1" | grep -qF -- "$2"; }
hasnt() { ! has "$1" "$2"; }

# fake bb: project kind, provider list ($FAKE_PROVIDERS), roster memory ($FAKE_ROSTER file, absent = no roster)
mkdir -p "$t/bin"
cat > "$t/bin/bb" <<'FAKE'
#!/bin/sh
case "$1 $2" in
  "project show")
    if [ "$3" = proj_personal ]; then k=personal; else k=standard; fi
    printf '{\n  "id": "%s",\n  "kind": "%s",\n  "name": "x"\n}\n' "$3" "$k" ;;
  "provider list")
    printf 'ID    Name\n----  ----\n'; for p in ${FAKE_PROVIDERS-claude-code codex acp-opencode}; do printf '%s  x\n------  ----\n' "$p"; done ;;
  "memory search")
    [ -f "$FAKE_ROSTER" ] && printf '{\n  "memories": [\n    {\n      "id": "mem_r",\n    }\n  ]\n}\n' ;;
  "memory get")
    [ -f "$FAKE_ROSTER" ] && printf '{\n  "memory": {\n    "id": "mem_r",\n    "name": "agent-roster",\n    "details": "%s",\n    "version": 1\n  }\n}\n' "$(awk '{printf "%s\\n", $0}' "$FAKE_ROSTER")" ;;
esac
FAKE
chmod +x "$t/bin/bb"; PATH=$t/bin:$PATH
# A1
c=$($H spawn --role Implementer --effort medium --brief "$t/b.md" --slice s1 --isolated); has "$c" "--parent-self"; ok $? "A1 child has --parent-self"
s=$($H spawn --mode spin-off --goal G --provider claude-code --model sonnet --effort high --brief "$t/b.md" --slice sp); hasnt "$s" "--parent-self" && has "$s" "--new-environment worktree" && has "$s" "--title G"; ok $? "A1 spin-off top-level, worktree, title=goal"
f=$($H spawn --mode fresh --goal G --provider codex --model gpt-6.1-sol --effort high --brief "$t/b.md" --slice fr); hasnt "$f" "--parent-self" && has "$f" "bb thread update thr_origin --parent-thread '<new>' --parent-notifications off"; ok $? "A1 fresh re-parents origin"
# A2
b=$(cat "$t/st/briefs/sp-spin-off.md"); has "$b" "@thread:thr_origin" && has "$b" "DONE" && has "$b" "BLOCKED" && has "$b" "FAILED" && has "$b" "bb thread tell thr_origin"; ok $? "A2 spin-off brief reporting"
$H spawn --mode spin-off --goal G --tier balanced --effort high --brief "$t/b.md" --slice sm --report-after-merge >/dev/null; has "$(cat "$t/st/briefs/sm-spin-off.md")" "only after your PR has merged"; ok $? "A2 after-merge trigger"
# A3
$H spawn --mode spin-off --goal G --tier balanced --effort high --brief "$t/b.md" --slice w --wait-go >/dev/null; has "$(cat "$t/st/briefs/w-spin-off.md")" "Hold:"; ok $? "A3 --wait-go hold"
a=$($H spawn --mode spin-off --goal G --tier balanced --effort high --brief "$t/b.md" --slice af --after thr_x); has "$(cat "$t/st/briefs/af-spin-off.md")" "thr_x" && has "$a" "bb thread tell thr_x"; ok $? "A3 --after untracked tells X"
printf '| @thread:thr_y | t |\n' > "$t/st/spin-offs.md"
a=$($H spawn --mode spin-off --goal G --tier balanced --effort high --brief "$t/b.md" --slice ay --after thr_y); hasnt "$a" "bb thread tell thr_y"; ok $? "A3 --after tracked: no tell"
# A4
$H spawn --mode spin-off --goal G --tier balanced --effort high --brief "$t/b.md" --slice nc --context none >/dev/null; hasnt "$(cat "$t/st/briefs/nc-spin-off.md")" "Context:"; ok $? "A4 --context none"
# W1: waiting-on column must not count as tracked
printf '| @thread:thr_z | t | d | done | thr_w | running | - |\n' > "$t/st/spin-offs.md"
a=$($H spawn --mode spin-off --goal G --tier balanced --effort high --brief "$t/b.md" --slice wz --after thr_w); has "$a" "bb thread tell thr_w" && has "$(cat "$t/st/briefs/wz-spin-off.md")" "tells you \"go\" directly"; ok $? "W1 waiting-on is not tracked"
printf '| @thread:thr_y | t |\n' > "$t/st/spin-offs.md"
# W2: none rejects a brief with a Context section
printf 'Goal: x\nContext: from the origin\n' > "$t/ctx.md"
$H spawn --mode spin-off --goal G --tier balanced --effort high --brief "$t/ctx.md" --slice cx --context none >/dev/null 2>&1; [ $? != 0 ]; ok $? "W2 none rejects Context: brief"
# W5: fresh always names the origin
$H spawn --mode fresh --goal G --tier balanced --effort high --brief "$t/b.md" --slice fo --context none --wait-go >/dev/null; has "$(cat "$t/st/briefs/fo-fresh.md")" "@thread:thr_origin"; ok $? "W5 fresh names origin"
# Personal project: personal workspace, not worktree
pp=$($H spawn --mode spin-off --goal G --tier balanced --effort high --brief "$t/b.md" --slice pp --project proj_personal); has "$pp" "--new-environment personal" && hasnt "$pp" "worktree"; ok $? "personal project uses --new-environment personal"
pf=$($H spawn --mode fresh --goal G --tier balanced --effort high --brief "$t/b.md" --slice pf --project proj_personal); has "$pf" "--new-environment personal"; ok $? "personal project, fresh"
pi=$($H spawn --role Implementer --effort medium --brief "$t/b.md" --slice pi --isolated --project proj_personal); has "$pi" "--new-environment personal"; ok $? "personal project, isolated child"
# W4: quoting and --json
mkdir -p "$t/sp ace"; echo x > "$t/sp ace/b.md"
q=$(BB_THREAD_STORAGE="$t/st x" $H spawn --mode spin-off --goal "Fix queued status" --tier balanced --effort high --brief "$t/sp ace/b.md" --slice qs); has "$q" "--title 'Fix queued status'" && has "$q" "--json" && has "$q" "--prompt-file '$t/st x/briefs/qs-spin-off.md'"; ok $? "W4 dry-run quotes args, has --json"
# A5
for r in "$c" "$s" "$f"; do has "$r" " → @thread:<new> · " && printf '%s\n' "$r" | grep -Eq 'high|medium' ; [ $? = 0 ] || fail=1; done
has "$s" "Spun off → @thread:<new> · top-level · " && has "$s" "claude-code/sonnet · high"; ok $? "A5 receipt line"
# A6
printf 's1\tthr_old\n' > "$t/st/spawned.log"
e=$($H spawn --role Implementer --effort medium --brief "$t/b.md" --slice s1 2>&1); r=$?
[ $r != 0 ] && has "$e" "bb thread retry thr_old"; ok $? "A6 re-spawn refused"
$H spawn --role Implementer --effort medium --brief "$t/b.md" --slice s1 --force >/dev/null 2>&1; ok $? "A6 --force passes"
# host passthrough
hh=$($H spawn --mode spin-off --goal G --tier balanced --effort high --brief "$t/b.md" --slice hh --host mac1); has "$hh" "--host mac1"; ok $? "host passed to bb thread spawn"
hn=$($H spawn --mode spin-off --goal G --tier balanced --effort high --brief "$t/b.md" --slice hn); hasnt "$hn" "--host"; ok $? "no --host by default"
# adopt
ad=$($H adopt thr_x); has "$ad" "bb thread update thr_x --parent-thread thr_origin --parent-notifications auto" && has "$ad" "Adopted → @thread:thr_x · child · reports every outcome"; ok $? "adopt re-parents, notifications auto"
aq=$($H adopt thr_x --quiet); has "$aq" "--parent-notifications off" && has "$aq" "reports off"; ok $? "adopt --quiet"
$H adopt thr_origin >/dev/null 2>&1; [ $? != 0 ]; ok $? "adopt refuses self"
ac=$(WORKFLOW_HARNESS=claude-code $H adopt thr_x); has "$ac" "adopt needs bb"; ok $? "adopt outside bb prints instruction"
# Reviewer: walks the roster's reviewer.order, skipping the author's model except as the last resort
printf 'tier.deep  claude-code:claude-opus-5-5\nreviewer.order   codex:gpt-6.1-sol  acp-opencode:opencode-go/grok-4.7  claude-code:claude-fable-5-2  claude-code:claude-opus-5-5\nreviewer.never   gemini\n' > "$t/roster"
rv() { n=$1 rf=$2; shift 2; FAKE_ROSTER=$rf $H spawn --role Reviewer --effort medium --brief "$t/b.md" --slice "rv$n" --force "$@" 2>"$t/rv.err"; }
r=$(rv 1 $t/roster --author claude-code:claude-opus-5-5); has "$r" "--provider codex --model gpt-6.1-sol"; ok $? "R1 first order entry"
r=$(rv 2 $t/roster --author codex:gpt-6.1-sol); has "$r" "--provider acp-opencode --model opencode-go/grok-4.7"; ok $? "R2 author's model skipped"
r=$(rv 3 $t/roster --author claude-code:claude-opus-5-5 --limited codex,acp-opencode); has "$r" "--provider claude-code --model claude-fable-5-2"; ok $? "R3 same vendor, other model reviews"
r=$(FAKE_PROVIDERS="claude-code acp-opencode" rv 4 $t/roster --author claude-code:claude-opus-5-5 --limited acp-opencode); has "$r" "--model claude-fable-5-2"; ok $? "R4 missing provider skipped"
r=$(rv 5 $t/roster --author claude-code:claude-fable-5-2 --limited codex,acp-opencode); has "$r" "--model claude-opus-5-5"; ok $? "R5 Fable-authored: Opus reviews"
printf 'reviewer.order   codex:gpt-6.1-sol  claude-code:claude-opus-5-5\n' > "$t/roster2"
r=$(rv 6 $t/roster2 --author claude-code:claude-opus-5-5 --limited codex); has "$r" "--provider claude-code --model claude-opus-5-5" && has "$(cat "$t/rv.err")" "last resort"; ok $? "R6 author's model as last resort, noted"
e=$(rv 7 $t/roster2 --author codex:gpt-6.1-sol --limited claude-code,codex 2>&1); [ $? != 0 ] && has "$(cat "$t/rv.err")" "no reviewer.order entry is available"; ok $? "R7 nothing available fails"
r=$(rv 8 $t/roster --author claude-code); has "$r" "--provider codex --model gpt-6.1-sol"; ok $? "R8 author without model: its vendor skipped"
r=$(rv 9 $t/roster --author claude-code --limited codex,acp-opencode); has "$r" "--model claude-fable-5-2" && has "$(cat "$t/rv.err")" "last resort"; ok $? "R9 author without model: its vendor is the last resort"
printf 'reviewer.order   gemini:g-3  codex:gpt-6.1-sol\nreviewer.never   gemini\n' > "$t/roster3"
r=$(rv 10 $t/roster3 --author claude-code:claude-opus-5-5); has "$r" "--provider codex"; ok $? "R10 reviewer.never skipped"
r=$(rv 11 none --author codex); has "$r" "--provider claude-code --model opus"; ok $? "R11 no roster: the other vendor"
r=$(rv 12 $t/roster --author claude-code:claude-opus-5-5 --provider acp-opencode --model opencode-go/glm-5.3); has "$r" "--provider acp-opencode --model opencode-go/glm-5.3"; ok $? "R12 --provider/--model override"
# A7
$C "bb thread spawn --help" 2>/dev/null; ok $? "A7 spawn --help allowed"
$C "bb thread create -h" 2>/dev/null; ok $? "A7 create -h allowed"
$C "bb thread spawn --prompt x" 2>/dev/null; [ $? = 2 ]; ok $? "A7 raw spawn blocked"
$C "bb thread spawn --help; bb thread spawn --prompt x" 2>/dev/null; [ $? = 2 ]; ok $? "A7 help + raw blocked"
$C "sh /x/scripts/harness.sh spawn --mode fresh" 2>/dev/null; ok $? "A7 harness.sh allowed"
[ $fail = 0 ] && echo "all passed" || { echo "FAILED"; exit 1; }
