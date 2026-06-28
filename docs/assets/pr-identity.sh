#!/usr/bin/env bash
# TEMPLATE ONLY — do not run from docs/assets/.
# Copy to: skills/<skill-name>/scripts/pr-identity.sh
#
# Source from sibling scripts (not invoked from SKILL.md):
#   # shellcheck source=pr-identity.sh
#   source "${SCRIPT_DIR}/pr-identity.sh"
#
# Sets globals OWNER, REPO, NUMBER from a GitHub PR URL or number.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]] && [[ "${BASH_SOURCE[0]}" == *"docs/assets/pr-identity.sh" ]]; then
  cat >&2 <<'EOF'
Error: docs/assets/pr-identity.sh is a template only — not for runtime use.
Copy to skills/<skill-name>/scripts/pr-identity.sh, then source that copy.
EOF
  exit 1
fi

require_gh_jq() {
  command -v gh &>/dev/null || {
    echo "Error: gh CLI not installed. See https://cli.github.com" >&2
    exit 1
  }
  command -v jq &>/dev/null || {
    echo "Error: jq not installed. Run: brew install jq" >&2
    exit 1
  }
}

parse_pr_identity() {
  local arg="$1"

  if [[ "$arg" =~ ^https://github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
    NUMBER="${BASH_REMATCH[3]}"
    return 0
  fi

  if [[ "$arg" =~ ^[0-9]+$ ]]; then
    local name_with_owner
    name_with_owner=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) || {
      echo "Error: could not detect repo — run from inside a git repo or provide the full PR URL." >&2
      exit 1
    }
    OWNER="${name_with_owner%%/*}"
    REPO="${name_with_owner##*/}"
    NUMBER="$arg"
    return 0
  fi

  echo "Error: expected a GitHub PR URL or number, got: $arg" >&2
  exit 1
}
