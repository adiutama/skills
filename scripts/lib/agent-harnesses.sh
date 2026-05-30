#!/usr/bin/env bash

# Shared helper to detect locally installed agent harnesses.
# Outputs canonical skills-cli agent slugs (for --agent).
#
# Default behavior:
# 1) Ask a local `skills` CLI for its valid/supported agent slugs.
# 2) Keep only slugs whose binaries are available on PATH.
# Use SKILLS_AGENTS to override when needed.

DETECTED_AGENTS=()
AGENT_ARGS=()
AGENT_SCOPE_DESC=""
DEFAULT_AGENT_SLUGS=(cursor claude-code codex opencode)

append_unique_agent() {
  local candidate="$1"
  local item=""
  [[ -n "${candidate}" ]] || return 0

  for item in "${DETECTED_AGENTS[@]:-}"; do
    [[ "${item}" == "${candidate}" ]] && return 0
  done
  DETECTED_AGENTS+=("${candidate}")
}

strip_ansi() {
  sed -E 's/\x1B\[[0-9;?]*[ -/]*[@-~]//g'
}

supported_agents_from_skills_cli() {
  local output=""
  local valid_line=""
  local source_path="${SOURCE_DIR:-.}"
  local skills_bin=""

  skills_bin="$(command -v skills 2>/dev/null || true)"
  [[ -n "${skills_bin}" ]] || return 0

  output="$(
    "${skills_bin}" add "${source_path}" -g --skill '*' --agent "__skills_invalid_probe__" -y 2>&1 || true
  )"
  valid_line="$(
    printf '%s\n' "${output}" \
      | strip_ansi \
      | awk -F'Valid agents: ' '/Valid agents: /{print $2; exit}'
  )"
  [[ -n "${valid_line}" ]] || return 0

  printf '%s\n' "${valid_line}" \
    | tr ',' '\n' \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' \
    | awk 'NF > 0 { print $0 }'
}

supported_agent_slugs() {
  local slug=""
  local -a supported=()

  while IFS= read -r slug; do
    [[ -n "${slug}" ]] && supported+=("${slug}")
  done < <(supported_agents_from_skills_cli)

  if [[ ${#supported[@]} -eq 0 ]]; then
    supported=("${DEFAULT_AGENT_SLUGS[@]}")
  fi

  printf '%s\n' "${supported[@]}"
}

agent_binary_for_slug() {
  local slug="$1"
  local no_cli="${slug%-cli}"
  local no_dash="${slug//-/}"
  local to_underscore="${slug//-/_}"

  case "${slug}" in
    claude-code) printf 'claude claude-code\n' ;;
    qwen-code) printf 'qwen qwen-code\n' ;;
    kiro-cli) printf 'kiro kiro-cli\n' ;;
    iflow-cli) printf 'iflow iflow-cli\n' ;;
    github-copilot) printf 'github-copilot copilot\n' ;;
    *)
      printf '%s' "${slug}"
      [[ "${no_cli}" != "${slug}" ]] && printf ' %s' "${no_cli}"
      [[ "${no_dash}" != "${slug}" ]] && printf ' %s' "${no_dash}"
      [[ "${to_underscore}" != "${slug}" ]] && printf ' %s' "${to_underscore}"
      printf '\n'
      ;;
  esac
}

agent_config_dirs_for_slug() {
  local slug="$1"
  local home_dir="${HOME_DIR:-${HOME}}"

  case "${slug}" in
    aider-desk) printf '%s\n' "${home_dir}/.aider-desk" "${home_dir}/.aider" ;;
    amp) printf '%s\n' "${home_dir}/.amp" ;;
    antigravity) printf '%s\n' "${home_dir}/.antigravity" ;;
    augment) printf '%s\n' "${home_dir}/.augment" ;;
    bob) printf '%s\n' "${home_dir}/.bob" ;;
    openclaw) printf '%s\n' "${home_dir}/.openclaw" ;;
    cline) printf '%s\n' "${home_dir}/.cline" ;;
    codearts-agent) printf '%s\n' "${home_dir}/.codeartsdoer" ;;
    codebuddy) printf '%s\n' "${home_dir}/.codebuddy" ;;
    codemaker) printf '%s\n' "${home_dir}/.codemaker" ;;
    codestudio) printf '%s\n' "${home_dir}/.codestudio" ;;
    codex) printf '%s\n' "${home_dir}/.codex" ;;
    command-code) printf '%s\n' "${home_dir}/.commandcode" ;;
    continue) printf '%s\n' "${home_dir}/.continue" ;;
    cursor) printf '%s\n' "${home_dir}/.cursor" ;;
    deepagents) printf '%s\n' "${home_dir}/.deepagents" ;;
    dexto) printf '%s\n' "${home_dir}/.dexto" ;;
    firebender) printf '%s\n' "${home_dir}/.firebender" ;;
    forgecode) printf '%s\n' "${home_dir}/.forge" ;;
    gemini-cli) printf '%s\n' "${home_dir}/.gemini" ;;
    github-copilot) printf '%s\n' "${home_dir}/.copilot" ;;
    goose) printf '%s\n' "${home_dir}/.goose" ;;
    hermes-agent) printf '%s\n' "${home_dir}/.hermes" ;;
    junie) printf '%s\n' "${home_dir}/.junie" ;;
    iflow-cli) printf '%s\n' "${home_dir}/.iflow" ;;
    kilo) printf '%s\n' "${home_dir}/.kilocode" ;;
    kimi-cli) printf '%s\n' "${home_dir}/.kimi" ;;
    kiro-cli) printf '%s\n' "${home_dir}/.kiro" ;;
    kode) printf '%s\n' "${home_dir}/.kode" ;;
    mcpjam) printf '%s\n' "${home_dir}/.mcpjam" ;;
    mux) printf '%s\n' "${home_dir}/.mux" ;;
    opencode) printf '%s\n' "${home_dir}/.opencode" ;;
    openhands) printf '%s\n' "${home_dir}/.openhands" ;;
    pi) printf '%s\n' "${home_dir}/.pi" ;;
    qoder) printf '%s\n' "${home_dir}/.qoder" ;;
    qwen-code) printf '%s\n' "${home_dir}/.qwen" ;;
    rovodev) printf '%s\n' "${home_dir}/.roovodev" ;;
    roo) printf '%s\n' "${home_dir}/.roo" ;;
    tabnine-cli) printf '%s\n' "${home_dir}/.tabnine" ;;
    trae) printf '%s\n' "${home_dir}/.trae" ;;
    trae-cn) printf '%s\n' "${home_dir}/.trae-cn" ;;
    warp) printf '%s\n' "${home_dir}/.warp" ;;
    windsurf) printf '%s\n' "${home_dir}/.windsurf" ;;
    zed) printf '%s\n' "${home_dir}/.zed" ;;
    zencoder) printf '%s\n' "${home_dir}/.zencoder" ;;
    neovate) printf '%s\n' "${home_dir}/.neovate" ;;
    pochi) printf '%s\n' "${home_dir}/.pochi" ;;
    adal) printf '%s\n' "${home_dir}/.adal" "${home_dir}/.ada" ;;
  esac
}

