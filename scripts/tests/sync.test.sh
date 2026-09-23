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
  find "${FIXTURE_ROOT}" -depth -delete
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

if [[ "${output}" == *"Removing stale global skills:"*"review-change"* ]]; then
  printf 'Expected copied skill of uncertain origin to be preserved.\n\n%s\n' "${output}" >&2
  exit 1
fi

printf 'sync copied-install preservation: ok\n'

find "${STALE_SKILL_DIR}" -depth -delete
ln -s "${SOURCE_DIR}/review-change" "${STALE_SKILL_DIR}"

output="$(
  HOME="${FIXTURE_HOME}" \
    PATH="${FAKE_BIN_DIR}:${PATH}" \
    SOURCE_DIR="${SOURCE_DIR}" \
    SKILLS_AGENTS=claude-code \
    "${REPO_ROOT}/scripts/sync.sh" --dry-run 2>&1
)"

if [[ "${output}" != *"Removing stale global skills:"*"review-change"* ]]; then
  printf 'Expected a stale link into this repo to be removed.\n\n%s\n' "${output}" >&2
  exit 1
fi

printf 'sync stale-link removal: ok\n'

FAIL_BIN_DIR="${FIXTURE_ROOT}/fail-bin"
mkdir -p "${FAIL_BIN_DIR}"
cat > "${FAIL_BIN_DIR}/npx" <<'EOF'
#!/usr/bin/env bash
printf 'simulated skills CLI failure\n' >&2
exit 23
EOF
chmod +x "${FAIL_BIN_DIR}/npx"

set +e
failure_output="$(
  HOME="${FIXTURE_HOME}" \
    PATH="${FAIL_BIN_DIR}:${PATH}" \
    SOURCE_DIR="${SOURCE_DIR}" \
    SKILLS_AGENTS=claude-code \
    "${REPO_ROOT}/scripts/sync.sh" --dry-run 2>&1
)"
failure_status=$?
set -e

if [[ ${failure_status} -eq 0 || "${failure_output}" != *"Unable to list global skills"* || "${failure_output}" == *"Sync complete."* ]]; then
  printf 'Expected sync to stop when listing global skills fails.\n\n%s\n' "${failure_output}" >&2
  exit 1
fi

printf 'sync CLI failure regression: ok\n'

CACHE_BIN_DIR="${FIXTURE_ROOT}/cache-bin"
mkdir -p "${CACHE_BIN_DIR}"
cat > "${CACHE_BIN_DIR}/npm" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == "config get cache" ]] || exit 1
printf '%s\n' "$HOME/missing-npm-cache"
EOF
cat > "${CACHE_BIN_DIR}/npx" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == "skills list -g --json" && -d "$npm_config_cache" ]] || exit 1
printf '[]\n'
EOF
chmod +x "${CACHE_BIN_DIR}/npm" "${CACHE_BIN_DIR}/npx"

cache_output="$(
  env -u npm_config_cache -u NPM_CONFIG_CACHE \
    HOME="${FIXTURE_HOME}" \
    PATH="${CACHE_BIN_DIR}:${PATH}" \
    SOURCE_DIR="${SOURCE_DIR}" \
    SKILLS_AGENTS=claude-code \
    "${REPO_ROOT}/scripts/sync.sh" --dry-run 2>&1
)"

if [[ "${cache_output}" != *"Sync complete."* ]]; then
  printf 'Expected sync to use a temporary npm cache.\n\n%s\n' "${cache_output}" >&2
  exit 1
fi

printf 'sync npm cache fallback regression: ok\n'
