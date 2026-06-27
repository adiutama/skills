#!/usr/bin/env bash
# Reply to a pull request review thread comment.
# Usage: reply.sh <OWNER> <REPO> <NUMBER> <COMMENT_ID>
# Input:  reply body on stdin
# Output: reply html_url

set -euo pipefail

usage() {
  echo "Usage: reply.sh <OWNER> <REPO> <NUMBER> <COMMENT_ID>" >&2
}

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

main() {
  local owner repo number comment_id body
  owner=${1:-}
  repo=${2:-}
  number=${3:-}
  comment_id=${4:-}

  [[ -n "$owner" && -n "$repo" && -n "$number" && -n "$comment_id" ]] || {
    usage
    exit 1
  }

  require_dependencies
  body=$(cat)

  [[ -n "$body" ]] || {
    echo "Error: reply body is empty" >&2
    exit 1
  }

  gh api "repos/${owner}/${repo}/pulls/${number}/comments/${comment_id}/replies" \
    --method POST \
    -f body="$body" | jq -r '.html_url'
}

main "$@"
