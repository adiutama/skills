#!/bin/bash
# Context zone check for the orchestration skill. Pure script: no model involved.
#   context-zone.sh hook                 Claude Code hook (PostToolUse / UserPromptSubmit), reads hook JSON on stdin.
#                                        Silent in green; injects one line when the zone changes, re-reminds in red.
#   context-zone.sh status <transcript>  Prints "🟢 62K" for the status line.
#   context-zone.sh tokens <transcript>  Prints the raw token count.
# Thresholds: 150K / 250K by default; CTX_WINDOW under 300K switches to 50 % / 80 % of it.
# CTX_GREEN_MAX / CTX_YELLOW_MAX override either.
if [ -n "$CTX_WINDOW" ] && [ "$CTX_WINDOW" -lt 300000 ]; then
  DEF_GREEN=$((CTX_WINDOW / 2)); DEF_YELLOW=$((CTX_WINDOW * 4 / 5))
else
  DEF_GREEN=150000; DEF_YELLOW=250000
fi
GREEN_MAX=${CTX_GREEN_MAX:-$DEF_GREEN}
YELLOW_MAX=${CTX_YELLOW_MAX:-$DEF_YELLOW}
RED_REMIND=${CTX_RED_REMIND:-15}   # checks between red reminders

tokens() {
  tail -n 500 "$1" 2>/dev/null |
    jq -R 'fromjson? | select(.isSidechain != true and .message.usage != null) | .message.usage' 2>/dev/null |
    jq -rs 'last // empty | (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)' 2>/dev/null
}

zone() {
  if [ "$1" -lt "$GREEN_MAX" ]; then echo green
  elif [ "$1" -lt "$YELLOW_MAX" ]; then echo yellow
  else echo red; fi
}

icon() { case "$1" in green) echo "🟢" ;; yellow) echo "🟡" ;; red) echo "🔴" ;; esac; }

case "$1" in
  tokens) tokens "$2" ;;
  status)
    t=$(tokens "$2"); [ -z "$t" ] && exit 0
    printf '%s %sK' "$(icon "$(zone "$t")")" "$((t / 1000))" ;;
  hook)
    input=$(cat)
    tp=$(echo "$input" | jq -r '.transcript_path // empty')
    sid=$(echo "$input" | jq -r '.session_id // "unknown"')
    event=$(echo "$input" | jq -r '.hook_event_name // "PostToolUse"')
    [ -f "$tp" ] || exit 0
    t=$(tokens "$tp"); [ -z "$t" ] && exit 0
    z=$(zone "$t")

    state_dir="${TMPDIR:-/tmp}/context-zone"; mkdir -p "$state_dir"
    state="$state_dir/$sid"
    { read -r prev count < "$state"; } 2>/dev/null
    count=$(( ${count:-0} + 1 ))

    emit=""
    if [ "$z" != "$prev" ] && [ "$z" != green ]; then emit=1; count=0
    elif [ "$z" = red ] && [ "$count" -ge "$RED_REMIND" ]; then emit=1; count=0; fi
    echo "$z $count" > "$state"
    [ -z "$emit" ] && exit 0

    k=$((t / 1000))
    case "$z" in
      yellow) msg="Context: ${k}K tokens ($(icon yellow) warm). At the next natural break, update the ledger (Manager/Lead) or prepare the handoff note (Specialist). Do not delegate because of this." ;;
      red)    msg="Context: ${k}K tokens ($(icon red) heavy). Do not stop mid-work: finish the current task (a short warning mid-way is fine) and note the zone in your final report. After the task: Manager updates the ledger and compacts; Lead compacts, or hands over if a phase just finished; Specialist reports with the zone noted (HANDOFF only if the task cannot be finished here)." ;;
    esac
    jq -n --arg e "$event" --arg m "$msg" '{hookSpecificOutput: {hookEventName: $e, additionalContext: $m}}' ;;
  *) echo "usage: context-zone.sh hook | status <transcript> | tokens <transcript>" >&2; exit 2 ;;
esac
