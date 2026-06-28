#!/usr/bin/env bash
# Resolve git change scope for blast-radius checks.
# Usage: resolve-scope.sh [target-branch-or-commit-sha]
# Output: KEY=VALUE lines (resolve-range fields plus session + changed files).
#
# Additional keys vs resolve-range.sh:
# - SESSION_DIR, SESSION_PATH, PASS
# - CHANGED_FILES (|:| separated relative paths, sorted unique)
# - OWNER, REPO

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=artifacts.sh
source "${SCRIPT_DIR}/artifacts.sh"
# shellcheck source=resolve-range.sh
source "${SCRIPT_DIR}/resolve-range.sh"

SKILL_NAME="scan-blast-radius"

allocate_session_path() {
  local slug dir n
  slug=$(artifact_branch_slug "$BRANCH")
  dir=$(artifact_skill_path "$OWNER" "$REPO" "$slug" "$SKILL_NAME")
  mkdir -p "$dir"

  n=$(artifact_next_pass_number "$OWNER" "$REPO" "$slug" "$SKILL_NAME")

  SESSION_DIR="$dir"
  SESSION_PATH="$dir/$(printf '%02d' "$n").md"
  PASS=$(printf '%02d' "$n")
}

collect_changed_files() {
  local -a files=()
  local f

  while IFS= read -r f; do
    [[ -n "$f" ]] && files+=("$f")
  done < <(git diff --name-only "${RANGE_BASE}..${TARGET_SHA}" 2>/dev/null || true)

  if [[ "$INCLUDE_UNCOMMITTED" == "1" ]]; then
    while IFS= read -r f; do
      [[ -n "$f" ]] && files+=("$f")
    done < <(git diff --name-only HEAD 2>/dev/null || true)
    while IFS= read -r f; do
      [[ -n "$f" ]] && files+=("$f")
    done < <(git diff --name-only --cached 2>/dev/null || true)
  fi

  if [[ ${#files[@]} -eq 0 ]]; then
    CHANGED_FILES=""
    return
  fi

  CHANGED_FILES=$(printf '%s\n' "${files[@]}" | sort -u | paste -sd'|' -)
}

emit_scope_result() {
  emit_range_result
  print_kv "OWNER" "$OWNER"
  print_kv "REPO" "$REPO"
  print_kv "SESSION_DIR" "$SESSION_DIR"
  print_kv "SESSION_PATH" "$SESSION_PATH"
  print_kv "PASS" "$PASS"
  print_kv "CHANGED_FILES" "$CHANGED_FILES"
}

main() {
  resolve_range_core "${1:-HEAD}"
  artifact_git_owner_repo
  allocate_session_path
  collect_changed_files
  emit_scope_result
}

main "$@"
