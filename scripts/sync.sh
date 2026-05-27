#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_DIR="${SOURCE_DIR:-${REPO_ROOT}/skills}"
GLOBAL_SKILLS_DIR="${GLOBAL_SKILLS_DIR:-${HOME}/.agents/skills}"
EXTRA_ADD_ARGS=()
LOCAL_SKILL_NAMES=()
REPO_MANAGED_GLOBAL_NAMES=()
STALE_SKILL_NAMES=()

##
# sync.sh
# Reconcile repo-local skills with global skill installation.
#
# Design intent:
# - Only manage skills that are clearly linked from this repo.
# - Remove stale global links when local folders are deleted.
# - Re-link current local skills in one predictable step.
#
# Usage:
#   ./scripts/sync.sh [--dry-run] [extra npx skills add args...]
#
# Optional environment:
#   SOURCE_DIR=/abs/path/to/skills
#   GLOBAL_SKILLS_DIR=/abs/path/to/global/skills
##

DRY_RUN=false

usage() {
  cat <<'EOF'
Usage:
  ./scripts/sync.sh [--dry-run] [extra add args...]

Examples:
  ./scripts/sync.sh
  ./scripts/sync.sh --dry-run
  ./scripts/sync.sh --copy

Environment:
  SOURCE_DIR        Skills source directory (default: <repo>/skills)
  GLOBAL_SKILLS_DIR Global skills directory (default: ~/.agents/skills)
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

# Collect local skill names from directories that contain SKILL.md.
collect_local_skill_names() {
  local names=()
  while IFS= read -r skill_dir; do
    names+=("$(basename "${skill_dir}")")
  done < <(
    for d in "${SOURCE_DIR}"/*; do
      [[ -f "${d}/SKILL.md" ]] && printf '%s\n' "${d}"
    done | sort
  )
  if [[ ${#names[@]} -gt 0 ]]; then
    printf '%s\n' "${names[@]}"
  fi
}

# Convert readlink output to an absolute path.
resolve_link_target() {
  local link_path="$1"
  local raw_target
  raw_target="$(readlink "${link_path}" || true)"

  if [[ -z "${raw_target}" ]]; then
    return 1
  fi

  if [[ "${raw_target}" == /* ]]; then
    printf '%s\n' "${raw_target}"
    return 0
  fi

  printf '%s\n' "$(cd "$(dirname "${link_path}")" && cd "$(dirname "${raw_target}")" && pwd)/$(basename "${raw_target}")"
}

# Collect global skill names that are managed by this repo
# (symlinks whose targets live under SOURCE_DIR).
collect_repo_managed_global_names() {
  local names=()
  local entry=""
  local target=""

  if [[ -d "${GLOBAL_SKILLS_DIR}" ]]; then
    while IFS= read -r entry; do
      [[ -n "${entry}" ]] || continue
      target="$(resolve_link_target "${entry}" || true)"
      [[ -n "${target}" ]] || continue

      if [[ "${target}" == "${SOURCE_DIR}/"* ]]; then
        names+=("${entry##*/}")
      fi
    done < <(
      for p in "${GLOBAL_SKILLS_DIR}"/*; do
        [[ -L "${p}" ]] && printf '%s\n' "${p}"
      done | sort
    )
  fi

  if [[ ${#names[@]} -gt 0 ]]; then
    printf '%s\n' "${names[@]}"
  fi
}

contains_name() {
  local needle="$1"
  shift
  local hay=("$@")
  local item=""

  for item in "${hay[@]}"; do
    [[ "${item}" == "${needle}" ]] && return 0
  done
  return 1
}

collect_stale_names() {
  local repo_global=("$@")
  local name=""
  local stale=()

  for name in "${repo_global[@]}"; do
    if ! contains_name "${name}" "${LOCAL_SKILL_NAMES[@]}"; then
      stale+=("${name}")
    fi
  done

  if [[ ${#stale[@]} -gt 0 ]]; then
    printf '%s\n' "${stale[@]}"
  fi
}

remove_stale_globals() {
  if [[ ${#STALE_SKILL_NAMES[@]} -eq 0 ]]; then
    echo "No stale global skills to remove."
    return
  fi

  echo "Removing stale global skills: ${STALE_SKILL_NAMES[*]}"
  if [[ "${DRY_RUN}" == true ]]; then
    echo "[dry-run] npx skills remove -g -y ${STALE_SKILL_NAMES[*]}"
  else
    npx skills remove -g -y "${STALE_SKILL_NAMES[@]}"
  fi
}

link_current_locals() {
  if [[ ${#LOCAL_SKILL_NAMES[@]} -eq 0 ]]; then
    echo "No local skills found in ${SOURCE_DIR}; skipping link step."
    return
  fi

  echo "Linking current local skills..."
  if [[ "${DRY_RUN}" == true ]]; then
    if [[ ${#EXTRA_ADD_ARGS[@]} -gt 0 ]]; then
      echo "[dry-run] npx skills add \"${SOURCE_DIR}\" -g --all -y ${EXTRA_ADD_ARGS[*]}"
    else
      echo "[dry-run] npx skills add \"${SOURCE_DIR}\" -g --all -y"
    fi
  else
    if [[ ${#EXTRA_ADD_ARGS[@]} -gt 0 ]]; then
      npx skills add "${SOURCE_DIR}" -g --all -y "${EXTRA_ADD_ARGS[@]}"
    else
      npx skills add "${SOURCE_DIR}" -g --all -y
    fi
  fi
}

main() {
  parse_args "$@"
  ensure_source_dir_exists

  LOCAL_SKILL_NAMES=()
  while IFS= read -r name; do
    [[ -n "${name}" ]] && LOCAL_SKILL_NAMES+=("${name}")
  done < <(collect_local_skill_names)

  REPO_MANAGED_GLOBAL_NAMES=()
  while IFS= read -r name; do
    [[ -n "${name}" ]] && REPO_MANAGED_GLOBAL_NAMES+=("${name}")
  done < <(collect_repo_managed_global_names)

  STALE_SKILL_NAMES=()
  while IFS= read -r name; do
    [[ -n "${name}" ]] && STALE_SKILL_NAMES+=("${name}")
  done < <(collect_stale_names "${REPO_MANAGED_GLOBAL_NAMES[@]:-}")

  echo "Syncing skills from: ${SOURCE_DIR}"
  echo "Global skills path: ${GLOBAL_SKILLS_DIR}"
  echo "Target: global (all agents)"

  remove_stale_globals
  link_current_locals

  echo "Sync complete."
}

main "$@"
