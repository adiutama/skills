#!/usr/bin/env bash
# Create a new iterate-task session directory with artifact skeleton.
# Usage: init-session.sh [slug]
# Output: JSON { session_id, session_dir, owner, repo, branch_slug, created }

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SKILL_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

slug="${1:-}"
slug=$(printf '%s' "$slug" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' | cut -c1-32)

resolve_owner_repo() {
  local url
  url=$(git remote get-url origin 2>/dev/null || true)
  if [[ -z "$url" ]]; then
    OWNER="_local"
    REPO="_local"
    return
  fi
  if [[ "$url" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]%.git}"
    return
  fi
  OWNER="_local"
  REPO="_local"
}

branch_slug() {
  local branch sha
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)
  if [[ "$branch" == "HEAD" ]]; then
    sha=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
    printf 'detached-%s' "$sha"
    return
  fi
  printf '%s' "$branch" | sed -E 's/[^a-zA-Z0-9]+/-/g; s/^-+|-+$//g'
}

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

resolve_owner_repo
BRANCH_SLUG=$(branch_slug)
SESSION_ID=$(session_id)
CREATED=$(date -u +%Y-%m-%dT%H:%M:%SZ)

BASE="${HOME}/.agents/artifacts/${OWNER}/${REPO}/${BRANCH_SLUG}/iterate-task/sessions"
SESSION_DIR="${BASE}/${SESSION_ID}"

if [[ -e "$SESSION_DIR" ]]; then
  echo "Error: session already exists: $SESSION_DIR" >&2
  exit 1
fi

mkdir -p "${SESSION_DIR}/reports"

cat >"${SESSION_DIR}/meta.md" <<EOF
---
session: ${SESSION_ID}
created: ${CREATED}
status: active
goal: ""
exit: ""
max: 10
---

Session created; parent fills goal and exit before first iteration.
EOF

if [[ -f "${SKILL_DIR}/references/master-template.md" ]]; then
  sed "s/{session_id}/${SESSION_ID}/g" "${SKILL_DIR}/references/master-template.md" >"${SESSION_DIR}/master.md"
else
  echo "# Master (parent-owned — child must not edit)" >"${SESSION_DIR}/master.md"
fi

if [[ -f "${SKILL_DIR}/references/handoff-template.md" ]]; then
  cp "${SKILL_DIR}/references/handoff-template.md" "${SESSION_DIR}/handoff.md"
else
  echo "# Handoff — iteration pending" >"${SESSION_DIR}/handoff.md"
fi

touch "${SESSION_DIR}/report.md"

jq -n \
  --arg session_id "$SESSION_ID" \
  --arg session_dir "$SESSION_DIR" \
  --arg owner "$OWNER" \
  --arg repo "$REPO" \
  --arg branch_slug "$BRANCH_SLUG" \
  --arg created "$CREATED" \
  '{session_id: $session_id, session_dir: $session_dir, owner: $owner, repo: $repo, branch_slug: $branch_slug, created: $created}'
