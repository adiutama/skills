#!/bin/sh
# Shared check for the spawn guards: spawn-check.sh "<shell command>"
# Exit 2 + message on stderr when the command runs a raw `bb thread spawn|create`;
# exit 0 otherwise (also for an empty command). Agent adapters call this.
cmd=${1:-}
[ -n "$cmd" ] || exit 0
# Issued by the wrapper (or marked as its call): allowed.
case $cmd in *harness.sh*) exit 0 ;; esac
# Read-only help (`bb thread spawn --help` / `-h`) is allowed; strip it before checking the rest.
cmd=$(printf '%s\n' "$cmd" | sed -E 's/bb[[:space:]]+thread[[:space:]]+(spawn|create)[[:space:]]+(--help|-h)([[:space:]]|$)/bb thread HELP /g')
if printf '%s\n' "$cmd" | grep -Eq '(^|[;&|(]|&&)[[:space:]]*([A-Za-z_][A-Za-z_0-9]*=[^[:space:]]*[[:space:]]+|env[[:space:]]+)*bb[[:space:]]+thread[[:space:]]+(spawn|create)([[:space:]]|$)'; then
  case $cmd in *WORKFLOW_SPAWN=1*) exit 0 ;; esac
  echo "Blocked: create threads with 'sh <dir>/scripts/harness.sh spawn --mode child|spin-off|fresh ...' (delegate | spin off | start fresh), not a raw bb thread spawn/create. '--help' is allowed." >&2
  exit 2
fi
exit 0
