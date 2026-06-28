#!/usr/bin/env bash
# Validate a discovery lane report.
# Usage: validate-discovery.sh <path-to-discovery-lane.md>
# Exit 0 + JSON { valid: true, status, summary, confidence } or exit 1 + JSON { valid: false, errors: [...] }

set -euo pipefail

REPORT="${1:-}"
if [[ -z "$REPORT" || ! -f "$REPORT" ]]; then
  jq -n --arg msg "discovery file not found" '{valid: false, errors: [$msg]}'
  exit 1
fi

errors=()

status=$(grep -E '^status:[[:space:]]*(complete|partial|blocked)[[:space:]]*$' "$REPORT" | head -1 | sed -E 's/^status:[[:space:]]*//' || true)
[[ -n "$status" ]] || errors+=("missing status: complete|partial|blocked")

grep -q '^## Summary' "$REPORT" || errors+=("missing ## Summary section")
grep -q '^## Findings' "$REPORT" || errors+=("missing ## Findings section")
grep -q '^## Evidence' "$REPORT" || errors+=("missing ## Evidence section")
grep -q '^## Gaps' "$REPORT" || errors+=("missing ## Gaps section")
grep -q '^## Confidence' "$REPORT" || errors+=("missing ## Confidence section")

confidence=$(grep -E '^## Confidence' -A1 "$REPORT" | tail -1 | tr -d '[:space:]' || true)
if [[ -n "$confidence" && "$confidence" != "high" && "$confidence" != "medium" && "$confidence" != "low" ]]; then
  errors+=("Confidence must be high, medium, or low")
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
  --arg confidence "$confidence" \
  '{valid: true, status: $status, summary: $summary, confidence: $confidence}'
