#!/usr/bin/env bash
# TEMPLATE ONLY — do not run or source from docs/assets/.
# Copy to: skills/<skill-name>/scripts/artifacts.sh
#
# In the skill package, source from sibling scripts:
#   SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
#   # shellcheck source=artifacts.sh
#   source "${SCRIPT_DIR}/artifacts.sh"
#
# CLI (skill-local copy only):
#   bash <SKILL_DIR>/scripts/artifacts.sh check [--json]
#   bash <SKILL_DIR>/scripts/artifacts.sh allocate <skill> [branch]
#
# Source helpers (after sourcing this file):
#   artifact_git_owner_repo   — sets OWNER, REPO
#   artifact_git_branch [ref] — sets BRANCH (current HEAD when omitted)
#   artifact_branch_slug [branch] — prints slug (current HEAD when omitted)
#
# Layout: <write-root>/<owner>/<repo>/<branch-slug>/<skill-name>/
# Override: AGENTS_ARTIFACTS_SCOPE=local|global

readonly ARTIFACT_GLOBAL_ROOT="${HOME}/.agents/artifacts"
readonly -a ARTIFACT_IGNORE_PATHS=(".agents/artifacts" ".agents")

# --- Scope & roots ---

artifact_git_root() {
  git rev-parse --show-toplevel 2>/dev/null || true
}

_artifact_local_root() {
  printf '%s/.agents/artifacts' "$1"
}

artifact_artifacts_gitignored() {
  local git_root="${1:-$(artifact_git_root)}"
  local path
  [[ -n "$git_root" ]] || return 1
  for path in "${ARTIFACT_IGNORE_PATHS[@]}"; do
    git -C "$git_root" check-ignore -q -- "$path" 2>/dev/null && return 0
  done
  return 1
}

artifact_write_scope() {
  local scope="${AGENTS_ARTIFACTS_SCOPE:-}"
  local git_root
  git_root=$(artifact_git_root)

  case "$scope" in
    global|local) printf '%s' "$scope"; return ;;
  esac

  if [[ -z "$git_root" ]] || ! artifact_artifacts_gitignored "$git_root"; then
    printf 'global'
  else
    printf 'local'
  fi
}

artifact_search_roots() {
  local git_root scope="${AGENTS_ARTIFACTS_SCOPE:-}"
  git_root=$(artifact_git_root)

  if [[ "$scope" == "global" ]]; then
    printf '%s\n' "$ARTIFACT_GLOBAL_ROOT"
    return
  fi

  [[ -n "$git_root" ]] && printf '%s\n' "$(_artifact_local_root "$git_root")"
  [[ "$scope" != "local" ]] && printf '%s\n' "$ARTIFACT_GLOBAL_ROOT"
}

artifact_write_root() {
  local git_root scope
  git_root=$(artifact_git_root)
  scope=$(artifact_write_scope)

  if [[ "$scope" == "local" && -n "$git_root" ]]; then
    _artifact_local_root "$git_root"
  else
    printf '%s' "$ARTIFACT_GLOBAL_ROOT"
  fi
}

# --- Path layout ---

_artifact_repo_rel() {
  printf '%s/%s/%s' "$1" "$2" "$3"
}

_artifact_skill_rel() {
  _artifact_repo_rel "$1" "$2" "$3"
  printf '/%s' "$4"
}

_artifact_join() {
  printf '%s/%s' "$1" "$2"
}

artifact_branch_path() {
  _artifact_join "$(artifact_write_root)" "$(_artifact_repo_rel "$1" "$2" "$3")"
}

artifact_skill_path() {
  _artifact_join "$(artifact_write_root)" "$(_artifact_skill_rel "$1" "$2" "$3" "$4")"
}

