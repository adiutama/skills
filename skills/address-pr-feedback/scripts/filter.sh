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

require_jq() {
  command -v jq &>/dev/null || {
    echo "Error: jq is not installed. Install it from https://jqlang.org or via your package manager (e.g. brew install jq)." >&2
    exit 1
  }
}

jq_filter_program() {
  cat <<'EOF'
def excerpt: split("\n") | map(select(length > 0)) | .[0:4] | join("\n");
def is_bot_login: . // "" | test("\\[bot\\]$|^coderabbitai$");

.threads |= [
  .[] |
  select(.isResolved == false) |
  select((.isOutdated == false) or (.line != null)) |
  .comments.nodes |= map(. + { body_excerpt: (.body | excerpt) }) |
  (.comments.nodes | first) as $first |
  (.comments.nodes | last) as $last |
  . + {
    anchor_moved: (.isOutdated == true and .line != null),
    reviewer: ($first.author.login // ""),
    is_bot: (($first.author.login // "") | is_bot_login),
    reply_kind: "thread",
    reply_to_id: ($last.databaseId // null)
  }
] |
.reviews |= [
  .[] |
  select(.state != "APPROVED" and .state != "DISMISSED") |
  select(
    .state == "CHANGES_REQUESTED" or
    ((.author.login // "") | is_bot_login | not)
  ) |
  . + {
    body_excerpt: (.body | excerpt),
    reviewer: (.author.login // ""),
    is_bot: ((.author.login // "") | is_bot_login),
    reply_kind: "review"
  }
] |
.comments |= [
  .[] |
  select(
    ((.user.type // "") != "Bot") and
    ((.user.login // "") | is_bot_login | not)
  ) |
  . + {
    body_excerpt: (.body | excerpt),
    reviewer: (.user.login // ""),
    is_bot: false,
    reply_kind: "issue_comment",
    reply_to_id: .id
  }
]
EOF
}

main() {
  require_jq
  jq "$(jq_filter_program)"
}

main "$@"
