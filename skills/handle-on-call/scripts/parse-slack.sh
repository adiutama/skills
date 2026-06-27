#!/usr/bin/env bash
# Parse pasted Slack alert text for permalink and message body.
# Usage: parse-slack.sh [text...]  (or stdin)
# Output JSON: { slack_url, channel, thread_ts, message_text }

set -euo pipefail

require_jq() {
  command -v jq &>/dev/null || {
    echo "Error: jq is not installed." >&2
    exit 1
  }
}

read_input() {
  if [[ $# -gt 0 ]]; then
    printf '%s' "$*"
  else
    cat
  fi
}

extract_slack_url() {
  local text="$1"
  grep -Eo 'https://[^[:space:]]+\.slack\.com/archives/[A-Z0-9]+/p[0-9]+' <<<"$text" | head -1 || true
}

parse_permalink() {
  local url="$1"
  local channel="" thread_ts=""

  if [[ "$url" =~ /archives/([A-Z0-9]+)/p([0-9]+) ]]; then
    channel="${BASH_REMATCH[1]}"
    local raw="${BASH_REMATCH[2]}"
    local len=${#raw}
    if ((len > 6)); then
      thread_ts="${raw:0:len-6}.${raw:len-6:6}"
    fi
  fi

  jq -n \
    --arg slack_url "$url" \
    --arg channel "$channel" \
    --arg thread_ts "$thread_ts" \
    '{slack_url: $slack_url, channel: $channel, thread_ts: $thread_ts}'
}

strip_url_from_text() {
  local text="$1"
  local url="$2"
  if [[ -z "$url" ]]; then
    printf '%s' "$text"
    return
  fi
  printf '%s' "$text" | sed "s|$url||g" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

main() {
  require_jq
  local raw trimmed url parsed channel thread_ts message_text

  raw=$(read_input "$@")
  trimmed=$(printf '%s' "$raw" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
  url=$(extract_slack_url "$trimmed")
  parsed=$(parse_permalink "${url:-}")
  channel=$(jq -r '.channel' <<<"$parsed")
  thread_ts=$(jq -r '.thread_ts' <<<"$parsed")
  message_text=$(strip_url_from_text "$trimmed" "$url")

  jq -n \
    --arg slack_url "${url:-}" \
    --arg channel "$channel" \
    --arg thread_ts "$thread_ts" \
    --arg message_text "$message_text" \
    '{
      slack_url: $slack_url,
      channel: $channel,
      thread_ts: $thread_ts,
      message_text: $message_text
    }'
}

main "$@"
