#!/usr/bin/env bash
# Fetch all data from a GitHub PR: review threads, reviews, and issue comments.
# Usage: fetch.sh <PR URL or number>
#   PR URL:    https://github.com/owner/repo/pull/123
#   PR number: 123  (must be run from inside the repo)
# Output: { "pr": { "title", "url" }, "threads": [...], "reviews": [...], "comments": [...] }

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=pr-identity.sh
source "${SCRIPT_DIR}/pr-identity.sh"

fetch_review_threads() {
  local threads cursor after response page_threads has_next
  threads='[]'
  cursor=null
  PR_TITLE=''
  PR_URL=''

  while true; do
    [[ "$cursor" == "null" ]] && after="" || after=", after: \"$cursor\""

    response=$(gh api graphql -f query="{
      repository(owner: \"$OWNER\", name: \"$REPO\") {
        pullRequest(number: $NUMBER) {
          title
          url
          reviewThreads(first: 100$after) {
            pageInfo { hasNextPage endCursor }
            nodes {
              isResolved
              isOutdated
              path
              line
              comments(first: 50) {
                nodes {
                  databaseId
                  author { login }
                  body
                  url
                  createdAt
                }
              }
            }
          }
        }
      }
    }")

    PR_TITLE=$(printf '%s' "$response" | jq -r '.data.repository.pullRequest.title')
    PR_URL=$(printf '%s' "$response" | jq -r '.data.repository.pullRequest.url')

    page_threads=$(printf '%s' "$response" | jq '.data.repository.pullRequest.reviewThreads.nodes')
    threads=$(jq -n --argjson a "$threads" --argjson b "$page_threads" '$a + $b')

    has_next=$(printf '%s' "$response" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage')
    [[ "$has_next" == "true" ]] || break

    cursor=$(printf '%s' "$response" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor')
  done

  THREADS="$threads"
}

fetch_reviews() {
  REVIEWS=$(gh api graphql -f query="{
    repository(owner: \"$OWNER\", name: \"$REPO\") {
      pullRequest(number: $NUMBER) {
        reviews(first: 100) {
          nodes {
            author { login }
            body
            state
            submittedAt
            url
          }
        }
      }
    }
  }" | jq '[.data.repository.pullRequest.reviews.nodes[] | select(.body != "")]')
}

fetch_issue_comments() {
  COMMENTS=$(gh api "repos/$OWNER/$REPO/issues/$NUMBER/comments" --paginate | jq '.')
}

print_output_json() {
  jq -n \
    --arg title "$PR_TITLE" \
    --arg url "$PR_URL" \
    --argjson threads "$THREADS" \
    --argjson reviews "$REVIEWS" \
    --argjson comments "$COMMENTS" \
    '{ pr: { title: $title, url: $url }, threads: $threads, reviews: $reviews, comments: $comments }'
}

main() {
  local arg
  arg=${1:?"Usage: fetch.sh <PR URL or number>"}

  require_gh_jq
  parse_pr_identity "$arg"

  fetch_review_threads
  fetch_reviews
  fetch_issue_comments
  print_output_json
}

main "$@"
