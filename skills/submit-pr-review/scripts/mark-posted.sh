#!/usr/bin/env bash
# Mark findings as posted in a review session file.
# Usage: mark-posted.sh <session_path> <ID> [<ID> ...]
# For each ID, changes the first "| Posted | ❌ |" inside its finding block to "| Posted | ✅ |".

set -euo pipefail

usage() {
  echo "Usage: mark-posted.sh <session_path> <ID>..." >&2
}

mark_posted_for_id() {
  local session="$1"
  local finding_id="$2"
  local temp_file
  temp_file=$(mktemp "${TMPDIR:-/tmp}/mark-posted.XXXXXX")

  awk -v id="$finding_id" '
    /^### /  { in_block = ($0 ~ ("^### " id " (—|-)")) }
    in_block && /\| Posted[[:space:]]*\| ❌ \|/ { sub(/❌/, "✅"); in_block = 0 }
    { print }
  ' "$session" > "$temp_file"

  mv "$temp_file" "$session"
}

main() {
  local session_path
  session_path=${1:-}
  [[ -n "$session_path" ]] || { usage; exit 1; }
  shift || true

  [[ $# -gt 0 ]] || { usage; exit 1; }

  for finding_id in "$@"; do
    mark_posted_for_id "$session_path" "$finding_id"
  done
}

main "$@"
