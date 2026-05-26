#!/usr/bin/env bash
# Initialize a PR review session: fetch PR metadata, diff, and existing comments in parallel.
# Usage: init.sh <PR URL or number>
# Output: JSON { owner, repo, number, title, branch, head_sha, base, body, diff_file, comments_file, session_path, pass }
# diff_file and comments_file are temp files; read them then remove them.

set -euo pipefail

command -v gh &>/dev/null || { echo "Error: gh CLI not installed. See https://cli.github.com" >&2; exit 1; }
command -v jq &>/dev/null || { echo "Error: jq not installed. Run: brew install jq" >&2; exit 1; }

ARG=${1:?"Usage: init.sh <PR URL or number>"}

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
  echo "Error: expected a GitHub PR URL or number, got: $ARG" >&2
  exit 1
fi

META_FILE=$(mktemp /tmp/pr-meta.XXXXXX)
DIFF_FILE=$(mktemp /tmp/pr-diff.XXXXXX)
COMMENTS_FILE=$(mktemp /tmp/pr-comments.XXXXXX)

gh pr view "$NUMBER" --repo "$OWNER/$REPO" \
  --json title,headRefName,headRefOid,baseRefName,body > "$META_FILE" &
gh pr diff "$NUMBER" --repo "$OWNER/$REPO" > "$DIFF_FILE" &
{
  inline=$(gh api "repos/${OWNER}/${REPO}/pulls/${NUMBER}/comments" \
    --jq '[.[] | {path:.path, line:(.line//.original_line), body:.body}]' 2>/dev/null \
    || echo '[]')
  reviews=$(gh api "repos/${OWNER}/${REPO}/pulls/${NUMBER}/reviews" \
    --jq '[.[] | select(.body!="") | {body:.body}]' 2>/dev/null \
    || echo '[]')
  jq -n --argjson i "$inline" --argjson r "$reviews" '{inline:$i,reviews:$r}' > "$COMMENTS_FILE"
} &
wait

META=$(cat "$META_FILE")
rm -f "$META_FILE"

BRANCH=$(printf '%s' "$META" | jq -r .headRefName)
SLUG=$(printf '%s' "$BRANCH" | tr -cs 'a-zA-Z0-9' '-' | sed 's/^-//;s/-$//')
DIR="reviews/${OWNER}/${REPO}/${SLUG}"
mkdir -p "$DIR"

N=1
while [[ -f "$DIR/$(printf '%02d' "$N").md" ]]; do ((N++)); done
SESSION_PATH="$DIR/$(printf '%02d' "$N").md"
PASS=$(printf '%02d' "$N")

jq -n \
  --arg owner          "$OWNER" \
  --arg repo           "$REPO" \
  --arg number         "$NUMBER" \
  --arg diff_file      "$DIFF_FILE" \
  --arg comments_file  "$COMMENTS_FILE" \
  --arg session_path   "$SESSION_PATH" \
  --arg pass           "$PASS" \
  --argjson meta       "$META" \
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
