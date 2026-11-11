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

# A1
c=$($H spawn --role Implementer --effort medium --brief "$t/b.md" --slice s1 --isolated); has "$c" "--parent-self"; ok $? "A1 child has --parent-self"
s=$($H spawn --mode spin-off --goal G --tier balanced --effort high --brief "$t/b.md" --slice sp); hasnt "$s" "--parent-self" && has "$s" "--new-environment worktree" && has "$s" "--title G"; ok $? "A1 spin-off top-level, worktree, title=goal"
f=$($H spawn --mode fresh --goal G --provider codex --model gpt-6.1-sol --effort high --brief "$t/b.md" --slice fr); hasnt "$f" "--parent-self" && has "$f" "bb thread update thr_origin --parent-thread <new> --parent-notifications off"; ok $? "A1 fresh re-parents origin"
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
# A5
for r in "$c" "$s" "$f"; do has "$r" " → @thread:<new> · " && printf '%s\n' "$r" | grep -Eq 'high|medium' ; [ $? = 0 ] || fail=1; done
has "$s" "Spun off → @thread:<new> · top-level · " && has "$s" "claude-code/sonnet · high"; ok $? "A5 receipt line"
# A6
printf 's1\tthr_old\n' > "$t/st/spawned.log"
e=$($H spawn --role Implementer --effort medium --brief "$t/b.md" --slice s1 2>&1); r=$?
[ $r != 0 ] && has "$e" "bb thread retry thr_old"; ok $? "A6 re-spawn refused"
$H spawn --role Implementer --effort medium --brief "$t/b.md" --slice s1 --force >/dev/null 2>&1; ok $? "A6 --force passes"
# A7
$C "bb thread spawn --help" 2>/dev/null; ok $? "A7 spawn --help allowed"
$C "bb thread create -h" 2>/dev/null; ok $? "A7 create -h allowed"
$C "bb thread spawn --prompt x" 2>/dev/null; [ $? = 2 ]; ok $? "A7 raw spawn blocked"
$C "bb thread spawn --help; bb thread spawn --prompt x" 2>/dev/null; [ $? = 2 ]; ok $? "A7 help + raw blocked"
$C "sh /x/scripts/harness.sh spawn --mode fresh" 2>/dev/null; ok $? "A7 harness.sh allowed"
[ $fail = 0 ] && echo "all passed" || { echo "FAILED"; exit 1; }
