#!/usr/bin/env bash
# Post a GitHub PR review.
# Usage: post.sh <OWNER> <REPO> <NUMBER> <HEAD_SHA> <EVENT>
# Input:  JSON on stdin — { "body": "...", "comments": [{ "path", "line", "body" }] }
#         Omit "comments" (or pass []) for APPROVE with no inline findings.
# Output: Review html_url

set -euo pipefail

usage() {
  echo "Usage: post.sh <OWNER> <REPO> <NUMBER> <HEAD_SHA> <EVENT>" >&2
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

build_payload() {
  local head_sha="$1"
  local event="$2"

  jq \
    --arg commit_id "$head_sha" \
    --arg event "$event" \
    '. + {commit_id: $commit_id, event: $event}
     | if (.comments // [] | length) > 0
       then .comments |= map(. + {side: "RIGHT"})
       else del(.comments)
       end'
}

post_review() {
  local owner="$1"
  local repo="$2"
  local number="$3"

  gh api "repos/${owner}/${repo}/pulls/${number}/reviews" \
    --method POST \
    --input - | jq -r '.html_url'
}

main() {
  local owner repo number head_sha event
  owner=${1:-}
  repo=${2:-}
  number=${3:-}
  head_sha=${4:-}
  event=${5:-}

  [[ -n "$owner" && -n "$repo" && -n "$number" && -n "$head_sha" && -n "$event" ]] || {
    usage
    exit 1
  }

  require_dependencies
  build_payload "$head_sha" "$event" | post_review "$owner" "$repo" "$number"
}

main "$@"
