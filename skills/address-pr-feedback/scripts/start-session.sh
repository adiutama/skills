#!/usr/bin/env bash
# Start or refresh a PR feedback session: fetch, filter, save artifacts.
# Usage: start-session.sh <PR URL or number> [--new-round]
# Output: JSON {
#   owner, repo, number, title, url, branch, head_sha,
#   session_dir, findings_path, meta_path, tracker_path, report_path,
#   thread_count, review_count, comment_count, total_count
# }
# --new-round  force a new numbered round dir instead of reusing pr-<N> session

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SKILL_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

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

branch_slug() {
  local branch="$1"
  printf '%s' "$branch" | sed -E 's/[^a-zA-Z0-9]+/-/g; s/^-+|-+$//g'
}

fetch_pr_meta() {
  PR_META=$(gh pr view "$NUMBER" --repo "$OWNER/$REPO" \
    --json title,url,headRefName,headRefOid)
  PR_TITLE=$(jq -r '.title' <<<"$PR_META")
  PR_URL=$(jq -r '.url' <<<"$PR_META")
  PR_BRANCH=$(jq -r '.headRefName' <<<"$PR_META")
  HEAD_SHA=$(jq -r '.headRefOid' <<<"$PR_META")
}

write_meta() {
  local now="$1"
  cat >"$META_PATH" <<EOF
---
pr: ${NUMBER}
owner: ${OWNER}
repo: ${REPO}
title: "${PR_TITLE//\"/\\\"}"
url: ${PR_URL}
branch: ${PR_BRANCH}
head_sha: ${HEAD_SHA}
created: ${CREATED}
updated: ${now}
---
EOF
}

init_tracker() {
  if [[ -f "$TRACKER_PATH" ]]; then
    return
  fi
  if [[ -f "${SKILL_DIR}/references/tracker-template.md" ]]; then
    sed "s/{pr_number}/${NUMBER}/g" "${SKILL_DIR}/references/tracker-template.md" >"$TRACKER_PATH"
  else
    cat >"$TRACKER_PATH" <<EOF
# Feedback tracker — PR #${NUMBER}

## Selected this workflow
<!-- IDs user chose to address, e.g. C1, W1, W2 -->

## Progress

| ID | Status | Notes |
|----|--------|-------|

## Rounds

| Round | Selected | Addressed | Remaining |
|-------|----------|-----------|-----------|
EOF
  fi
}

main() {
  local arg="${1:?"Usage: start-session.sh <PR URL or number>"}"

  require_dependencies
  parse_pr_identity "$arg"
  fetch_pr_meta

  SLUG=$(branch_slug "$PR_BRANCH")
  BASE="${HOME}/.agents/artifacts/${OWNER}/${REPO}/${SLUG}/address-pr-feedback"
  SESSION_DIR="${BASE}/pr-${NUMBER}"
  mkdir -p "$SESSION_DIR"

  META_PATH="${SESSION_DIR}/meta.md"
  FINDINGS_PATH="${SESSION_DIR}/findings.json"
  TRACKER_PATH="${SESSION_DIR}/tracker.md"
  REPORT_PATH="${SESSION_DIR}/report.md"

  CREATED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  if [[ -f "$META_PATH" ]]; then
    CREATED=$(awk -F': ' '/^created:/{print $2; exit}' "$META_PATH" 2>/dev/null || echo "$CREATED")
  fi

  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  bash "${SKILL_DIR}/scripts/fetch.sh" "$arg" \
    | bash "${SKILL_DIR}/scripts/filter.sh" >"$FINDINGS_PATH"

  write_meta "$NOW"
  init_tracker
  touch "$REPORT_PATH"

  THREAD_COUNT=$(jq '.threads | length' "$FINDINGS_PATH")
  REVIEW_COUNT=$(jq '.reviews | length' "$FINDINGS_PATH")
  COMMENT_COUNT=$(jq '.comments | length' "$FINDINGS_PATH")
  TOTAL=$((THREAD_COUNT + REVIEW_COUNT + COMMENT_COUNT))

  jq -n \
    --arg owner "$OWNER" \
    --arg repo "$REPO" \
    --arg number "$NUMBER" \
    --arg title "$PR_TITLE" \
    --arg url "$PR_URL" \
    --arg branch "$PR_BRANCH" \
    --arg head_sha "$HEAD_SHA" \
    --arg session_dir "$SESSION_DIR" \
    --arg findings_path "$FINDINGS_PATH" \
    --arg meta_path "$META_PATH" \
    --arg tracker_path "$TRACKER_PATH" \
    --arg report_path "$REPORT_PATH" \
    --argjson thread_count "$THREAD_COUNT" \
    --argjson review_count "$REVIEW_COUNT" \
    --argjson comment_count "$COMMENT_COUNT" \
    --argjson total_count "$TOTAL" \
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

main "$@"
