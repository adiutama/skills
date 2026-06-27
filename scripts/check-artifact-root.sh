#!/usr/bin/env bash
# Report where skill artifacts would be written for the current repo.
# Usage: ./scripts/check-artifact-root.sh [--json]
#
# Writes locally only when .agents/artifacts (or .agents/) is gitignored.
# Otherwise uses ~/.agents/artifacts/ to avoid committing session output.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
# shellcheck source=../docs/assets/artifact-root.sh
source "${REPO_ROOT}/docs/assets/artifact-root.sh"

JSON=false
if [[ "${1:-}" == "--json" ]]; then
  JSON=true
fi

git_root=$(artifact_git_root)
write_root=$(artifact_write_root)
write_scope=$(artifact_write_scope)
gitignored=false
reason=""

if [[ -z "$git_root" ]]; then
  reason="not inside a git repository"
elif artifact_artifacts_gitignored "$git_root"; then
  gitignored=true
  if git -C "$git_root" check-ignore -q -- ".agents/artifacts" 2>/dev/null; then
    reason=".agents/artifacts is gitignored"
  else
    reason=".agents is gitignored (covers .agents/artifacts)"
  fi
else
  reason=".agents/artifacts is not gitignored — using global to avoid accidental commits"
fi

if [[ "${AGENTS_ARTIFACTS_SCOPE:-}" == "local" || "${AGENTS_ARTIFACTS_SCOPE:-}" == "global" ]]; then
  reason="AGENTS_ARTIFACTS_SCOPE=${AGENTS_ARTIFACTS_SCOPE} override"
fi

if $JSON; then
  jq -n \
    --arg git_root "${git_root}" \
    --arg write_root "$write_root" \
    --arg write_scope "$write_scope" \
    --arg reason "$reason" \
    --argjson gitignored "$gitignored" \
    '{
      git_root: (if ($git_root | length) > 0 then $git_root else null end),
      gitignored: $gitignored,
      write_scope: $write_scope,
      write_root: $write_root,
      reason: $reason
    }'
  exit 0
fi

cat <<EOF
Artifact write root: ${write_root}
Write scope:         ${write_scope}
Git root:            ${git_root:-<none>}
Gitignored:          ${gitignored}
Reason:              ${reason}

Add to .gitignore to use project-local artifacts:
  .agents/

Check anytime:
  ./scripts/check-artifact-root.sh [--json]
EOF
