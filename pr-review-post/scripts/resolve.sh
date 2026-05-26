#!/usr/bin/env bash
# Resolve PR identity and locate the latest review session file.
# Usage: resolve.sh <PR URL or number>
# Output: JSON { owner, repo, number, head_sha, branch, session_path }
#   session_path — highest-numbered NN.md under reviews/<owner>/<repo>/<slug>/
#                  or empty string if no session file exists yet.

set -euo pipefail

command -v gh  &>/dev/null || { echo "Error: gh CLI not installed. See https://cli.github.com" >&2; exit 1; }
command -v jq  &>/dev/null || { echo "Error: jq not installed. Run: brew install jq" >&2; exit 1; }

ARG=${1:?"Usage: resolve.sh <PR URL or number>"}

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

META=$(gh pr view "$NUMBER" --repo "$OWNER/$REPO" --json headRefName,headRefOid)
BRANCH=$(printf '%s' "$META" | jq -r .headRefName)
HEAD_SHA=$(printf '%s' "$META" | jq -r .headRefOid)

SLUG=$(printf '%s' "$BRANCH" | tr -cs 'a-zA-Z0-9' '-' | sed 's/^-//;s/-$//')
DIR="reviews/${OWNER}/${REPO}/${SLUG}"

SESSION_PATH=""
if [[ -d "$DIR" ]]; then
  LATEST=$(ls "$DIR"/*.md 2>/dev/null | sort -V | tail -1 || true)
  [[ -n "$LATEST" ]] && SESSION_PATH="$LATEST"
fi

jq -n \
  --arg owner        "$OWNER" \
  --arg repo         "$REPO" \
  --arg number       "$NUMBER" \
  --arg head_sha     "$HEAD_SHA" \
  --arg branch       "$BRANCH" \
  --arg session_path "$SESSION_PATH" \
  '{owner:$owner, repo:$repo, number:$number, head_sha:$head_sha, branch:$branch, session_path:$session_path}'
