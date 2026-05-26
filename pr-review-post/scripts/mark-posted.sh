#!/usr/bin/env bash
# Mark findings as posted in a review session file.
# Usage: mark-posted.sh <session_path> <ID> [<ID> ...]
# For each ID, changes the first "| Posted | ❌ |" inside its finding block to "| Posted | ✅ |".

set -euo pipefail

SESSION=${1:?"Usage: mark-posted.sh <session_path> <ID>..."}
shift

for ID in "$@"; do
  awk -v id="$ID" '
    /^### /  { in_block = ($0 ~ ("^### " id " -")) }
    in_block && /\| Posted[[:space:]]*\| ❌ \|/ { sub(/❌/, "✅"); in_block = 0 }
    { print }
  ' "$SESSION" > "${SESSION}.tmp" && mv "${SESSION}.tmp" "$SESSION"
done
