#!/usr/bin/env bash
# Resolve artifact directories (local when gitignored, else global).
# Source from skill scripts:
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/artifact-root.sh"
#
# Layout (both roots use the same suffix):
#   <root>/<owner>/<repo>/<branch-slug>/<skill-name>/
#
# Override with AGENTS_ARTIFACTS_SCOPE=local|global

artifact_git_root() {
  git rev-parse --show-toplevel 2>/dev/null || true
}

# Exit 0 when .agents/artifacts (or parent .agents) is ignored by git.
artifact_artifacts_gitignored() {
  local git_root="${1:-$(artifact_git_root)}"
  [[ -n "$git_root" ]] || return 1

  if git -C "$git_root" check-ignore -q -- ".agents/artifacts" 2>/dev/null; then
    return 0
  fi
  if git -C "$git_root" check-ignore -q -- ".agents" 2>/dev/null; then
    return 0
  fi
  return 1
}

# local | global | auto
artifact_write_scope() {
  local scope="${AGENTS_ARTIFACTS_SCOPE:-}"
  local git_root
  git_root=$(artifact_git_root)

  if [[ "$scope" == "global" || "$scope" == "local" ]]; then
    printf '%s' "$scope"
    return
  fi

  if [[ -z "$git_root" ]]; then
    printf 'global'
    return
  fi
  if artifact_artifacts_gitignored "$git_root"; then
    printf 'local'
    return
  fi
  printf 'global'
}

artifact_search_roots() {
  local git_root scope="${AGENTS_ARTIFACTS_SCOPE:-}"
  git_root=$(artifact_git_root)

  if [[ "$scope" == "global" ]]; then
    printf '%s\n' "${HOME}/.agents/artifacts"
    return
  fi

  if [[ -n "$git_root" ]]; then
    printf '%s\n' "${git_root}/.agents/artifacts"
  fi
  if [[ "$scope" != "local" ]]; then
    printf '%s\n' "${HOME}/.agents/artifacts"
  fi
}

artifact_write_root() {
  local git_root scope
  git_root=$(artifact_git_root)
  scope=$(artifact_write_scope)

  if [[ "$scope" == "local" && -n "$git_root" ]]; then
    printf '%s/.agents/artifacts' "$git_root"
    return
  fi
  printf '%s/.agents/artifacts' "$HOME"
}

artifact_branch_path() {
  local owner="$1" repo="$2" branch_slug="$3"
  printf '%s/%s/%s/%s' "$(artifact_write_root)" "$owner" "$repo" "$branch_slug"
}

artifact_skill_path() {
  local owner="$1" repo="$2" branch_slug="$3" skill="$4"
  printf '%s/%s' "$(artifact_branch_path "$owner" "$repo" "$branch_slug")" "$skill"
}

artifact_resolve_skill_dir() {
  local owner="$1" repo="$2" branch_slug="$3" skill="$4"
  local root path
  while IFS= read -r root; do
    [[ -n "$root" ]] || continue
    path="${root}/${owner}/${repo}/${branch_slug}/${skill}"
    if [[ -d "$path" ]]; then
      printf '%s' "$path"
      return 0
    fi
  done < <(artifact_search_roots)
  artifact_skill_path "$owner" "$repo" "$branch_slug" "$skill"
}

artifact_resolve_branch_base() {
  local owner="$1" repo="$2" branch_slug="$3"
  local root path
  while IFS= read -r root; do
    [[ -n "$root" ]] || continue
    path="${root}/${owner}/${repo}/${branch_slug}"
    if [[ -d "$path" ]]; then
      printf '%s' "$path"
      return 0
    fi
  done < <(artifact_search_roots)
  artifact_branch_path "$owner" "$repo" "$branch_slug"
}

# Highest NN.md under <skill> across local + global search roots.
artifact_latest_numbered_markdown() {
  local owner="$1" repo="$2" branch_slug="$3" skill="$4"
  local root dir f base best="" best_n=0
  while IFS= read -r root; do
    [[ -n "$root" ]] || continue
    dir="${root}/${owner}/${repo}/${branch_slug}/${skill}"
    [[ -d "$dir" ]] || continue
    shopt -s nullglob
    for f in "$dir"/*.md; do
      base="${f##*/}"
      base="${base%.md}"
      if [[ "$base" =~ ^[0-9]+$ ]] && (( 10#base > best_n )); then
        best_n=$((10#base))
        best="$f"
      fi
    done
    shopt -u nullglob
  done < <(artifact_search_roots)
  printf '%s' "$best"
}

# Next pass number (max existing + 1) across local + global for one or more skill dirs.
artifact_next_pass_number() {
  local owner="$1" repo="$2" branch_slug="$3"
  shift 3
  local skills=("$@")
  local root dir skill f candidate n=0
  while IFS= read -r root; do
    [[ -n "$root" ]] || continue
    for skill in "${skills[@]}"; do
      dir="${root}/${owner}/${repo}/${branch_slug}/${skill}"
      [[ -d "$dir" ]] || continue
      shopt -s nullglob
      for f in "$dir"/*.md; do
        candidate="${f##*/}"
        candidate="${candidate%.md}"
        if [[ "$candidate" =~ ^[0-9]+$ ]] && (( 10#candidate > n )); then
          n=$((10#candidate))
        fi
      done
      shopt -u nullglob
    done
  done < <(artifact_search_roots)
  printf '%d' $((n + 1))
}
