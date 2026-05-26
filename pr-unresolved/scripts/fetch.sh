#!/usr/bin/env bash
# Fetch all data from a GitHub PR: review threads, reviews, and issue comments.
# Usage: fetch.sh <PR URL or number>
#   PR URL:    https://github.com/owner/repo/pull/123
#   PR number: 123  (must be run from inside the repo)
# Output: { "pr": { "title", "url" }, "threads": [...], "reviews": [...], "comments": [...] }

set -euo pipefail

command -v gh  &>/dev/null || { echo "Error: gh is not installed. Install it from https://cli.github.com and run 'gh auth login'." >&2; exit 1; }
command -v jq  &>/dev/null || { echo "Error: jq is not installed. Install it from https://jqlang.org or via your package manager (e.g. brew install jq)." >&2; exit 1; }

ARG=${1:?"Usage: fetch.sh <PR URL or number>"}

if [[ "$ARG" =~ ^https://github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]}"
  NUMBER="${BASH_REMATCH[3]}"
elif [[ "$ARG" =~ ^[0-9]+$ ]]; then
  NAME_WITH_OWNER=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) \
    || { echo "Error: could not detect repo — run from inside a git repo or provide the full PR URL." >&2; exit 1; }
  OWNER="${NAME_WITH_OWNER%%/*}"
  REPO="${NAME_WITH_OWNER##*/}"
  NUMBER="$ARG"
else
  echo "Error: expected a GitHub PR URL or PR number, got: $ARG" >&2
  exit 1
fi

# --- Review threads (paginated) ---

threads='[]'
cursor=null
pr_title=''
pr_url=''

while true; do
  [ "$cursor" = "null" ] && after="" || after=", after: \"$cursor\""

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

  pr_title=$(echo "$response" | jq -r '.data.repository.pullRequest.title')
  pr_url=$(echo "$response"   | jq -r '.data.repository.pullRequest.url')

  page_threads=$(echo "$response" | jq '.data.repository.pullRequest.reviewThreads.nodes')
  threads=$(jq -n --argjson a "$threads" --argjson b "$page_threads" '$a + $b')

  has_next=$(echo "$response" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage')
  [ "$has_next" = "true" ] || break

  cursor=$(echo "$response" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor')
done

# --- Review-level comments ---

reviews=$(gh api graphql -f query="{
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

# --- General PR comments ---

comments=$(gh api "repos/$OWNER/$REPO/issues/$NUMBER/comments" --paginate | jq '.')

# --- Output ---

jq -n \
  --arg     title    "$pr_title" \
  --arg     url      "$pr_url" \
  --argjson threads  "$threads" \
  --argjson reviews  "$reviews" \
  --argjson comments "$comments" \
  '{ pr: { title: $title, url: $url }, threads: $threads, reviews: $reviews, comments: $comments }'
