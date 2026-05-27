#!/usr/bin/env bash
# Initialize a PR review session: fetch PR metadata, diff, and existing comments in parallel.
# Usage: start-session.sh <PR URL or number>
# Output: JSON { owner, repo, number, title, branch, head_sha, base, body, diff_file, comments_file, session_path, pass }
# diff_file and comments_file are temp files; read them then remove them.

set -euo pipefail

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

fetch_artifacts() {
  local meta_file="$1"
  local diff_file="$2"
  local comments_file="$3"

  gh pr view "$NUMBER" --repo "$OWNER/$REPO" \
    --json title,headRefName,headRefOid,baseRefName,body > "$meta_file" &
  gh pr diff "$NUMBER" --repo "$OWNER/$REPO" > "$diff_file" &
  {
    local inline_comments
    local review_comments
    inline_comments=$(gh api "repos/${OWNER}/${REPO}/pulls/${NUMBER}/comments" \
      --jq '[.[] | {path:.path, line:(.line//.original_line), body:.body}]' 2>/dev/null \
      || echo '[]')
    review_comments=$(gh api "repos/${OWNER}/${REPO}/pulls/${NUMBER}/reviews" \
      --jq '[.[] | select(.body!="") | {body:.body}]' 2>/dev/null \
      || echo '[]')
    jq -n --argjson i "$inline_comments" --argjson r "$review_comments" '{inline:$i,reviews:$r}' > "$comments_file"
  } &
  wait
}

allocate_session_path() {
  local branch="$1"
  local slug dir n

  slug=$(printf '%s' "$branch" | tr -cs 'a-zA-Z0-9' '-' | sed 's/^-//;s/-$//')
  dir="reviews/${OWNER}/${REPO}/${slug}"
  mkdir -p "$dir"

  n=1
  while [[ -f "$dir/$(printf '%02d' "$n").md" ]]; do ((n++)); done

  SESSION_PATH="$dir/$(printf '%02d' "$n").md"
  PASS=$(printf '%02d' "$n")
}

print_output_json() {
  local meta="$1"
  local diff_file="$2"
  local comments_file="$3"

  jq -n \
    --arg owner          "$OWNER" \
    --arg repo           "$REPO" \
    --arg number         "$NUMBER" \
    --arg diff_file      "$diff_file" \
    --arg comments_file  "$comments_file" \
    --arg session_path   "$SESSION_PATH" \
    --arg pass           "$PASS" \
    --argjson meta       "$meta" \
    '{
      owner:         $owner,
      repo:          $repo,
      number:        $number,
      title:         $meta.title,
      branch:        $meta.headRefName,
      head_sha:      $meta.headRefOid,
      base:          $meta.baseRefName,
      body:          $meta.body,
      diff_file:     $diff_file,
      comments_file: $comments_file,
      session_path:  $session_path,
      pass:          $pass
    }'
}

main() {
  local arg meta_file diff_file comments_file meta branch
  arg=${1:?"Usage: start-session.sh <PR URL or number>"}

  require_dependencies
  parse_pr_identity "$arg"

  meta_file=$(mktemp /tmp/pr-meta.XXXXXX)
  diff_file=$(mktemp /tmp/pr-diff.XXXXXX)
  comments_file=$(mktemp /tmp/pr-comments.XXXXXX)

  fetch_artifacts "$meta_file" "$diff_file" "$comments_file"

  meta=$(<"$meta_file")
  rm -f "$meta_file"

  branch=$(printf '%s' "$meta" | jq -r .headRefName)
  allocate_session_path "$branch"

  print_output_json "$meta" "$diff_file" "$comments_file"
}

main "$@"
