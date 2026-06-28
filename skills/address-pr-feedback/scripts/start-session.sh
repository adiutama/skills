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
# shellcheck source=artifacts.sh
source "${SCRIPT_DIR}/artifacts.sh"
# shellcheck source=pr-identity.sh
source "${SCRIPT_DIR}/pr-identity.sh"

require_dependencies() {
  require_gh_jq
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

  SLUG=$(artifact_branch_slug "$PR_BRANCH")
  BASE=$(artifact_skill_path "$OWNER" "$REPO" "$SLUG" "address-pr-feedback")
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
