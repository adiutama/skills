#!/usr/bin/env bash
# Durable lifecycle for orchestrate sessions.
# Usage: session.sh init [slug] [vision] | list | resolve [hint] | touch <session-id> | close <session-id>

set -euo pipefail

command -v git >/dev/null || { echo "git is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

git_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
repo=$(basename "$git_root")
owner=$(basename "$(dirname "$git_root")")
branch=$(git -C "$git_root" branch --show-current 2>/dev/null || true)
branch=${branch:-detached}
branch_slug=$(printf '%s' "$branch" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')

if git -C "$git_root" check-ignore -q .agents 2>/dev/null || git -C "$git_root" check-ignore -q .agents/artifacts 2>/dev/null; then
  root="$git_root/.agents/artifacts"
else
  root="${AGENTS_ARTIFACTS_ROOT:-${HOME}/.agents/artifacts}"
fi

base="$root/$owner/$repo/$branch_slug/orchestrate/sessions"

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

slugify() {
  printf '%s' "${1:-session}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' | cut -c1-40
}

list_sessions() {
  if [[ ! -d "$base" ]]; then
    printf '[]\n'
    return
  fi
  output=$(find "$base" -mindepth 2 -maxdepth 2 -name meta.json -type f \
    -exec jq -s 'sort_by(.updated) | reverse | .[:10]' {} + 2>/dev/null || true)
  [[ -n "$output" ]] && printf '%s\n' "$output" || printf '[]\n'
}

action=${1:-}
shift || true

case "$action" in
  init)
    slug=$(slugify "${1:-session}")
    vision=${2:-}
    id="$(date -u +%Y%m%d-%H%M%S)-$slug"
    dir="$base/$id"
    [[ ! -e "$dir" ]] || { echo "session already exists: $dir" >&2; exit 1; }
    mkdir -p "$dir/handoffs"
    created=$(now)
    jq -n \
      --arg id "$id" --arg status active --arg created "$created" --arg updated "$created" \
      --arg repo "$repo" --arg branch "$branch" --arg vision "$vision" --arg path "$dir" \
      '{id:$id,status:$status,created:$created,updated:$updated,repo:$repo,branch:$branch,vision:$vision,path:$path}' \
      >"$dir/meta.json"
    printf '# Vision\n\n## Intent\n\n## Desired outcomes\n\n## Constraints\n\n## Non-goals\n' >"$dir/vision.md"
    printf '# State\n\n## Current direction\n\n## Confirmed decisions\n\n## Active work\n\n## Important findings\n\n## Open questions\n\n## Risks and blockers\n\n## Next useful action\n' >"$dir/state.md"
    printf '# Log\n\n- %s — Session created.\n' "$created" >"$dir/log.md"
    jq . "$dir/meta.json"
    ;;
  list)
    list_sessions
    ;;
  resolve)
    hint=${1:-}
    sessions=$(list_sessions)
    if [[ -n "$hint" ]]; then
      hint=$(printf '%s' "$hint" | tr '[:upper:]' '[:lower:]')
      sessions=$(jq --arg hint "$hint" '[.[] | select((.id|ascii_downcase|contains($hint)) or (.vision|ascii_downcase|contains($hint)))]' <<<"$sessions")
    fi
    jq '{recommend: ([.[] | select(.status == "active")][0] // null), candidates: .[:5]}' <<<"$sessions"
    ;;
  touch)
    id=${1:-}
    [[ -n "$id" ]] || { echo "session id is required" >&2; exit 1; }
    dir="$base/$id"
    [[ -f "$dir/meta.json" ]] || { echo "session not found: $id" >&2; exit 1; }
    updated=$(now)
    tmp="$dir/meta.json.tmp"
    jq --arg updated "$updated" '.updated=$updated' "$dir/meta.json" >"$tmp"
    mv "$tmp" "$dir/meta.json"
    jq . "$dir/meta.json"
    ;;
  close)
    id=${1:-}
    [[ -n "$id" ]] || { echo "session id is required" >&2; exit 1; }
    dir="$base/$id"
    [[ -f "$dir/meta.json" ]] || { echo "session not found: $id" >&2; exit 1; }
    updated=$(now)
    tmp="$dir/meta.json.tmp"
    jq --arg updated "$updated" '.status="closed" | .updated=$updated' "$dir/meta.json" >"$tmp"
    mv "$tmp" "$dir/meta.json"
    printf '\n- %s — Session closed.\n' "$updated" >>"$dir/log.md"
    jq . "$dir/meta.json"
    ;;
  *)
    echo 'usage: session.sh init [slug] [vision] | list | resolve [hint] | touch <session-id> | close <session-id>' >&2
    exit 2
    ;;
esac