is_agent_available() {
  local slug="$1"
  local bins=""
  local agent_bin=""
  local resolved=""
  bins="$(agent_binary_for_slug "${slug}" || true)"
  [[ -n "${bins}" ]] || return 1

  for agent_bin in ${bins}; do
    resolved="$(command -v "${agent_bin}" 2>/dev/null || true)"
    if [[ -n "${resolved}" && "${resolved}" == */* && -x "${resolved}" ]]; then
      return 0
    fi
  done

  # Optional explicit override path per slug:
  # SKILLS_BIN_CURSOR, SKILLS_BIN_CLAUDE_CODE, SKILLS_BIN_CODEX, SKILLS_BIN_OPENCODE
  local env_key
  env_key="$(printf 'SKILLS_BIN_%s' "${slug}" | tr '[:lower:]-' '[:upper:]_')"
  local override_path="${!env_key:-}"
  [[ -n "${override_path}" && -x "${override_path}" ]]
}

split_agents_env() {
  local raw="$1"
  local normalized
  normalized="$(printf '%s' "${raw}" | tr ',' ' ')"
  for token in ${normalized}; do
    printf '%s\n' "${token}"
  done
}

detect_installed_agents() {
  local slug=""
  local override="${SKILLS_AGENTS:-}"

  DETECTED_AGENTS=()

  if [[ -n "${override}" ]]; then
    while IFS= read -r slug; do
      [[ -n "${slug}" ]] || continue
      append_unique_agent "${slug}"
    done < <(split_agents_env "${override}")
    return 0
  fi

  local -a supported=()
  while IFS= read -r slug; do
    [[ -n "${slug}" ]] && supported+=("${slug}")
  done < <(supported_agent_slugs)

  for slug in "${supported[@]}"; do
    if is_agent_available "${slug}"; then
      append_unique_agent "${slug}"
    fi
  done
}

build_agent_args() {
  detect_installed_agents

  AGENT_ARGS=()
  if [[ ${#DETECTED_AGENTS[@]} -gt 0 ]]; then
    AGENT_ARGS=(--agent "${DETECTED_AGENTS[@]}")
    AGENT_SCOPE_DESC="binary-detected agents (${DETECTED_AGENTS[*]})"
  else
    AGENT_SCOPE_DESC="skills-cli auto-detected agent"
  fi
}

print_command() {
  local arg=""

  printf '[dry-run]'
  for arg in "$@"; do
    printf ' %q' "${arg}"
  done
  printf '\n'
}

run_or_print() {
  local dry_run="$1"
  shift

  if [[ "${dry_run}" == true ]]; then
    print_command "$@"
  else
    "$@"
  fi
}

run_skills_add_all() {
  local source_dir="$1"
  local dry_run="$2"
  shift 2
  local cmd=(npx skills add "${source_dir}" -g --skill '*' -y)

  if [[ ${#AGENT_ARGS[@]} -gt 0 ]]; then
    cmd+=("${AGENT_ARGS[@]}")
  fi
  if [[ $# -gt 0 ]]; then
    cmd+=("$@")
  fi

  run_or_print "${dry_run}" "${cmd[@]}"
}

run_skills_remove_global() {
  local dry_run="$1"
  shift
  local cmd=(npx skills remove -g -y)
  local -a names=()
  local -a extra_args=()

  while [[ $# -gt 0 && "${1}" != "--" ]]; do
    names+=("$1")
    shift
  done
  if [[ $# -gt 0 && "${1}" == "--" ]]; then
    shift
  fi
  extra_args=("$@")

  if [[ ${#AGENT_ARGS[@]} -gt 0 ]]; then
    cmd+=("${AGENT_ARGS[@]}")
  fi
  cmd+=("${names[@]}")
  if [[ ${#extra_args[@]} -gt 0 ]]; then
    cmd+=("${extra_args[@]}")
  fi

  run_or_print "${dry_run}" "${cmd[@]}"
}
