#!/usr/bin/env bash
# Locate an existing PR feedback session (no re-fetch).
# Usage: resolve-session.sh [PR URL or number]
#   With no arg: newest pr-* session under current branch slug.
# Output: same JSON shape as start-session.sh, or { session_dir: null }

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/lib/artifact-root.sh"

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

emit_session_json() {
  local session_dir="$1"
  local meta_path="${session_dir}/meta.md"
  local findings_path="${session_dir}/findings.json"

  local number title url branch head_sha
  number=$(read_meta_field "$meta_path" pr)
  title=$(read_meta_field "$meta_path" title)
  url=$(read_meta_field "$meta_path" url)
  branch=$(read_meta_field "$meta_path" branch)
  head_sha=$(read_meta_field "$meta_path" head_sha)

  local thread_count review_count comment_count total
  thread_count=$(jq '.threads | length' "$findings_path")
  review_count=$(jq '.reviews | length' "$findings_path")
  comment_count=$(jq '.comments | length' "$findings_path")
  total=$((thread_count + review_count + comment_count))

  jq -n \
    --arg owner "$OWNER" \
    --arg repo "$REPO" \
    --arg number "$number" \
    --arg title "$title" \
    --arg url "$url" \
    --arg branch "$branch" \
    --arg head_sha "$head_sha" \
    --arg session_dir "$session_dir" \
    --arg findings_path "$findings_path" \
    --arg meta_path "$meta_path" \
    --arg tracker_path "${session_dir}/tracker.md" \
    --arg report_path "${session_dir}/report.md" \
    --argjson thread_count "$thread_count" \
    --argjson review_count "$review_count" \
    --argjson comment_count "$comment_count" \
    --argjson total_count "$total" \
    '{
      owner: $owner,
      repo: $repo,
      number: $number,
      title: $title,
      url: $url,
      branch: $branch,
      head_sha: $head_sha,
      session_dir: $session_dir,
      findings_path: $findings_path,
      meta_path: $meta_path,
      tracker_path: $tracker_path,
      report_path: $report_path,
      thread_count: $thread_count,
      review_count: $review_count,
      comment_count: $comment_count,
      total_count: $total_count
    }'
}

main() {
  local arg="${1:-}"
  command -v jq &>/dev/null || { echo "Error: jq not installed." >&2; exit 1; }

  resolve_owner_repo
  SLUG=$(branch_slug)

  local session_dir=""
  local root base
  if [[ -n "$arg" ]]; then
    local number=""
    if [[ "$arg" =~ ^https://github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
      OWNER="${BASH_REMATCH[1]}"
      REPO="${BASH_REMATCH[2]}"
      number="${BASH_REMATCH[3]}"
    elif [[ "$arg" =~ ^[0-9]+$ ]]; then
      number="$arg"
    fi
    if [[ -n "$number" ]]; then
      while IFS= read -r root; do
        [[ -n "$root" ]] || continue
        candidate="${root}/${OWNER}/${REPO}/${SLUG}/address-pr-feedback/pr-${number}"
        if [[ -d "$candidate" ]]; then
          session_dir="$candidate"
          break
        fi
      done < <(artifact_search_roots)
    fi
  else
    while IFS= read -r root; do
      [[ -n "$root" ]] || continue
      base="${root}/${OWNER}/${REPO}/${SLUG}/address-pr-feedback"
      [[ -d "$base" ]] || continue
      candidate=$(find "$base" -mindepth 1 -maxdepth 1 -type d -name 'pr-*' 2>/dev/null | sort -r | head -1)
      if [[ -n "$candidate" ]]; then
        session_dir="$candidate"
        break
      fi
    done < <(artifact_search_roots)
  fi

  if [[ -z "$session_dir" || ! -f "${session_dir}/findings.json" ]]; then
    jq -n '{session_dir: null}'
    exit 0
  fi

  emit_session_json "$session_dir"
}

main "$@"
