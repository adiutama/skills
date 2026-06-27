#!/usr/bin/env bash
# Discover refinable text targets under a skill folder.
# Usage: discover-targets.sh <folder>
# Output: one path per line, relative to <folder>, sorted

set -euo pipefail

ROOT="${1:?folder path required}"
ROOT="$(cd "$ROOT" && pwd)"

find "$ROOT" -type f \
  \( -name '*.md' -o -name '*.txt' -o -name '*.prompt' \) \
  ! -path '*/scripts/*' \
  ! -name '*.optimized.md' \
  ! -name 'package-lock.json' \
  ! -name 'yarn.lock' \
  ! -name 'pnpm-lock.yaml' \
  | sed "s|^${ROOT}/||" \
  | LC_ALL=C sort
