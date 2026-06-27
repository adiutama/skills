#!/usr/bin/env bash
# List loop-until sessions for the current repo + branch, newest first.
# Usage: list-sessions.sh [limit]
# Output: JSON array [{ session_id, session_dir, status, goal, created }]

set -euo pipefail

LIMIT="${1:-5}"

resolve_owner_repo() {
  local url
  url=$(git remote get-url origin 2>/dev/null || true)
  if [[ -z "$url" ]]; then
    OWNER="_local"
    REPO="_local"
    return
  fi
  if [[ "$url" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]%.git}"
    return
  fi
  OWNER="_local"
  REPO="_local"
}

branch_slug() {
  local branch sha
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)
  if [[ "$branch" == "HEAD" ]]; then
    sha=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
    printf 'detached-%s' "$sha"
    return
  fi
  printf '%s' "$branch" | sed -E 's/[^a-zA-Z0-9]+/-/g; s/^-+|-+$//g'
}

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

resolve_owner_repo
BRANCH_SLUG=$(branch_slug)
BASE="${HOME}/.agents/artifacts/${OWNER}/${REPO}/${BRANCH_SLUG}/loop-until/sessions"

if [[ ! -d "$BASE" ]]; then
  jq -n '[]'
  exit 0
fi

entries=()
count=0
while IFS= read -r id; do
  [[ -z "$id" ]] && continue
  dir="${BASE}/${id}"
  meta="${dir}/meta.md"
  [[ -f "$meta" ]] || continue

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
  [[ "$count" -ge "$LIMIT" ]] && break
done < <(ls -1 "$BASE" 2>/dev/null | sort -r)

if [[ ${#entries[@]} -eq 0 ]]; then
  jq -n '[]'
else
  printf '%s\n' "${entries[@]}" | jq -s '.'
fi
