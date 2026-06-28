#!/usr/bin/env bash
# TEMPLATE ONLY — do not run from docs/assets/.
# Copy to: skills/<skill-name>/scripts/resolve-range.sh
#
# Resolve local git review scope in one call.
# Usage: resolve-range.sh [target-branch-or-commit-sha]
# Output: KEY=VALUE lines for BRANCH, TARGET_SHA, PR_BASE, RANGE_BASE, and related fields.
#
# Output contract (consumed by SKILL.md):
# - COMMITTED_RANGE = RANGE_BASE..TARGET_SHA
# - INCLUDE_UNCOMMITTED = 1 only when TARGET_SHA == current HEAD
#
# Skill-local:
#   bash <SKILL_DIR>/scripts/resolve-range.sh [target]
#
# Source from extended scripts (e.g. resolve-scope.sh):
#   # shellcheck source=resolve-range.sh
#   source "${SCRIPT_DIR}/resolve-range.sh"
#   resolve_range_core "$target"

set -euo pipefail

if [[ "${BASH_SOURCE[0]}" == "${0}" ]] && [[ "${BASH_SOURCE[0]}" == *"docs/assets/resolve-range.sh" ]]; then
  cat >&2 <<'EOF'
Error: docs/assets/resolve-range.sh is a template only — not for runtime use.
Copy to skills/<skill-name>/scripts/resolve-range.sh, then run that copy.
EOF
  exit 1
fi

ref_exists() {
  git rev-parse --verify --quiet "$1^{commit}" >/dev/null 2>&1
}

print_kv() {
  local key="$1"
  local val="${2:-}"
  printf '%s=%s\n' "$key" "$val"
}

resolve_repo_context() {
  BRANCH_RAW="$(git rev-parse --abbrev-ref HEAD)"
  HEAD_SHA="$(git rev-parse HEAD)"

  local head_short
  head_short="$(git rev-parse --short HEAD)"

  UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name "@{upstream}" 2>/dev/null || true)"
  ORIGIN_HEAD="$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null || true)"

  if [[ "$BRANCH_RAW" == "HEAD" ]]; then
    BRANCH="detached-${head_short}"
  else
    BRANCH="$BRANCH_RAW"
  fi
}

resolve_target() {
  TARGET_KIND="commit"
  TARGET_SHA=""
  TARGET_BRANCH=""

  if ! ref_exists "$TARGET_INPUT"; then
    echo "Error: invalid target '$TARGET_INPUT'. Provide a branch name or commit SHA." >&2
    exit 1
  fi

  TARGET_SHA="$(git rev-parse "$TARGET_INPUT^{commit}")"
  if git show-ref --verify --quiet "refs/heads/$TARGET_INPUT" || git show-ref --verify --quiet "refs/remotes/$TARGET_INPUT"; then
    TARGET_KIND="branch"
    TARGET_BRANCH="$TARGET_INPUT"
  fi
}

resolve_strong_hints() {
  GH_MERGE_BASE=""
  TARGET_UPSTREAM=""
  PR_BASE=""
  RANGE_BASE=""

  if [[ -n "$TARGET_BRANCH" ]] && git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
    GH_MERGE_BASE="$(git config --get "branch.${TARGET_BRANCH}.gh-merge-base" 2>/dev/null || true)"
    TARGET_UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name "${TARGET_BRANCH}@{upstream}" 2>/dev/null || true)"
  fi
  if [[ -z "$GH_MERGE_BASE" ]] && [[ "$TARGET_SHA" == "$HEAD_SHA" ]] && [[ "$BRANCH_RAW" != "HEAD" ]]; then
    GH_MERGE_BASE="$(git config --get "branch.${BRANCH_RAW}.gh-merge-base" 2>/dev/null || true)"
  fi

  if [[ -n "$TARGET_UPSTREAM" ]] && ref_exists "$TARGET_UPSTREAM"; then
    PR_BASE="$TARGET_UPSTREAM"
    RANGE_BASE="$(git rev-parse "$TARGET_UPSTREAM^{commit}")"
  elif [[ "$TARGET_SHA" == "$HEAD_SHA" ]] && [[ -n "$UPSTREAM" ]] && ref_exists "$UPSTREAM"; then
    PR_BASE="$UPSTREAM"
    RANGE_BASE="$(git rev-parse "$UPSTREAM^{commit}")"
  fi

  if [[ -n "$GH_MERGE_BASE" ]] && ref_exists "$GH_MERGE_BASE"; then
    PR_BASE="${PR_BASE:-$GH_MERGE_BASE}"
  fi
}

