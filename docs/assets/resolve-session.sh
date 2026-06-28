#!/usr/bin/env bash
# TEMPLATE ONLY — copy to skills/<skill-name>/scripts/resolve-session.sh
#
# Set SESSION_SOURCE_SKILL when copying (artifact namespace whose NN.md session to find):
#   submit-pr-review → submit-pr-review (also checks review-pr in the skill copy)
#
# Usage: resolve-session.sh <PR URL or number>
# Output: JSON { owner, repo, number, head_sha, branch, session_path }

if [[ "${BASH_SOURCE[0]}" == "${0}" ]] && [[ "${BASH_SOURCE[0]}" == *"docs/assets/resolve-session.sh" ]]; then
  cat >&2 <<'EOF'
Error: docs/assets/resolve-session.sh is a template only — not for runtime use.
Copy to skills/<skill-name>/scripts/resolve-session.sh and set SESSION_SOURCE_SKILL.
EOF
  exit 1
fi

SESSION_SOURCE_SKILL="${SESSION_SOURCE_SKILL:-CHANGE_ME}"

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

  if [[ "$SESSION_SOURCE_SKILL" == "CHANGE_ME" ]]; then
    echo "Error: SESSION_SOURCE_SKILL must be set in resolve-session.sh" >&2
    exit 1
  fi

  require_gh_jq
  parse_pr_identity "$arg"

  meta=$(gh pr view "$NUMBER" --repo "$OWNER/$REPO" --json headRefName,headRefOid)
  branch=$(printf '%s' "$meta" | jq -r .headRefName)
  head_sha=$(printf '%s' "$meta" | jq -r .headRefOid)

  slug=$(artifact_branch_slug "$branch")
  session_path=$(artifact_latest_numbered_markdown "$OWNER" "$REPO" "$slug" "$SESSION_SOURCE_SKILL")

  print_resolve_json "$head_sha" "$branch" "$session_path"
}

main() {
  resolve_pr_session "${1:?"Usage: resolve-session.sh <PR URL or number>"}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
