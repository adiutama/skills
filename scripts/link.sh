#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_DIR="${SOURCE_DIR:-${REPO_ROOT}/skills}"
source "${SCRIPT_DIR}/lib/agent-harnesses.sh"
DRY_RUN=false
EXTRA_ADD_ARGS=()

##
# link.sh
# Link all local skills from SOURCE_DIR into global scope for all agents.
#
# Usage:
#   ./scripts/link.sh [--dry-run] [extra npx skills add args...]
##

usage() {
  cat <<'EOF'
Usage:
  ./scripts/link.sh [--dry-run] [extra add args...]

Examples:
  ./scripts/link.sh
  ./scripts/link.sh --dry-run
  ./scripts/link.sh --copy

Environment:
  SOURCE_DIR  Skills source directory (default: <repo>/skills)
  SKILLS_AGENTS Optional explicit agent slug list (comma/space-separated)
EOF
}

parse_args() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
  fi

  if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    shift
  fi

  EXTRA_ADD_ARGS=("$@")
}

ensure_source_dir_exists() {
  if [[ ! -d "${SOURCE_DIR}" ]]; then
    echo "Skills directory not found: ${SOURCE_DIR}" >&2
    exit 1
  fi
}

run_link() {
  build_agent_args

  echo "Linking skills from: ${SOURCE_DIR}"
  echo "Target: global (${AGENT_SCOPE_DESC})"

  run_skills_add_all "${SOURCE_DIR}" "${DRY_RUN}" "${EXTRA_ADD_ARGS[@]}"
}

main() {
  parse_args "$@"
  ensure_source_dir_exists
  run_link
}

main "$@"
