#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FIXTURE_ROOT="$(mktemp -d)"
FIXTURE_HOME="${FIXTURE_ROOT}/home"
SOURCE_DIR="${FIXTURE_ROOT}/source"
STALE_SKILL_DIR="${FIXTURE_HOME}/.claude/skills/review-change"
FAKE_BIN_DIR="${REPO_ROOT}/scripts/tests/fixtures/bin"

cleanup() {
  if command -v trash >/dev/null 2>&1; then
    trash "${FIXTURE_ROOT}"
  else
    find "${FIXTURE_ROOT}" -depth -delete
  fi
}
trap cleanup EXIT

mkdir -p "${SOURCE_DIR}" "${STALE_SKILL_DIR}"
cp "${REPO_ROOT}/skills/review-pr/SKILL.md" "${STALE_SKILL_DIR}/SKILL.md"

output="$({
  HOME="${FIXTURE_HOME}" \
    PATH="${FAKE_BIN_DIR}:${PATH}" \
    SOURCE_DIR="${SOURCE_DIR}" \
    SKILLS_AGENTS=claude-code \
    "${REPO_ROOT}/scripts/sync.sh" --dry-run
} 2>&1)"

if [[ "${output}" != *"Removing stale global skills:"*"review-change"* ]]; then
  printf 'Expected copied agent skill to be detected as stale.\n\n%s\n' "${output}" >&2
  exit 1
fi

printf 'sync copied-install regression: ok\n'
