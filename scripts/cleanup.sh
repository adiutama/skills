#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_DIR="${SOURCE_DIR:-${REPO_ROOT}/skills}"
source "${SCRIPT_DIR}/lib/agent-harnesses.sh"

DRY_RUN=true
ASSUME_YES=false
HOME_DIR="${HOME}"
TARGETS=()

usage() {
  cat <<'EOF'
Usage:
  ./scripts/cleanup.sh [--apply] [--yes]

Behavior:
  - Detects supported agent slugs from local skills CLI when available.
  - Treats an agent as "used" when its CLI binary is available on PATH.
  - Marks known config directories for agents without installed binaries.

Options:
  --apply     Remove detected directories (default is dry-run)
  --yes       Skip confirmation prompt during --apply
  --help,-h   Show this help

Environment:
  SOURCE_DIR  Skills source directory (default: <repo>/skills)
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --apply)
        DRY_RUN=false
        shift
        ;;
      --yes|-y)
        ASSUME_YES=true
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done
}

append_unique_target() {
  local candidate="$1"
  local item=""
  [[ -n "${candidate}" ]] || return 0
  for item in "${TARGETS[@]:-}"; do
    [[ "${item}" == "${candidate}" ]] && return 0
  done
  TARGETS+=("${candidate}")
}

collect_targets() {
  local slug=""
  local dir=""
  local -a supported=()

  while IFS= read -r slug; do
    [[ -n "${slug}" ]] && supported+=("${slug}")
  done < <(supported_agent_slugs)

  for slug in "${supported[@]:-}"; do
    if is_agent_available "${slug}"; then
      continue
    fi

    while IFS= read -r dir; do
      [[ -n "${dir}" ]] || continue
      [[ -d "${dir}" ]] || continue
      append_unique_target "${dir}"
    done < <(agent_config_dirs_for_slug "${slug}")
  done
}

confirm_if_needed() {
  if [[ "${DRY_RUN}" == true || "${ASSUME_YES}" == true ]]; then
    return 0
  fi

  local reply=""
  read -r -p "Delete ${#TARGETS[@]} directories? [y/N] " reply
  case "${reply}" in
    y|Y|yes|YES) ;;
    *)
      echo "Cancelled."
      exit 0
      ;;
  esac
}

delete_targets() {
  local dir=""
  for dir in "${TARGETS[@]}"; do
    if [[ "${dir}" != "${HOME_DIR}/."* ]]; then
      echo "Skipping unsafe path: ${dir}" >&2
      continue
    fi
    rm -rf "${dir}"
    echo "Removed: ${dir}"
  done
}

main() {
  parse_args "$@"
  collect_targets

  if [[ ${#TARGETS[@]} -eq 0 ]]; then
    echo "No unused config directories found."
    return
  fi

  echo "Unused config directories:"
  printf '  - %s\n' "${TARGETS[@]}"

  if [[ "${DRY_RUN}" == true ]]; then
    echo
    echo "Dry-run mode. Re-run with --apply to delete."
    return
  fi

  confirm_if_needed
  delete_targets
}

main "$@"