infer_pr_base() {
  [[ -n "$PR_BASE" ]] && return 0

  local candidates best_score ref mb score
  candidates=()
  [[ -n "$ORIGIN_HEAD" ]] && candidates+=("$ORIGIN_HEAD")
  candidates+=(
    "origin/develop"
    "origin/main"
    "origin/master"
    "origin/trunk"
    "develop"
    "main"
    "master"
    "trunk"
  )

  best_score=""
  for ref in "${candidates[@]}"; do
    [[ -z "$ref" ]] && continue
    ref_exists "$ref" || continue

    mb="$(git merge-base "$TARGET_SHA" "$ref" 2>/dev/null || true)"
    [[ -n "$mb" ]] || continue

    score="$(git rev-list --count "${mb}..${TARGET_SHA}" 2>/dev/null || true)"
    [[ -n "$score" ]] || continue

    if [[ -z "$best_score" ]] || (( score < best_score )); then
      best_score="$score"
      PR_BASE="$ref"
    fi
  done
}

apply_safety_fallbacks() {
  [[ -n "$PR_BASE" ]] && return 0

  if [[ -n "$ORIGIN_HEAD" ]] && ref_exists "$ORIGIN_HEAD"; then
    PR_BASE="$ORIGIN_HEAD"
  elif ref_exists "main"; then
    PR_BASE="main"
  elif ref_exists "${TARGET_SHA}^"; then
    PR_BASE="${TARGET_SHA}^"
  else
    PR_BASE="$TARGET_SHA"
  fi
}

resolve_range_base() {
  if [[ -z "$RANGE_BASE" ]]; then
    RANGE_BASE="$(git merge-base "$TARGET_SHA" "$PR_BASE" 2>/dev/null || true)"
  fi
  if [[ -n "$RANGE_BASE" ]]; then
    return 0
  fi
  if ref_exists "${TARGET_SHA}^"; then
    RANGE_BASE="$(git rev-parse "${TARGET_SHA}^")"
  else
    RANGE_BASE="$TARGET_SHA"
  fi
}

set_include_uncommitted() {
  if [[ "$TARGET_SHA" == "$HEAD_SHA" ]]; then
    INCLUDE_UNCOMMITTED="1"
  else
    INCLUDE_UNCOMMITTED="0"
  fi
}

emit_range_result() {
  print_kv "BRANCH" "$BRANCH"
  print_kv "BRANCH_RAW" "$BRANCH_RAW"
  print_kv "HEAD_SHA" "$HEAD_SHA"
  print_kv "TARGET_INPUT" "$TARGET_INPUT"
  print_kv "TARGET_KIND" "$TARGET_KIND"
  print_kv "TARGET_SHA" "$TARGET_SHA"
  print_kv "UPSTREAM" "$UPSTREAM"
  print_kv "TARGET_UPSTREAM" "$TARGET_UPSTREAM"
  print_kv "ORIGIN_HEAD" "$ORIGIN_HEAD"
  print_kv "GH_MERGE_BASE" "$GH_MERGE_BASE"
  print_kv "PR_BASE" "$PR_BASE"
  print_kv "RANGE_BASE" "$RANGE_BASE"
  print_kv "COMMITTED_RANGE" "${RANGE_BASE}..${TARGET_SHA}"
  print_kv "INCLUDE_UNCOMMITTED" "$INCLUDE_UNCOMMITTED"
}

resolve_range_core() {
  TARGET_INPUT="${1:-HEAD}"

  resolve_repo_context
  resolve_target
  resolve_strong_hints
  infer_pr_base
  apply_safety_fallbacks
  resolve_range_base
  set_include_uncommitted
}

main() {
  resolve_range_core "${1:-HEAD}"
  emit_range_result
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
