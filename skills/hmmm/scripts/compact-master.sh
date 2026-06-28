#!/usr/bin/env bash
# Compact master.md when it grows too large.
# Usage: compact-master.sh <path-to-master.md> [max_lines]
# Output: JSON { compacted, lines_before, lines_after, actions }

set -euo pipefail

MASTER="${1:-}"
MAX_LINES="${2:-150}"

if [[ -z "$MASTER" || ! -f "$MASTER" ]]; then
  jq -n '{compacted: false, error: "master file not found"}'
  exit 1
fi

lines_before=$(wc -l <"$MASTER" | tr -d ' ')
actions=()
compacted=false

attempt_count=$(awk '
  /^## Attempts/{f=1;next}
  f && /^## /{exit}
  f && /^- iter /{c++}
  END{print c+0}
' "$MASTER")

if [[ "$attempt_count" -gt 8 ]]; then
  fold=$((attempt_count - 8))
  compacted=true
  actions+=("folded ${fold} attempt lines into Archive")
  awk -v keep=8 '
    /^## Attempts/ { print; in_a=1; n=0; next }
    in_a && /^## / {
      for (i=1; i<=n; i++) if (i<=keep) print attempts[i]
      if (fold_n>0) {
        if (!archive_printed) { print ""; print "## Archive"; archive_printed=1 }
        for (i=1; i<=fold_n; i++) print archive[i]
      }
      in_a=0; print; next
    }
    in_a && /^- iter / {
      n++; attempts[n]=$0
      if (n>keep) { fold_n++; archive[fold_n]=("- " substr($0,3)) }
      next
    }
    !in_a { print }
    END {
      if (in_a) {
        for (i=1; i<=n; i++) if (i<=keep) print attempts[i]
        if (fold_n>0) {
          print ""; print "## Archive"
          for (i=1; i<=fold_n; i++) print archive[i]
        }
      }
    }
  ' "$MASTER" >"${MASTER}.tmp" && mv "${MASTER}.tmp" "$MASTER"
fi

lines_mid=$(wc -l <"$MASTER" | tr -d ' ')
if [[ "$lines_mid" -gt "$MAX_LINES" ]] && grep -q '^## Archive' "$MASTER"; then
  compacted=true
  actions+=("trimmed Archive to last 20 entries")
  awk '
    /^## Archive$/ { print; in_a=1; delete buf; n=0; next }
    in_a && /^## / { for (i=(n>20?n-19:1); i<=n; i++) print buf[i]; in_a=0; print; next }
    in_a && /^- / { n++; buf[n]=$0; next }
    in_a && !/^- / { next }
    !in_a { print }
    END { if (in_a) for (i=(n>20?n-19:1); i<=n; i++) print buf[i] }
  ' "$MASTER" >"${MASTER}.tmp" && mv "${MASTER}.tmp" "$MASTER"
fi

lines_after=$(wc -l <"$MASTER" | tr -d ' ')

if [[ ${#actions[@]} -eq 0 ]]; then
  actions_json='[]'
else
  actions_json=$(printf '%s\n' "${actions[@]}" | jq -R . | jq -s .)
fi

jq -n \
  --argjson compacted "$compacted" \
  --argjson lines_before "$lines_before" \
  --argjson lines_after "$lines_after" \
  --argjson actions "$actions_json" \
  '{compacted: $compacted, lines_before: $lines_before, lines_after: $lines_after, actions: $actions}'
