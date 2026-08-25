#!/usr/bin/env bash
# TEMPLATE ONLY — copy to skills/<skill-name>/scripts/mark-posted.sh
#
# Mark findings as posted in a canonical review JSON file.
# Usage: mark-posted.sh <session_path> <ID> [<ID> ...]
# For each ID, changes its `posting` value to `posted`.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]] && [[ "${BASH_SOURCE[0]}" == *"docs/assets/mark-posted.sh" ]]; then
  cat >&2 <<'EOF'
Error: docs/assets/mark-posted.sh is a template only — not for runtime use.
Copy to skills/<skill-name>/scripts/mark-posted.sh, then run that copy.
EOF
  exit 1
fi

set -euo pipefail

usage() {
  echo "Usage: mark-posted.sh <session_path> <ID>..." >&2
}

main() {
  local session_path ids_json temp_file
  session_path=${1:-}
  [[ -n "$session_path" ]] || { usage; exit 1; }
  shift || true

  [[ $# -gt 0 ]] || { usage; exit 1; }

  command -v jq >/dev/null 2>&1 || { echo "Error: jq is required." >&2; exit 1; }
  jq -e 'type == "object" and (.findings | type == "array")' "$session_path" >/dev/null || {
    echo "Error: invalid review JSON: $session_path" >&2
    exit 1
  }

  ids_json=$(printf '%s\n' "$@" | jq -R . | jq -s .)
  temp_file=$(mktemp "${TMPDIR:-/tmp}/mark-posted.XXXXXX")
  jq --argjson ids "$ids_json" '
    (.findings[] | select(.id as $id | $ids | index($id)) | .posting) = "posted"
  ' "$session_path" > "$temp_file"
  mv "$temp_file" "$session_path"
}

main "$@"
