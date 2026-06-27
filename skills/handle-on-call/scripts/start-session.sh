#!/usr/bin/env bash
# Start an on-call incident session from pasted Slack text.
# Usage: start-session.sh [alert text...]  (or stdin; may include Slack permalink)
# Output JSON: session paths + slack fields + has_thread (true|false)

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SKILL_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
source "${SCRIPT_DIR}/lib/artifact-root.sh"

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

incident_slug() {
  date -u +%Y%m%d-%H%M%S
}

read_alert_input() {
  if [[ $# -gt 0 ]]; then
    printf '%s' "$*"
  else
    cat
  fi
}

init_tracker() {
  if [[ -f "$TRACKER_PATH" ]]; then
    return
  fi
  if [[ -f "${SKILL_DIR}/references/tracker-template.md" ]]; then
    sed "s/{incident_id}/${INCIDENT_ID}/g" "${SKILL_DIR}/references/tracker-template.md" >"$TRACKER_PATH"
  else
    cat >"$TRACKER_PATH" <<'EOF'
# On-call tracker

## Status

pending

## Timeline

| Step | Status | Notes |
|------|--------|-------|
EOF
  fi
}

write_meta() {
  local now="$1"
  cat >"$META_PATH" <<EOF
---
incident: ${INCIDENT_ID}
created: ${CREATED}
updated: ${now}
slack_url: "${SLACK_URL//\"/\\\"}"
channel: ${CHANNEL}
thread_ts: ${THREAD_TS}
has_thread: ${HAS_THREAD}
status: pending
---
EOF
}

main() {
  command -v jq &>/dev/null || { echo "Error: jq not installed." >&2; exit 1; }

  local raw parsed message_text
  raw=$(read_alert_input "$@")
  [[ -n "$raw" ]] || { echo "Error: paste the Slack alert message or permalink." >&2; exit 1; }

  parsed=$(bash "${SCRIPT_DIR}/parse-slack.sh" <<<"$raw")
  SLACK_URL=$(jq -r '.slack_url' <<<"$parsed")
  CHANNEL=$(jq -r '.channel' <<<"$parsed")
  THREAD_TS=$(jq -r '.thread_ts' <<<"$parsed")
  message_text=$(jq -r '.message_text' <<<"$parsed")

  resolve_owner_repo
  SLUG=$(branch_slug)
  INCIDENT_ID=$(incident_slug)
  BASE=$(artifact_skill_path "$OWNER" "$REPO" "$SLUG" "handle-on-call")
  SESSION_DIR="${BASE}/incident-${INCIDENT_ID}"
  mkdir -p "$SESSION_DIR"

  META_PATH="${SESSION_DIR}/meta.md"
  ALERT_PATH="${SESSION_DIR}/alert.txt"
  TRACKER_PATH="${SESSION_DIR}/tracker.md"
  REPORT_PATH="${SESSION_DIR}/report.md"

  printf '%s\n' "$raw" >"$ALERT_PATH"
  CREATED=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  if [[ -n "$CHANNEL" && -n "$THREAD_TS" ]]; then
    HAS_THREAD="true"
  else
    HAS_THREAD="false"
    CHANNEL=""
    THREAD_TS=""
  fi

  write_meta "$CREATED"
  init_tracker
  touch "$REPORT_PATH"

  jq -n \
    --arg owner "$OWNER" \
    --arg repo "$REPO" \
    --arg incident_id "$INCIDENT_ID" \
    --arg session_dir "$SESSION_DIR" \
    --arg meta_path "$META_PATH" \
    --arg alert_path "$ALERT_PATH" \
    --arg tracker_path "$TRACKER_PATH" \
    --arg report_path "$REPORT_PATH" \
    --arg slack_url "$SLACK_URL" \
    --arg channel "$CHANNEL" \
    --arg thread_ts "$THREAD_TS" \
    --arg has_thread "$HAS_THREAD" \
    --arg message_text "$message_text" \
    '{
      owner: $owner,
      repo: $repo,
      incident_id: $incident_id,
      session_dir: $session_dir,
      meta_path: $meta_path,
      alert_path: $alert_path,
      tracker_path: $tracker_path,
      report_path: $report_path,
      slack_url: $slack_url,
      channel: $channel,
      thread_ts: $thread_ts,
      has_thread: ($has_thread == "true"),
      message_text: $message_text
    }'
}

main "$@"
