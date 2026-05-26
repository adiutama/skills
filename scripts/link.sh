#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_DIR="${SOURCE_DIR:-${REPO_ROOT}/skills}"

if [[ ! -d "${SOURCE_DIR}" ]]; then
  echo "Skills directory not found: ${SOURCE_DIR}" >&2
  exit 1
fi

echo "Linking skills from: ${SOURCE_DIR}"
echo "Target: global (all agents)"

npx skills add "${SOURCE_DIR}" -g --all -y "$@"
