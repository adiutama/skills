#!/usr/bin/env bash
# Post a GitHub PR review.
# Usage: post.sh <OWNER> <REPO> <NUMBER> <HEAD_SHA> <EVENT>
# Input:  JSON on stdin — { "body": "...", "comments": [{ "path", "line", "body" }] }
#         Omit "comments" (or pass []) for APPROVE with no inline findings.
# Output: Review html_url

set -euo pipefail

command -v gh  &>/dev/null || { echo "Error: gh CLI not installed. See https://cli.github.com" >&2; exit 1; }
command -v jq  &>/dev/null || { echo "Error: jq not installed. Run: brew install jq" >&2; exit 1; }

OWNER=${1:?"Usage: post.sh <OWNER> <REPO> <NUMBER> <HEAD_SHA> <EVENT>"}
REPO=${2:?"Usage: post.sh <OWNER> <REPO> <NUMBER> <HEAD_SHA> <EVENT>"}
NUMBER=${3:?"Usage: post.sh <OWNER> <REPO> <NUMBER> <HEAD_SHA> <EVENT>"}
HEAD_SHA=${4:?"Usage: post.sh <OWNER> <REPO> <NUMBER> <HEAD_SHA> <EVENT>"}
EVENT=${5:?"Usage: post.sh <OWNER> <REPO> <NUMBER> <HEAD_SHA> <EVENT>"}

INPUT=$(cat)

PAYLOAD=$(printf '%s' "$INPUT" | jq \
  --arg commit_id "$HEAD_SHA" \
  --arg event     "$EVENT" \
  '. + {commit_id: $commit_id, event: $event}
   | if (.comments // [] | length) > 0
     then .comments |= map(. + {side: "RIGHT"})
     else del(.comments)
     end')

printf '%s' "$PAYLOAD" | gh api "repos/${OWNER}/${REPO}/pulls/${NUMBER}/reviews" \
  --method POST \
  --input - | jq -r '.html_url'
