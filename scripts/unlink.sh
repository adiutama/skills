#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_DIR="${SOURCE_DIR:-${REPO_ROOT}/skills}"

if [[ ! -d "${SOURCE_DIR}" ]]; then
  echo "Skills directory not found: ${SOURCE_DIR}" >&2
  exit 1
fi

SKILL_NAMES=()

while IFS= read -r skill_dir; do
  SKILL_NAMES+=("$(basename "${skill_dir}")")
done < <(for d in "${SOURCE_DIR}"/*; do [[ -f "${d}/SKILL.md" ]] && printf '%s\n' "${d}"; done | sort)

if [[ ${#SKILL_NAMES[@]} -eq 0 ]]; then
  echo "No skills found in ${SOURCE_DIR}" >&2
  exit 1
fi

echo "Unlinking skills from: ${SOURCE_DIR}"
echo "Target: global (all agents)"
echo "Skills: ${SKILL_NAMES[*]}"

npx skills remove -g --all -y "${SKILL_NAMES[@]}" "$@"
