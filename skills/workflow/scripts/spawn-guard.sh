#!/bin/sh
# Claude Code PreToolUse hook for Bash (also usable by Codex, same input shape):
# reads the hook JSON on stdin and hands the command to spawn-check.sh.
# Fails open on any parse problem.
in=$(cat 2>/dev/null) || exit 0
cmd=$(printf '%s' "$in" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -n "$cmd" ] || exit 0
exec sh "$(dirname "$0")/spawn-check.sh" "$cmd"
