#!/bin/sh
# Claude Code PreToolUse hook for Bash: blocks a raw `bb thread spawn|create`.
# Workers are spawned only through harness.sh spawn. Fails open on any parse problem.
in=$(cat 2>/dev/null) || exit 0
cmd=$(printf '%s' "$in" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -n "$cmd" ] || exit 0
# Issued by the wrapper (or marked as its call): allowed.
case $cmd in *harness.sh*) exit 0 ;; esac
if printf '%s\n' "$cmd" | grep -Eq '(^|[;&|(]|&&)[[:space:]]*([A-Za-z_][A-Za-z_0-9]*=[^[:space:]]*[[:space:]]+|env[[:space:]]+)*bb[[:space:]]+thread[[:space:]]+(spawn|create)([[:space:]]|$)'; then
  case $cmd in *WORKFLOW_SPAWN=1*) exit 0 ;; esac
  echo "Blocked: spawn workers with 'sh <dir>/scripts/harness.sh spawn --role R --effort E --brief FILE', not a raw bb thread spawn/create." >&2
  exit 2
fi
exit 0
