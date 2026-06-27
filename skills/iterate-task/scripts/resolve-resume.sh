#!/usr/bin/env bash
# Resolve which session to resume for the current repo + branch.
# Usage: resolve-resume.sh [session-id-or-slug-hint]
# Output: JSON { recommend, reason, iteration_count, candidates: [...] }

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HINT="${1:-}"

candidates=$(bash "$SCRIPT_DIR/list-sessions.sh" 10)
count=$(jq 'length' <<<"$candidates")

if [[ "$count" -eq 0 ]]; then
  jq -n '{recommend: null, reason: "no sessions on this branch", iteration_count: 0, candidates: []}'
  exit 0
fi

strip_quotes() {
  sed -E 's/^"|"$//g; s/^'\''|'\''$//g'
}

iteration_count_for() {
  local dir="$1" master="${dir}/master.md"
  [[ -f "$master" ]] || { echo 0; return; }
  awk '/^\| [0-9]+ \|/{c++} END{print c+0}' "$master"
}

build_enriched() {
  jq -c '.[]' <<<"$candidates" | while read -r row; do
    dir=$(jq -r '.session_dir' <<<"$row")
    iter=$(iteration_count_for "$dir")
    jq -n \
      --argjson base "$row" \
      --argjson iteration_count "$iter" \
      '$base + {iteration_count: $iteration_count}'
  done | jq -s '.'
}

enriched=$(build_enriched)

if [[ -n "$HINT" ]]; then
  hint_lower=$(printf '%s' "$HINT" | tr '[:upper:]' '[:lower:]')
  matched=$(jq -c --arg h "$hint_lower" '
    [.[] | select(
      (.session_id | ascii_downcase | contains($h)) or
      (.goal | ascii_downcase | contains($h))
    )]
  ' <<<"$enriched")
  if [[ $(jq 'length' <<<"$matched") -gt 0 ]]; then
    enriched="$matched"
  fi
fi

recommend=$(jq -c '
  ( [.[] | select(.status == "active")] | .[0] ) //
  ( [.[] | select(.status == "blocked" or .status == "max-reached")] | .[0] ) //
  .[0]
' <<<"$enriched")

if [[ "$recommend" == "null" || -z "$recommend" ]]; then
  jq -n --argjson candidates "$enriched" \
    '{recommend: null, reason: "no matching session", iteration_count: 0, candidates: $candidates}'
  exit 0
fi

reason="newest active session"
status=$(jq -r '.status' <<<"$recommend")
[[ "$status" == "active" ]] || reason="newest resumable session (status: ${status})"

jq -n \
  --argjson recommend "$recommend" \
  --arg reason "$reason" \
  --argjson iteration_count "$(jq '.iteration_count' <<<"$recommend")" \
  --argjson candidates "$enriched" \
  '{recommend: $recommend, reason: $reason, iteration_count: $iteration_count, candidates: $candidates}'
