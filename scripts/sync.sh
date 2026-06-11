#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_DIR="${SOURCE_DIR:-${REPO_ROOT}/skills}"
GLOBAL_SKILLS_DIR="${GLOBAL_SKILLS_DIR:-${HOME}/.agents/skills}"
source "${SCRIPT_DIR}/lib/agent-harnesses.sh"
EXTRA_ADD_ARGS=()
LOCAL_SKILL_NAMES=()
REPO_KNOWN_SKILL_NAMES=()
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
  SKILLS_AGENTS     Optional explicit agent slug list (comma/space-separated)
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

# Collect skill names that have existed in this repo (current + historical)
# from tracked paths matching skills/<name>/SKILL.md.
collect_repo_known_skill_names() {
  local names=()
  local path=""
  local name=""

  while IFS= read -r name; do
    [[ -n "${name}" ]] && names+=("${name}")
  done < <(collect_local_skill_names)

  if git -C "${REPO_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r path; do
      [[ -n "${path}" ]] || continue
      case "${path}" in
        skills/*/SKILL.md)
          name="${path#skills/}"
          name="${name%/SKILL.md}"
          names+=("${name}")
          ;;
      esac
    done < <(
      git -C "${REPO_ROOT}" log --pretty=format: --name-only -- "skills/*/SKILL.md" | sort -u
    )
  fi

  if [[ ${#names[@]} -gt 0 ]]; then
    printf '%s\n' "${names[@]}" | sort -u
  fi
}

# Lexically normalize an absolute path (without requiring it to exist).
normalize_absolute_path_lexically() {
  local input_path="$1"
  local -a parts=()
  local -a resolved_parts=()
  local part=""

  [[ "${input_path}" == /* ]] || return 1

  IFS='/' read -r -a parts <<< "${input_path}"
  for part in "${parts[@]}"; do
    [[ -z "${part}" || "${part}" == "." ]] && continue
    if [[ "${part}" == ".." ]]; then
      if [[ ${#resolved_parts[@]} -gt 0 ]]; then
        unset "resolved_parts[$((${#resolved_parts[@]} - 1))]"
      fi
      continue
    fi
    resolved_parts+=("${part}")
  done

  if [[ ${#resolved_parts[@]} -eq 0 ]]; then
    printf '/\n'
  else
    printf '/%s\n' "$(IFS=/; echo "${resolved_parts[*]}")"
  fi
}

# Convert readlink output to an absolute path, even if target is missing.
resolve_link_target() {
  local link_path="$1"
  local raw_target
  local absolute_target
  raw_target="$(readlink "${link_path}" || true)"

  if [[ -z "${raw_target}" ]]; then
    return 1
  fi

  if [[ "${raw_target}" == /* ]]; then
    absolute_target="${raw_target}"
  else
    absolute_target="$(dirname "${link_path}")/${raw_target}"
  fi

  normalize_absolute_path_lexically "${absolute_target}"
}

# Collect global skill names that are managed by this repo
# (symlinks whose targets live under SOURCE_DIR).
collect_repo_managed_global_names() {
  local names=()
  local entry=""
  local target=""
  local normalized_source=""

  normalized_source="$(normalize_absolute_path_lexically "${SOURCE_DIR}")"

  if [[ -d "${GLOBAL_SKILLS_DIR}" ]]; then
    while IFS= read -r entry; do
      [[ -n "${entry}" ]] || continue
      target="$(resolve_link_target "${entry}" || true)"
      [[ -n "${target}" ]] || continue

      if [[ "${target}" == "${normalized_source}/"* ]]; then
        names+=("${entry##*/}")
      fi
    done < <(
      for p in "${GLOBAL_SKILLS_DIR}"/*; do
        [[ -L "${p}" ]] && printf '%s\n' "${p}"
      done | sort
    )

    # Also include copied/global directory installs that match known repo skills.
    while IFS= read -r entry; do
      [[ -n "${entry}" ]] || continue
      if [[ -d "${entry}" && -f "${entry}/SKILL.md" ]]; then
        if contains_name "${entry##*/}" "${REPO_KNOWN_SKILL_NAMES[@]}"; then
          names+=("${entry##*/}")
        fi
      fi
    done < <(
      for p in "${GLOBAL_SKILLS_DIR}"/*; do
        [[ -d "${p}" ]] && printf '%s\n' "${p}"
      done | sort
    )
  fi

  if [[ ${#names[@]} -gt 0 ]]; then
    printf '%s\n' "${names[@]}" | sort -u
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
  run_skills_remove_global "${DRY_RUN}" "${STALE_SKILL_NAMES[@]}" --
}

link_current_locals() {
  if [[ ${#LOCAL_SKILL_NAMES[@]} -eq 0 ]]; then
    echo "No local skills found in ${SOURCE_DIR}; skipping link step."
    return
  fi

  echo "Linking current local skills..."
  run_skills_add_all "${SOURCE_DIR}" "${DRY_RUN}" "${EXTRA_ADD_ARGS[@]+"${EXTRA_ADD_ARGS[@]}"}"
}

main() {
  parse_args "$@"
  ensure_source_dir_exists
  build_agent_args

  LOCAL_SKILL_NAMES=()
  while IFS= read -r name; do
    [[ -n "${name}" ]] && LOCAL_SKILL_NAMES+=("${name}")
  done < <(collect_local_skill_names)

  REPO_KNOWN_SKILL_NAMES=()
  while IFS= read -r name; do
    [[ -n "${name}" ]] && REPO_KNOWN_SKILL_NAMES+=("${name}")
  done < <(collect_repo_known_skill_names)

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
  echo "Target: global (${AGENT_SCOPE_DESC})"

  remove_stale_globals
  link_current_locals

  echo "Sync complete."
}

main "$@"
