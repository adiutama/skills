#!/usr/bin/env bash
# Resolve PR identity and locate the latest review session file.
# Usage: resolve-session.sh <PR URL or number>
# Output: JSON { owner, repo, number, head_sha, branch, session_path }
#   session_path — highest-numbered NN.md under review-pr/ or submit-pr-review/, or empty if none exist.

SESSION_SOURCE_SKILL="submit-pr-review"

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=artifacts.sh
source "${SCRIPT_DIR}/artifacts.sh"
# shellcheck source=pr-identity.sh
source "${SCRIPT_DIR}/pr-identity.sh"

print_resolve_json() {
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

resolve_pr_session() {
  local arg="$1"
  local meta branch head_sha slug session_path

  require_gh_jq
  parse_pr_identity "$arg"

  meta=$(gh pr view "$NUMBER" --repo "$OWNER/$REPO" --json headRefName,headRefOid)
  branch=$(printf '%s' "$meta" | jq -r .headRefName)
  head_sha=$(printf '%s' "$meta" | jq -r .headRefOid)

  slug=$(artifact_branch_slug "$branch")
  session_path=$(artifact_latest_numbered_markdown "$OWNER" "$REPO" "$slug" "review-pr")
  if [[ -z "$session_path" ]]; then
    session_path=$(artifact_latest_numbered_markdown "$OWNER" "$REPO" "$slug" "$SESSION_SOURCE_SKILL")
  fi

  print_resolve_json "$head_sha" "$branch" "$session_path"
}

main() {
  resolve_pr_session "${1:?"Usage: resolve-session.sh <PR URL or number>"}"
}

main "$@"
