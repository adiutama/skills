#!/usr/bin/env bash
# List work-until sessions for the current repo + branch, newest first.
# Usage: list-sessions.sh [limit]
# Output: JSON array [{ session_id, session_dir, status, goal, created }]

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=artifacts.sh
source "${SCRIPT_DIR}/artifacts.sh"

LIMIT="${1:-5}"

read_meta_field() {
  local file="$1" key="$2"
  awk -v k="$key" '
    /^---$/ { in_fm=(in_fm?0:1); next }
    in_fm && $1 == k ":" {
      sub(/^[^:]*:[[:space:]]*/, "")
      gsub(/^"/, ""); gsub(/"$/, "")
      print
      exit
    }
  ' "$file" 2>/dev/null || true
}

artifact_git_owner_repo
BRANCH_SLUG=$(artifact_branch_slug)

entries=()
seen=$'\n'
count=0

collect_sessions() {
  local base="$1" id dir meta status goal created
  base="$1"
  [[ -d "$base" ]] || return 0

  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    [[ "$seen" == *$'\n'"${id}"$'\n'* ]] && continue
    dir="${base}/${id}"
    meta="${dir}/meta.md"
    [[ -f "$meta" ]] || continue

    seen+="${id}"$'\n'
    status=$(read_meta_field "$meta" status)
    goal=$(read_meta_field "$meta" goal)
    created=$(read_meta_field "$meta" created)

    entries+=("$(jq -n \
      --arg session_id "$id" \
      --arg session_dir "$dir" \
      --arg status "$status" \
      --arg goal "$goal" \
      --arg created "$created" \
      '{session_id: $session_id, session_dir: $session_dir, status: $status, goal: $goal, created: $created}')")

    count=$((count + 1))
    [[ "$count" -ge "$LIMIT" ]] && return
  done < <(ls -1 "$base" 2>/dev/null | sort -r)
}

while IFS= read -r root; do
  [[ -n "$root" ]] || continue
  collect_sessions "${root}/${OWNER}/${REPO}/${BRANCH_SLUG}/work-until/sessions"
  [[ "$count" -ge "$LIMIT" ]] && break
done < <(artifact_search_roots)

if [[ ${#entries[@]} -eq 0 ]]; then
  jq -n '[]'
else
  printf '%s\n' "${entries[@]}" | jq -s '.'
fi
