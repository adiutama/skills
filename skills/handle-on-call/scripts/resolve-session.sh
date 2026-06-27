#!/usr/bin/env bash
# Locate an existing on-call session.
# Usage: resolve-session.sh [incident-id]
#   With no arg: newest incident-* session under current branch slug.
# Output: same JSON shape as start-session.sh, or { session_dir: null }

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
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

read_meta_field() {
  local file="$1" key="$2"
  awk -v k="$key" '
    /^---$/ { in_fm=(in_fm?0:1); next }
    in_fm && $1 == k ":" {
      sub(/^[^:]*:[[:space:]]*/, "")
      gsub(/^"/, ""); gsub(/"$/, "")
      print
      exit
    }
  ' "$file" 2>/dev/null || true
}

emit_session_json() {
  local session_dir="$1"
  local meta_path="${session_dir}/meta.md"
  local alert_path="${session_dir}/alert.txt"

  local incident_id slack_url channel thread_ts has_thread status message_text
  incident_id=$(read_meta_field "$meta_path" incident)
  slack_url=$(read_meta_field "$meta_path" slack_url)
  channel=$(read_meta_field "$meta_path" channel)
  thread_ts=$(read_meta_field "$meta_path" thread_ts)
  has_thread=$(read_meta_field "$meta_path" has_thread)
  status=$(read_meta_field "$meta_path" status)

  message_text=""
  if [[ -f "$alert_path" ]]; then
    message_text=$(bash "${SCRIPT_DIR}/parse-slack.sh" <"$alert_path" | jq -r '.message_text')
  fi

  jq -n \
    --arg owner "$OWNER" \
    --arg repo "$REPO" \
    --arg incident_id "$incident_id" \
    --arg session_dir "$session_dir" \
    --arg meta_path "$meta_path" \
    --arg alert_path "$alert_path" \
    --arg tracker_path "${session_dir}/tracker.md" \
    --arg report_path "${session_dir}/report.md" \
    --arg slack_url "$slack_url" \
    --arg channel "$channel" \
    --arg thread_ts "$thread_ts" \
    --arg has_thread "$has_thread" \
    --arg status "$status" \
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
      status: $status,
      message_text: $message_text
    }'
}

main() {
  local arg="${1:-}"
  command -v jq &>/dev/null || { echo "Error: jq not installed." >&2; exit 1; }

  resolve_owner_repo
  SLUG=$(branch_slug)

  local session_dir="" root base candidate
  if [[ -n "$arg" ]]; then
    local id="${arg#incident-}"
    while IFS= read -r root; do
      [[ -n "$root" ]] || continue
      for candidate in \
        "${root}/${OWNER}/${REPO}/${SLUG}/handle-on-call/incident-${id}" \
        "${root}/${OWNER}/${REPO}/${SLUG}/handle-on-call/${arg}"; do
        if [[ -d "$candidate" ]]; then
          session_dir="$candidate"
          break 2
        fi
      done
    done < <(artifact_search_roots)
  else
    while IFS= read -r root; do
      [[ -n "$root" ]] || continue
      base="${root}/${OWNER}/${REPO}/${SLUG}/handle-on-call"
      [[ -d "$base" ]] || continue
      candidate=$(find "$base" -mindepth 1 -maxdepth 1 -type d -name 'incident-*' 2>/dev/null | sort -r | head -1)
      if [[ -n "$candidate" ]]; then
        session_dir="$candidate"
        break
      fi
    done < <(artifact_search_roots)
  fi

  if [[ -z "$session_dir" || ! -f "${session_dir}/meta.md" ]]; then
    jq -n '{session_dir: null}'
    exit 0
  fi

  emit_session_json "$session_dir"
}

main "$@"
