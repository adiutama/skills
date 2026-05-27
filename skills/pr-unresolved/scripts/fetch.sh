#!/usr/bin/env bash
# Fetch all data from a GitHub PR: review threads, reviews, and issue comments.
# Usage: fetch.sh <PR URL or number>
#   PR URL:    https://github.com/owner/repo/pull/123
#   PR number: 123  (must be run from inside the repo)
# Output: { "pr": { "title", "url" }, "threads": [...], "reviews": [...], "comments": [...] }

set -euo pipefail

require_dependencies() {
  command -v gh &>/dev/null || {
    echo "Error: gh is not installed. Install it from https://cli.github.com and run 'gh auth login'." >&2
    exit 1
  }
  command -v jq &>/dev/null || {
    echo "Error: jq is not installed. Install it from https://jqlang.org or via your package manager (e.g. brew install jq)." >&2
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

  echo "Error: expected a GitHub PR URL or PR number, got: $arg" >&2
  exit 1
}

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

  require_dependencies
  parse_pr_identity "$arg"

  fetch_review_threads
  fetch_reviews
  fetch_issue_comments
  print_output_json
}

main "$@"
