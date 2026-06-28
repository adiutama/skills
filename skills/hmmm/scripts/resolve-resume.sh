#!/usr/bin/env bash
# Resolve which hmmm session to resume for the current repo + branch.
# Usage: resolve-resume.sh [session-id-or-slug-hint]
# Output: JSON { recommend, reason, phase, candidates: [...] }

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HINT="${1:-}"

candidates=$(bash "$SCRIPT_DIR/list-sessions.sh" 10)
count=$(jq 'length' <<<"$candidates")

if [[ "$count" -eq 0 ]]; then
  jq -n '{recommend: null, reason: "no sessions on this branch", phase: null, candidates: []}'
  exit 0
fi

if [[ -n "$HINT" ]]; then
  hint_lower=$(printf '%s' "$HINT" | tr '[:upper:]' '[:lower:]')
  matched=$(jq -c --arg h "$hint_lower" '
    [.[] | select(
      (.session_id | ascii_downcase | contains($h)) or
      (.problem | ascii_downcase | contains($h))
    )]
  ' <<<"$candidates")
  if [[ $(jq 'length' <<<"$matched") -gt 0 ]]; then
    candidates="$matched"
  fi
fi

recommend=$(jq -c '
  ( [.[] | select(.status == "active")] | .[0] ) //
  ( [.[] | select(.status == "done")] | .[0] ) //
  .[0]
' <<<"$candidates")

if [[ "$recommend" == "null" || -z "$recommend" ]]; then
  jq -n --argjson candidates "$candidates" \
    '{recommend: null, reason: "no matching session", phase: null, candidates: $candidates}'
  exit 0
fi

reason="newest active session"
status=$(jq -r '.status' <<<"$recommend")
[[ "$status" == "active" ]] || reason="newest session (status: ${status})"

phase=$(jq -r '.phase' <<<"$recommend")

jq -n \
  --argjson recommend "$recommend" \
  --arg reason "$reason" \
  --arg phase "$phase" \
  --argjson candidates "$candidates" \
  '{recommend: $recommend, reason: $reason, phase: $phase, candidates: $candidates}'
