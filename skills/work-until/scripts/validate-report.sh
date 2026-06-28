#!/usr/bin/env bash
# Validate report.md from an iteration worker.
# Usage: validate-report.sh <path-to-report.md>
# Exit 0 + JSON { valid: true, status, summary, ... } or exit 1 + JSON { valid: false, errors: [...] }

set -euo pipefail

REPORT="${1:-}"
if [[ -z "$REPORT" || ! -f "$REPORT" ]]; then
  jq -n --arg msg "report file not found" '{valid: false, errors: [$msg]}'
  exit 1
fi

errors=()

status=$(grep -E '^status:[[:space:]]*(done|continue|blocked)[[:space:]]*$' "$REPORT" | head -1 | sed -E 's/^status:[[:space:]]*//' || true)
[[ -n "$status" ]] || errors+=("missing status: done|continue|blocked")

grep -q '^## Summary' "$REPORT" || errors+=("missing ## Summary section")
grep -q '^## Evidence' "$REPORT" || errors+=("missing ## Evidence section")
grep -q '^## Changes' "$REPORT" || errors+=("missing ## Changes section")
grep -q '^## Blockers' "$REPORT" || errors+=("missing ## Blockers section")

if [[ "$status" == "continue" ]]; then
  grep -q '^## Recommended next' "$REPORT" || errors+=("missing ## Recommended next (required when status is continue)")
fi

summary_empty=true
if awk '/^## Summary/{f=1;next} f&&/^## /{exit} f&&/[^[:space:]]/{found=1;exit} END{exit !found}' "$REPORT"; then
  summary_empty=false
fi
[[ "$summary_empty" == false ]] || errors+=("Summary section is empty")

if [[ ${#errors[@]} -gt 0 ]]; then
  jq -n --argjson errors "$(printf '%s\n' "${errors[@]}" | jq -R . | jq -s .)" \
    '{valid: false, errors: $errors}'
  exit 1
fi

summary=$(awk '/^## Summary/{f=1;next} f&&/^## /{exit} f{print}' "$REPORT" | sed '/^[[:space:]]*$/d' | head -3 | tr '\n' ' ' | sed 's/[[:space:]]*$//')

jq -n \
  --arg status "$status" \
  --arg summary "$summary" \
  '{valid: true, status: $status, summary: $summary}'
