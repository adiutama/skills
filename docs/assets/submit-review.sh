#!/usr/bin/env bash
# TEMPLATE ONLY — copy to skills/<skill-name>/scripts/submit-review.sh
#
# Submit a GitHub PR review.
# Usage: submit-review.sh <OWNER> <REPO> <NUMBER> <HEAD_SHA> <EVENT>
# Input:  JSON on stdin — { "body": "...", "comments": [{ "path", "line", "body" }] }
#         Omit "comments" (or pass []) for APPROVE with no inline findings.
# Output: Review html_url

if [[ "${BASH_SOURCE[0]}" == "${0}" ]] && [[ "${BASH_SOURCE[0]}" == *"docs/assets/submit-review.sh" ]]; then
  cat >&2 <<'EOF'
Error: docs/assets/submit-review.sh is a template only — not for runtime use.
Copy to skills/<skill-name>/scripts/submit-review.sh, then run that copy.
EOF
  exit 1
fi

set -euo pipefail

usage() {
  echo "Usage: submit-review.sh <OWNER> <REPO> <NUMBER> <HEAD_SHA> <EVENT>" >&2
}

require_gh_jq() {
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

submit_review() {
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

  require_gh_jq
  build_payload "$head_sha" "$event" | submit_review "$owner" "$repo" "$number"
}

main "$@"
