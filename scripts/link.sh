#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_DIR="${SOURCE_DIR:-${REPO_ROOT}/skills}"
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
  echo "Linking skills from: ${SOURCE_DIR}"
  echo "Target: global (all agents)"

  if [[ "${DRY_RUN}" == true ]]; then
    if [[ ${#EXTRA_ADD_ARGS[@]} -gt 0 ]]; then
      echo "[dry-run] npx skills add \"${SOURCE_DIR}\" -g --all -y ${EXTRA_ADD_ARGS[*]}"
    else
      echo "[dry-run] npx skills add \"${SOURCE_DIR}\" -g --all -y"
    fi
    return
  fi

  if [[ ${#EXTRA_ADD_ARGS[@]} -gt 0 ]]; then
    npx skills add "${SOURCE_DIR}" -g --all -y "${EXTRA_ADD_ARGS[@]}"
  else
    npx skills add "${SOURCE_DIR}" -g --all -y
  fi
}

main() {
  parse_args "$@"
  ensure_source_dir_exists
  run_link
}

main "$@"
