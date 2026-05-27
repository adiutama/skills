#!/usr/bin/env bash
# Resolve PR identity and locate the latest review session file.
# Usage: resolve.sh <PR URL or number>
# Output: JSON { owner, repo, number, head_sha, branch, session_path }
#   session_path — highest-numbered NN.md under reviews/<owner>/<repo>/<slug>/
#                  or empty string if no session file exists yet.

set -euo pipefail

require_dependencies() {
  command -v gh &>/dev/null || {
    echo "Error: gh CLI not installed. See https://cli.github.com" >&2
    exit 1
  }
  command -v jq &>/dev/null || {
    echo "Error: jq not installed. Run: brew install jq" >&2
    exit 1
  }
}

parse_pr_identity() {
  local arg="$1"

  if [[ "$arg" =~ ^https://github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
    NUMBER="${BASH_REMATCH[3]}"
    return
  fi

  if [[ "$arg" =~ ^[0-9]+$ ]]; then
    local name_with_owner
    name_with_owner=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) || {
      echo "Error: could not detect repo — run from inside a git repo or provide the full PR URL." >&2
      exit 1
    }
    OWNER="${name_with_owner%%/*}"
    REPO="${name_with_owner##*/}"
    NUMBER="$arg"
    return
  fi

  echo "Error: expected a GitHub PR URL or number, got: $arg" >&2
  exit 1
}

latest_session_file() {
  local dir="$1"
  local files

  [[ -d "$dir" ]] || return 0

  shopt -s nullglob
  files=("$dir"/*.md)
  shopt -u nullglob
  [[ ${#files[@]} -gt 0 ]] || return 0

  printf '%s\n' "${files[@]}" | sort -V | tail -1
}

print_output_json() {
  local head_sha="$1"
  local branch="$2"
  local session_path="$3"

  jq -n \
    --arg owner "$OWNER" \
    --arg repo "$REPO" \
    --arg number "$NUMBER" \
    --arg head_sha "$head_sha" \
    --arg branch "$branch" \
    --arg session_path "$session_path" \
    '{owner:$owner, repo:$repo, number:$number, head_sha:$head_sha, branch:$branch, session_path:$session_path}'
}

main() {
  local arg meta branch head_sha slug dir session_path
  arg=${1:?"Usage: resolve.sh <PR URL or number>"}

  require_dependencies
  parse_pr_identity "$arg"

  meta=$(gh pr view "$NUMBER" --repo "$OWNER/$REPO" --json headRefName,headRefOid)
  branch=$(printf '%s' "$meta" | jq -r .headRefName)
  head_sha=$(printf '%s' "$meta" | jq -r .headRefOid)

  slug=$(printf '%s' "$branch" | tr -cs 'a-zA-Z0-9' '-' | sed 's/^-//;s/-$//')
  dir="reviews/${OWNER}/${REPO}/${slug}"
  session_path=$(latest_session_file "$dir")

  print_output_json "$head_sha" "$branch" "$session_path"
}

main "$@"
