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
TEMP_NPM_CACHE=""

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

cleanup() {
  if [[ -n "${TEMP_NPM_CACHE}" && -d "${TEMP_NPM_CACHE}" ]]; then
    find "${TEMP_NPM_CACHE}" -depth -delete
  fi
}
trap cleanup EXIT

ensure_npm_cache() {
  local default_cache=""
  local probe_dir=""
  local probe=""
  local temp_root="${TMPDIR:-/tmp}"

  [[ -z "${npm_config_cache:-}" && -z "${NPM_CONFIG_CACHE:-}" ]] || return 0

  default_cache="$(npm config get cache)" || return 1
  if [[ -d "${default_cache}" ]]; then
    probe_dir="${default_cache}/_cacache/tmp"
    [[ -d "${probe_dir}" ]] || probe_dir="${default_cache}"
    probe="$(mktemp "${probe_dir%/}/.skills-sync.XXXXXX" 2>/dev/null)" || true
    if [[ -n "${probe}" ]]; then
      find "${probe}" -delete
      return 0
    fi
  fi

  TEMP_NPM_CACHE="$(mktemp -d "${temp_root%/}/skills-sync-npm.XXXXXX")" || return 1
  export npm_config_cache="${TEMP_NPM_CACHE}"
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

# Ask the skills CLI for global state. Only a symlink into SOURCE_DIR proves
# that a stale installation belongs to this repo; copied installs are ambiguous.
collect_repo_managed_global_names() {
  local name=""
  local skills_json=""
  local names_output=""

  skills_json="$(npx skills list -g --json)" || return 1
  names_output="$(printf '%s\n' "${skills_json}" | SKILLS_SOURCE_DIR="${SOURCE_DIR}" node -e '
    const fs = require("fs");
    const path = require("path");
    const sourceDir = path.resolve(process.env.SKILLS_SOURCE_DIR);
    let input = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", chunk => input += chunk);
    process.stdin.on("end", () => {
      const skills = JSON.parse(input);
      for (const skill of skills) {
        if (!skill || typeof skill.name !== "string" || typeof skill.path !== "string") continue;
        try {
          if (!fs.lstatSync(skill.path).isSymbolicLink()) continue;
          const target = path.resolve(path.dirname(skill.path), fs.readlinkSync(skill.path));
          if (target === path.join(sourceDir, skill.name)) console.log(skill.name);
        } catch { /* Missing or inaccessible installation: leave it alone. */ }
      }
    });
  ')" || return 1

  while IFS= read -r name; do
    [[ -n "${name}" ]] || continue
    if contains_name "${name}" "${REPO_KNOWN_SKILL_NAMES[@]}"; then
      printf '%s\n' "${name}"
    fi
  done <<< "${names_output}"
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
  ensure_npm_cache
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
