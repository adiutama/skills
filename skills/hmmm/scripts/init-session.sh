#!/usr/bin/env bash
# Create a new hmmm session directory with artifact skeleton.
# Usage: init-session.sh [slug]
# Output: JSON { session_id, session_dir, owner, repo, branch_slug, created }

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SKILL_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=artifacts.sh
source "${SCRIPT_DIR}/artifacts.sh"

slug="${1:-}"
slug=$(printf '%s' "$slug" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' | cut -c1-32)

session_id() {
  local ts id
  ts=$(date -u +%Y%m%d-%H%M%S)
  if [[ -n "$slug" ]]; then
    id="${ts}-${slug}"
  else
    id="$ts"
  fi
  printf '%s' "$id"
}

artifact_git_owner_repo
BRANCH_SLUG=$(artifact_branch_slug)
SESSION_ID=$(session_id)
CREATED=$(date -u +%Y-%m-%dT%H:%M:%SZ)

BASE="$(artifact_skill_path "$OWNER" "$REPO" "$BRANCH_SLUG" "hmmm")/sessions"
SESSION_DIR="${BASE}/${SESSION_ID}"

if [[ -e "$SESSION_DIR" ]]; then
  echo "Error: session already exists: $SESSION_DIR" >&2
  exit 1
fi

mkdir -p "${SESSION_DIR}/discovery" "${SESSION_DIR}/reports"

cat >"${SESSION_DIR}/meta.md" <<EOF
---
session: ${SESSION_ID}
created: ${CREATED}
status: active
phase: frame
mode: rapid
problem: ""
---

Session created; parent fills problem before discovery.
EOF

if [[ -f "${SKILL_DIR}/references/master-template.md" ]]; then
  sed "s/{session_id}/${SESSION_ID}/g" "${SKILL_DIR}/references/master-template.md" >"${SESSION_DIR}/master.md"
else
  echo "# Master (parent-owned — child must not edit)" >"${SESSION_DIR}/master.md"
fi

if [[ -f "${SKILL_DIR}/references/brief-template.md" ]]; then
  cp "${SKILL_DIR}/references/brief-template.md" "${SESSION_DIR}/brief.md"
else
  touch "${SESSION_DIR}/brief.md"
fi

touch "${SESSION_DIR}/options.md" "${SESSION_DIR}/decisions.md"

jq -n \
  --arg session_id "$SESSION_ID" \
  --arg session_dir "$SESSION_DIR" \
  --arg owner "$OWNER" \
  --arg repo "$REPO" \
  --arg branch_slug "$BRANCH_SLUG" \
  --arg created "$CREATED" \
  '{session_id: $session_id, session_dir: $session_dir, owner: $owner, repo: $repo, branch_slug: $branch_slug, created: $created}'
