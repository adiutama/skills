#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_DIR="${SOURCE_DIR:-${REPO_ROOT}/skills}"
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
  SOURCE_DIR    Skills source directory (default: <repo>/skills)
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

# Ask the skills CLI for global state. It owns the agent-specific paths and
# understands both linked and copied installs.
collect_repo_managed_global_names() {
  local name=""

  while IFS= read -r name; do
    [[ -n "${name}" ]] || continue
    if contains_name "${name}" "${REPO_KNOWN_SKILL_NAMES[@]}"; then
      printf '%s\n' "${name}"
    fi
  done < <(
    npx skills list -g --json | node -e '
      let input = "";
      process.stdin.setEncoding("utf8");
      process.stdin.on("data", chunk => input += chunk);
      process.stdin.on("end", () => {
        const skills = JSON.parse(input);
        for (const skill of skills) {
          if (skill && typeof skill.name === "string") console.log(skill.name);
        }
      });
    '
  )
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
    [[ -n "${name}" ]] || continue
    if [[ ${#LOCAL_SKILL_NAMES[@]} -eq 0 ]] || ! contains_name "${name}" "${LOCAL_SKILL_NAMES[@]}"; then
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
  run_skills_remove_global_all_agents "${DRY_RUN}" "${STALE_SKILL_NAMES[@]}"
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
  local repo_managed_output=""

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

  if ! repo_managed_output="$(collect_repo_managed_global_names)"; then
    echo "Unable to list global skills with npx skills." >&2
    exit 1
  fi

  REPO_MANAGED_GLOBAL_NAMES=()
  while IFS= read -r name; do
    [[ -n "${name}" ]] && REPO_MANAGED_GLOBAL_NAMES+=("${name}")
  done <<< "${repo_managed_output}"

  STALE_SKILL_NAMES=()
  while IFS= read -r name; do
    [[ -n "${name}" ]] && STALE_SKILL_NAMES+=("${name}")
  done < <(collect_stale_names "${REPO_MANAGED_GLOBAL_NAMES[@]:-}")

  echo "Syncing skills from: ${SOURCE_DIR}"
  echo "Target: global (${AGENT_SCOPE_DESC})"

  remove_stale_globals
  link_current_locals

  echo "Sync complete."
}

main "$@"
