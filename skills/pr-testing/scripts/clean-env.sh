#!/bin/sh
# clean-env.sh — run a command with none of the caller's environment except the basics,
# so real-provider credentials in the agent's shell never reach the app under test.
#
#   clean-env.sh [--env FILE]... [--set KEY=VALUE]... -- CMD [ARG]...
#
# Kept from the caller: PATH HOME USER LOGNAME SHELL TMPDIR LANG LC_ALL TERM.
# Then each --env file is sourced in order (dotenv KEY=value lines, exported),
# then each --set. Later wins. Files are read by the shell, never printed.
set -e

die() { printf '%s\n' "$*" >&2; exit 1; }

files= sets=
while [ $# -gt 0 ]; do
  case $1 in
    --env) [ -f "$2" ] || die "clean-env: no such env file: $2"; files="$files
$2"; shift ;;
    --set) case $2 in [A-Za-z_]*=*) ;; *) die "clean-env: --set needs KEY=VALUE" ;; esac
           sets="$sets
$2"; shift ;;
    --) shift; break ;;
    *) die "clean-env: unknown argument $1 (clean-env.sh [--env FILE]... [--set K=V]... -- CMD...)" ;;
  esac; shift
done
[ $# -gt 0 ] || die "clean-env: no command"

exec env -i \
  PATH="$PATH" HOME="$HOME" USER="${USER:-}" LOGNAME="${LOGNAME:-}" SHELL=/bin/sh \
  TMPDIR="${TMPDIR:-/tmp}" LANG="${LANG:-C.UTF-8}" ${LC_ALL:+LC_ALL="$LC_ALL"} TERM="${TERM:-dumb}" \
  CLEAN_ENV_FILES="$files" CLEAN_ENV_SETS="$sets" \
  /bin/sh -c '
    set -a
    IFS="
"
    for f in $CLEAN_ENV_FILES; do [ -n "$f" ] && . "$f"; done
    for kv in $CLEAN_ENV_SETS; do [ -n "$kv" ] && export "$kv"; done
    unset CLEAN_ENV_FILES CLEAN_ENV_SETS IFS
    set +a
    exec "$@"
  ' clean-env "$@"