_artifact_find_existing_dir() {
  local rel="$1" fallback="$2" root candidate
  while IFS= read -r root; do
    [[ -n "$root" ]] || continue
    candidate="$(_artifact_join "$root" "$rel")"
    if [[ -d "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done < <(artifact_search_roots)
  printf '%s' "$fallback"
}

artifact_resolve_skill_dir() {
  local owner="$1" repo="$2" branch_slug="$3" skill="$4"
  local rel="$(_artifact_skill_rel "$owner" "$repo" "$branch_slug" "$skill")"
  _artifact_find_existing_dir "$rel" "$(artifact_skill_path "$owner" "$repo" "$branch_slug" "$skill")"
}

artifact_resolve_branch_base() {
  local owner="$1" repo="$2" branch_slug="$3"
  local rel="$(_artifact_repo_rel "$owner" "$repo" "$branch_slug")"
  _artifact_find_existing_dir "$rel" "$(artifact_branch_path "$owner" "$repo" "$branch_slug")"
}

# --- Numbered passes (NN.md) ---

_artifact_each_skill_dir() {
  local owner="$1" repo="$2" branch_slug="$3" skill="$4"
  local rel root
  rel="$(_artifact_skill_rel "$owner" "$repo" "$branch_slug" "$skill")"
  while IFS= read -r root; do
    [[ -n "$root" ]] || continue
    printf '%s\n' "$(_artifact_join "$root" "$rel")"
  done < <(artifact_search_roots)
}

# Sets _ARTIFACT_PASS_N and _ARTIFACT_PASS_FILE for the highest NN.md in dir.
_artifact_highest_pass_in_dir() {
  local dir="$1" f base n=0
  _ARTIFACT_PASS_N=0
  _ARTIFACT_PASS_FILE=""
  [[ -d "$dir" ]] || return 0

  shopt -s nullglob
  for f in "$dir"/*.md; do
    base="${f##*/}"
    base="${base%.md}"
    if [[ "$base" =~ ^[0-9]+$ ]] && (( 10#base > n )); then
      n=$((10#base))
      _ARTIFACT_PASS_N=$n
      _ARTIFACT_PASS_FILE="$f"
    fi
  done
  shopt -u nullglob
}

artifact_latest_numbered_markdown() {
  local owner="$1" repo="$2" branch_slug="$3" skill="$4"
  local dir best="" best_n=0
  while IFS= read -r dir; do
    _artifact_highest_pass_in_dir "$dir"
    if (( _ARTIFACT_PASS_N > best_n )); then
      best_n=$_ARTIFACT_PASS_N
      best="$_ARTIFACT_PASS_FILE"
    fi
  done < <(_artifact_each_skill_dir "$owner" "$repo" "$branch_slug" "$skill")
  printf '%s' "$best"
}

artifact_next_pass_number() {
  local owner="$1" repo="$2" branch_slug="$3" skill="$4"
  local dir max=0
  while IFS= read -r dir; do
    _artifact_highest_pass_in_dir "$dir"
    (( _ARTIFACT_PASS_N > max )) && max=$_ARTIFACT_PASS_N
  done < <(_artifact_each_skill_dir "$owner" "$repo" "$branch_slug" "$skill")
  printf '%d' $((max + 1))
}

# --- Git context (public — source from skill scripts) ---

# Sets global OWNER and REPO from origin remote (or _local/_local).
artifact_git_owner_repo() {
  _artifact_resolve_owner_repo
}

# Sets global BRANCH from arg or current HEAD (handles detached HEAD).
artifact_git_branch() {
  _artifact_resolve_branch "${1:-}"
}

# Prints a filesystem-safe slug for branch (arg or current HEAD when omitted).
artifact_branch_slug() {
  local branch="${1-}"
  if [[ $# -eq 0 || -z "$branch" ]]; then
    _artifact_resolve_branch ""
    branch="$BRANCH"
  fi
  printf '%s' "$branch" | sed -E 's/[^a-zA-Z0-9]+/-/g; s/^-+|-+$//g'
}

# --- CLI ---

_artifact_print_kv() {
  printf '%s=%s\n' "$1" "${2:-}"
}

_artifact_resolve_owner_repo() {
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

_artifact_resolve_branch() {
  local arg="${1:-}"
  if [[ -n "$arg" ]]; then
    BRANCH="$arg"
    return
  fi

  local branch_raw head_short
  branch_raw=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)
  if [[ "$branch_raw" == "HEAD" ]]; then
    head_short=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
    BRANCH="detached-${head_short}"
    return
  fi
  BRANCH="$branch_raw"
}

_artifact_check_reason() {
  local git_root="$1"
  if [[ "${AGENTS_ARTIFACTS_SCOPE:-}" == "local" || "${AGENTS_ARTIFACTS_SCOPE:-}" == "global" ]]; then
    printf 'AGENTS_ARTIFACTS_SCOPE=%s override' "${AGENTS_ARTIFACTS_SCOPE}"
  elif [[ -z "$git_root" ]]; then
    printf 'not inside a git repository'
  elif artifact_artifacts_gitignored "$git_root"; then
    if git -C "$git_root" check-ignore -q -- ".agents/artifacts" 2>/dev/null; then
      printf '.agents/artifacts is gitignored'
    else
      printf '.agents is gitignored (covers .agents/artifacts)'
    fi
  else
    printf '.agents/artifacts is not gitignored — using global to avoid accidental commits'
  fi
}

_artifact_cmd_check() {
  local json=false git_root write_root write_scope gitignored=false
  [[ "${1:-}" == "--json" ]] && json=true

  git_root=$(artifact_git_root)
  write_root=$(artifact_write_root)
  write_scope=$(artifact_write_scope)
  artifact_artifacts_gitignored "$git_root" && gitignored=true
  local reason
  reason=$(_artifact_check_reason "$git_root")

  if $json; then
    jq -n \
      --arg git_root "${git_root}" \
      --arg write_root "$write_root" \
      --arg write_scope "$write_scope" \
      --arg reason "$reason" \
      --argjson gitignored "$gitignored" \
      '{
        git_root: (if ($git_root | length) > 0 then $git_root else null end),
        gitignored: $gitignored,
        write_scope: $write_scope,
        write_root: $write_root,
        reason: $reason
      }'
    return
  fi

  cat <<EOF
Artifact write root: ${write_root}
Write scope:         ${write_scope}
Git root:            ${git_root:-<none>}
Gitignored:          ${gitignored}
Reason:              ${reason}

Add to .gitignore to use project-local artifacts:
  .agents/

Check: bash <SKILL_DIR>/scripts/artifacts.sh check [--json]
EOF
}

_artifact_cmd_allocate() {
  local skill="${1:?"Usage: artifacts.sh allocate <skill> [branch]"}"
  local branch_arg="${2:-}"
  local n pass

  artifact_git_owner_repo
  artifact_git_branch "$branch_arg"
  BRANCH_SLUG=$(artifact_branch_slug "$BRANCH")

  SESSION_DIR=$(artifact_skill_path "$OWNER" "$REPO" "$BRANCH_SLUG" "$skill")
  mkdir -p "$SESSION_DIR"

  n=$(artifact_next_pass_number "$OWNER" "$REPO" "$BRANCH_SLUG" "$skill")
  pass=$(printf '%02d' "$n")
  SESSION_PATH="${SESSION_DIR}/${pass}.md"

  _artifact_print_kv "OWNER" "$OWNER"
  _artifact_print_kv "REPO" "$REPO"
  _artifact_print_kv "BRANCH" "$BRANCH"
  _artifact_print_kv "BRANCH_SLUG" "$BRANCH_SLUG"
  _artifact_print_kv "SESSION_DIR" "$SESSION_DIR"
  _artifact_print_kv "SESSION_PATH" "$SESSION_PATH"
  _artifact_print_kv "PASS" "$pass"
  _artifact_print_kv "WRITE_ROOT" "$(artifact_write_root)"
  _artifact_print_kv "WRITE_SCOPE" "$(artifact_write_scope)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ "${BASH_SOURCE[0]}" == *"docs/assets/artifacts.sh" ]]; then
    cat >&2 <<'EOF'
Error: docs/assets/artifacts.sh is a template only — not for runtime use.
Copy to skills/<skill-name>/scripts/artifacts.sh, then run or source that copy.
EOF
    exit 1
  fi
  set -euo pipefail
  cmd="${1:-}"
  shift || true
  case "$cmd" in
    check) _artifact_cmd_check "$@" ;;
    allocate) _artifact_cmd_allocate "$@" ;;
    -h|--help|help|"")
      cat <<'EOF'
Usage:
  artifacts.sh check [--json]
  artifacts.sh allocate <skill> [branch]

Copy this file from docs/assets/artifacts.sh into skills/<name>/scripts/artifacts.sh (template — do not run from docs/).

Source from skill scripts:
  SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  # shellcheck source=artifacts.sh
  source "${SCRIPT_DIR}/artifacts.sh"
EOF
      ;;
    *)
      echo "Error: unknown command: $cmd" >&2
      exit 1
      ;;
  esac
fi
