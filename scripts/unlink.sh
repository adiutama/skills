#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_DIR="${SOURCE_DIR:-${REPO_ROOT}/skills}"
source "${SCRIPT_DIR}/lib/agent-harnesses.sh"
DRY_RUN=false
EXTRA_REMOVE_ARGS=()
SKILL_NAMES=()

##
# unlink.sh
# Unlink all local skills from global scope for all agents.
#
# Usage:
#   ./scripts/unlink.sh [--dry-run] [extra npx skills remove args...]
##

usage() {
  cat <<'EOF'
Usage:
  ./scripts/unlink.sh [--dry-run] [extra remove args...]

Examples:
  ./scripts/unlink.sh
  ./scripts/unlink.sh --dry-run
  ./scripts/unlink.sh --agent Cursor

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

  EXTRA_REMOVE_ARGS=("$@")
}

ensure_source_dir_exists() {
  if [[ ! -d "${SOURCE_DIR}" ]]; then
    echo "Skills directory not found: ${SOURCE_DIR}" >&2
    exit 1
  fi
}

collect_skill_names() {
  local skill_dir=""
  while IFS= read -r skill_dir; do
    SKILL_NAMES+=("$(basename "${skill_dir}")")
  done < <(
    for d in "${SOURCE_DIR}"/*; do
      [[ -f "${d}/SKILL.md" ]] && printf '%s\n' "${d}"
    done | sort
  )
}

ensure_skill_names_exist() {
  if [[ ${#SKILL_NAMES[@]} -eq 0 ]]; then
    echo "No skills found in ${SOURCE_DIR}" >&2
    exit 1
  fi
}

run_unlink() {
  build_agent_args

  echo "Unlinking skills from: ${SOURCE_DIR}"
  echo "Target: global (${AGENT_SCOPE_DESC})"
  echo "Skills: ${SKILL_NAMES[*]}"

  run_skills_remove_global "${DRY_RUN}" "${SKILL_NAMES[@]}" -- "${EXTRA_REMOVE_ARGS[@]}"
}

main() {
  parse_args "$@"
  ensure_source_dir_exists
  collect_skill_names
  ensure_skill_names_exist
  run_unlink
}

main "$@"
