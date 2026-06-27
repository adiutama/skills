#!/usr/bin/env bash
# Resolve git change scope for blast-radius checks.
# Usage: resolve-scope.sh [target-branch-or-commit-sha]
# Output: KEY=VALUE lines (resolve-range fields plus session + changed files).
#
# Additional keys vs review-diff resolve-range.sh:
# - SESSION_DIR, SESSION_PATH, PASS
# - CHANGED_FILES (|:| separated relative paths, sorted unique)
# - OWNER, REPO

set -euo pipefail

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

resolve_owner_repo() {
  local url
  url=$(git remote get-url origin 2>/dev/null || true)
  if [[ -z "$url" ]]; then
    OWNER="_local"
    REPO="_local"
    return
  fi
  if [[ "$url" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]%.git}"
    return
  fi
  OWNER="_local"
  REPO="_local"
}

branch_slug() {
  printf '%s' "$BRANCH" | sed -E 's/[^a-zA-Z0-9]+/-/g; s/^-+|-+$//g'
}

allocate_session_path() {
  local slug dir legacy_dir base f candidate n
  slug=$(branch_slug)
  dir="${HOME}/.agents/artifacts/${OWNER}/${REPO}/${slug}/scan-blast-radius"
  legacy_dir="${HOME}/.agents/artifacts/${OWNER}/${REPO}/${slug}/check-blast-radius"
  mkdir -p "$dir"

  n=0
  for base in "$dir" "$legacy_dir"; do
    [[ -d "$base" ]] || continue
    shopt -s nullglob
    for f in "$base"/*.md; do
      candidate="${f##*/}"
      candidate="${candidate%.md}"
      if [[ "$candidate" =~ ^[0-9]+$ ]] && (( 10#candidate > n )); then
        n=$((10#candidate))
      fi
    done
    shopt -u nullglob
  done
  n=$((n + 1))

  SESSION_DIR="$dir"
  SESSION_PATH="$dir/$(printf '%02d' "$n").md"
  PASS=$(printf '%02d' "$n")
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
  if [[ -n "$PR_BASE" ]]; then
    return 0
  fi

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
  if [[ -n "$PR_BASE" ]]; then
    return 0
  fi

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
    return
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

emit_result() {
  print_kv "OWNER" "$OWNER"
  print_kv "REPO" "$REPO"
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
  print_kv "SESSION_DIR" "$SESSION_DIR"
  print_kv "SESSION_PATH" "$SESSION_PATH"
  print_kv "PASS" "$PASS"
  print_kv "CHANGED_FILES" "$CHANGED_FILES"
}

main() {
  TARGET_INPUT="${1:-HEAD}"

  resolve_repo_context
  resolve_owner_repo
  resolve_target
  resolve_strong_hints
  infer_pr_base
  apply_safety_fallbacks
  resolve_range_base
  set_include_uncommitted
  allocate_session_path
  collect_changed_files
  emit_result
}

main "$@"
