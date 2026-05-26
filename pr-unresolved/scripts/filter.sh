#!/usr/bin/env bash
# Filter fetched PR data to actionable unresolved items.
# Reads  { pr, threads, reviews, comments } JSON from stdin.
# Writes { pr, threads, reviews, comments } JSON to stdout.
#
# threads — include if:
#   isResolved=false, isOutdated=false
#   isResolved=false, isOutdated=true, line!=null  → anchor_moved=true
#   exclude if isOutdated=true and line=null (diff context gone, UI shows "Outdated")
#
# reviews — keep CHANGES_REQUESTED (blocking) from anyone;
#           keep COMMENTED from humans only (bot summaries duplicate resolved threads);
#           exclude APPROVED, DISMISSED, and bot COMMENTED reviews.
#
# comments — exclude bot issue comments (deploy notices, CI status, etc.)
#
# body_excerpt — first 4 non-empty lines of each body, added to all items

set -euo pipefail

command -v jq &>/dev/null || { echo "Error: jq is not installed. Install it from https://jqlang.org or via your package manager (e.g. brew install jq)." >&2; exit 1; }

jq '
  def excerpt: split("\n") | map(select(length > 0)) | .[0:4] | join("\n");

  .threads |= [
    .[] |
    select(.isResolved == false) |
    select((.isOutdated == false) or (.line != null)) |
    . + { anchor_moved: (.isOutdated == true and .line != null) } |
    .comments.nodes |= map(. + { body_excerpt: (.body | excerpt) })
  ] |
  .reviews |= [
    .[] |
    select(.state != "APPROVED" and .state != "DISMISSED") |
    select(
      .state == "CHANGES_REQUESTED" or
      ((.author.login // "") | test("\\[bot\\]$|^coderabbitai$") | not)
    ) |
    . + { body_excerpt: (.body | excerpt) }
  ] |
  .comments |= [
    .[] |
    select(
      ((.user.type // "") != "Bot") and
      ((.user.login // "") | test("\\[bot\\]$") | not)
    ) |
    . + { body_excerpt: (.body | excerpt) }
  ]
'
