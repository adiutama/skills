#!/bin/sh
# Install, update or uninstall skills from this repo.
#
#   ./install.sh [--runtime bb|claude|codex]... [--dry-run] [skill...]
#   ./install.sh --uninstall [--runtime ...] [--dry-run] skill...
#
# Threat model: install.sh runs as you, in your own home, with normal
# permissions, from a checkout you trust. It protects against mistakes: bad
# skill names, broken or duplicated markers, losing or changing your own text
# in the global instructions, installing over or uninstalling the source, and
# a re-run after an interruption. It does not defend against a filesystem
# deliberately arranged against it (permissions that block removing a link,
# folders planted mid-run, two runs at once); those are documented limits.
#
# Install makes each skill folder in the runtime's skills directory an exact
# copy of the source (rsync -a --delete --checksum, or rm -rf then cp -R
# where rsync is missing), so files a release removed go too. A link or a
# file where that folder belongs is removed first, never what it points to,
# and the run stops before copying if it is still there. A copy that fails
# midway fails the run and leaves that folder partly updated; running the
# install again repairs it. The global instructions file is replaced in one
# step (a new file beside it renamed over it, a linked file keeping its
# link), so an interrupted run leaves it whole, old or new, with at most a
# stray <file>.XXXXXX beside it. Running two installs at once is unsupported.
# If the skill ships init.md, its text goes inline into the runtime's global
# instructions, between markers the script owns:
#
#   <!-- skill:<name> <version> -->
#   ...text of init.md...
#   <!-- /skill:<name> -->
#
# Re-running replaces the block in place; a skill without init.md has its
# block removed. --uninstall removes the folder and the block. Bytes outside
# the markers are kept exactly, apart from the separator the installer owns:
# an appended block gets one blank line before it (or, in a file with no
# final newline, just a newline ending the last line), and removing a block
# takes back only that, so installs and uninstalls in any order restore the
# file. A block removed from the middle takes one blank line with it where two
# would otherwise meet; one that sat right under the text takes the blank line
# before the next block, which moves up into its place. The installer reads
# what it owns from this shape, so blocks moved or spaced by hand may come
# back with a blank line more or less. Each edited file is backed up to
# <file>.bak.
#
# Before changing anything, the script checks every named skill and stops
# with nothing changed when a name is not a folder name (lowercase letters,
# digits, hyphens), when the file holds a broken block of any skill, named or
# not (a start with no end, an end with no start, a block inside another, or
# a skill with two blocks), or when an uninstall would delete the source
# folder (a skills directory linked to this repo). An install whose
# destination is the source keeps the folder and still writes the block. Two
# runtimes linked to one skills directory get one copy and each its block.
#
# With no skill named, install takes every skill whose description does not
# start with "Deprecated". With no --runtime: bb when ~/.bb exists (bb puts its
# AGENTS.md in front of every provider it runs), else each of Claude Code and
# Codex whose home exists.
#
# Runtimes      skills directory             global instructions
#   bb          ~/.bb/skills                 ~/.bb/AGENTS.md
#   claude      ~/.claude/skills             ~/.claude/CLAUDE.md
#   codex       ${CODEX_HOME:-~/.codex}/skills  ${CODEX_HOME:-~/.codex}/AGENTS.md
#
# SKILLS_DIR overrides the source folder (tests). Exit 1 on a usage error,
# an unknown skill, or any of the checks above.

set -eu

here=$(cd "$(dirname "$0")" && pwd)
src=${SKILLS_DIR:-$here/skills}
codex_home=${CODEX_HOME:-$HOME/.codex}

die() { printf 'install: %s\n' "$*" >&2; exit 1; }
# A skill name is a folder name, never a path: no separators, no dot components, no glob characters.
valid_name() { case $1 in ''|-*|*[!a-z0-9-]*) die "invalid skill name: '$1' (lowercase letters, digits and hyphens)" ;; esac; }

uninstall=0 dry=0 runtimes='' skills=''
while [ $# -gt 0 ]; do
  case $1 in
    --uninstall) uninstall=1 ;;
    --dry-run) dry=1 ;;
    --runtime) [ $# -ge 2 ] || die "--runtime needs bb, claude or codex"
      case $2 in bb|claude|codex) runtimes="$runtimes $2" ;; *) die "unknown runtime: $2" ;; esac
      shift ;;
    -h|--help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *) valid_name "$1"; skills="$skills $1" ;;
  esac
  shift
done

skills_dir() { case $1 in bb) echo "$HOME/.bb/skills" ;; claude) echo "$HOME/.claude/skills" ;; codex) echo "$codex_home/skills" ;; esac; }
global_file() { case $1 in bb) echo "$HOME/.bb/AGENTS.md" ;; claude) echo "$HOME/.claude/CLAUDE.md" ;; codex) echo "$codex_home/AGENTS.md" ;; esac; }

if [ -z "$runtimes" ]; then
  if [ -d "$HOME/.bb" ]; then runtimes=bb
  else
    [ ! -d "$HOME/.claude" ] || runtimes="$runtimes claude"
    [ ! -d "$codex_home" ] || runtimes="$runtimes codex"
  fi
  [ -n "$runtimes" ] || die "no runtime found (~/.bb, ~/.claude, ~/.codex); pass --runtime"
fi

frontmatter() { # <file> <key>: the value of a frontmatter key, quotes stripped
  awk -v k="$2" 'NR==1 && $0=="---" {f=1; next} f && $0=="---" {exit}
    f { line=$0; sub(/^[ \t]+/, "", line)
        if (index(line, k ":") == 1) { v=substr(line, length(k)+2); sub(/^[ \t]+/, "", v); gsub(/^"|"$/, "", v); print v; exit } }' "$1"
}

if [ -z "$skills" ]; then
  [ "$uninstall" = 0 ] || die "--uninstall needs the skills to remove"
  for d in "$src"/*/; do
    n=$(basename "$d"); [ -f "$d/SKILL.md" ] || continue
    valid_name "$n"
    case $(frontmatter "$d/SKILL.md" description) in Deprecated*) continue ;; esac
    skills="$skills $n"
  done
fi
if [ "$uninstall" = 0 ]; then
  for n in $skills; do [ -f "$src/$n/SKILL.md" ] || die "unknown skill: $n"; done
fi

run() { if [ "$dry" = 1 ]; then printf 'would: %s\n' "$*"; else "$@"; fi; }

# check_markers <file>: prints what is wrong and fails unless every managed block in the file, of any
# skill, is whole: a start, then its own end, with no other marker between them, and at most one block
# per skill. Checked for the whole file, so a block of a skill that was not named is never cut through.
check_markers() {
  [ -f "$1" ] || return 0
  awk '
    /^<!-- skill:[a-z0-9-]+ / { n = substr($0, 12); sub(/ .*/, "", n)
      if (cur != "") { print "line " NR ": a skill:" n " start marker inside the skill:" cur " block"; bad = 1; exit }
      if (n in seen) { print "line " NR ": a second skill:" n " block"; bad = 1; exit }
      cur = n; seen[n] = 1; next }
    /^<!-- \/skill:[a-z0-9-]+ -->$/ { n = substr($0, 13); sub(/ -->$/, "", n)
      if (cur == "") { print "line " NR ": a skill:" n " end marker with no start"; bad = 1; exit }
      if (n != cur) { print "line " NR ": a skill:" n " end marker inside the skill:" cur " block"; bad = 1; exit }
      cur = "" }
    END { if (bad) exit 1; if (cur != "") { print "the skill:" cur " block has no end marker"; exit 1 } }' "$1"
}

has_block() { [ -f "$1" ] && awk -v s="<!-- skill:$2 " 'index($0, s) == 1 { f=1; exit } END { exit !f }' "$1"; }

# phys <dir>: the directory with every symlink resolved; empty when it does not exist.
phys() { (cd "$1" 2>/dev/null && pwd -P) || true; }
# is_source <dest folder> <skill>: the installed folder is the source itself (a real folder reached through a linked skills directory).
is_source() { [ -d "$1" ] && [ ! -L "$1" ] && [ -n "$(phys "$1")" ] && [ "$(phys "$1")" = "$(phys "$src/$2")" ]; }
src_root=$(phys "$src")

# set_block <file> <name> <block file or empty>: replace the skill's block in
# place, append it when absent, or remove it when the block file is empty.
# check_markers has passed for the file.
set_block() {
  f=$1 name=$2 blk=$3
  if [ -z "$blk" ] && ! has_block "$f" "$name"; then return 0; fi
  tmp=$(mktemp)
  if [ -f "$f" ]; then
    nl=1; [ -z "$(tail -c 1 "$f")" ] || nl=0
    awk -v s="<!-- skill:$name " -v e="<!-- /skill:$name -->" -v b="$blk" -v nl="$nl" '
      { line[NR] = $0 }
      END {
        # Lines outside the block are copied as they are. An append separates the block with one blank
        # line, or, when the file has no final newline, only ends its last line; removing a block gives
        # back exactly that. Inside the file it drops one blank line where two would meet, or the blank
        # line between it and the next block when it sat right under the text.
        m = 0; found = 0; last = -1
        for (i = 1; i <= NR; i++) {
          if (!found && index(line[i], s) == 1) {
            found = 1
            while (i < NR && line[i] != e) i++
            if (b != "") { while ((getline l < b) > 0) o[++m] = l; close(b); last = m; if (i >= NR) nl = 1 }
            else if (i < NR) {
              if (m > 0 && o[m] == "" && line[i + 1] == "") i++
              # A block right under the text (or at the top) hands that place to the next block: the blank line
              # between the two blocks was a separator the installer added, so the next block takes this place.
              else if ((m == 0 || o[m] != "") && line[i + 1] == "" && index(line[i + 2], "<!-- skill:") == 1) i++
            }
            else if (m > 0 && o[m] == "") { m--; nl = 1 }
            else if (m > 0) nl = 0
            continue
          }
          o[++m] = line[i]
        }
        if (!found && b != "") {
          if (m > 0 && nl) o[++m] = ""
          while ((getline l < b) > 0) o[++m] = l; close(b); last = m
        }
        for (j = 1; j <= m; j++) printf "%s%s", o[j], (j < m || nl || last == m ? "\n" : "")
      }' "$f" > "$tmp"
  else
    cat "$blk" > "$tmp"
  fi
  if [ -f "$f" ] && cmp -s "$f" "$tmp"; then rm -f "$tmp"; return 0; fi
  if [ "$dry" = 1 ]; then printf 'would: update %s (skill:%s)\n' "$f" "$name"; rm -f "$tmp"; return 0; fi
  # The new text goes into a file beside the real one (a linked file keeps its link) that is then renamed over it, in one
  # step: an interrupted run leaves the old file or the new one, never part of either, and the backup is of a whole file.
  real=$f; while [ -L "$real" ]; do l=$(readlink "$real"); case $l in /*) real=$l ;; *) real=$(dirname "$real")/$l ;; esac; done
  mkdir -p "$(dirname "$real")"; new=$(mktemp "$real.XXXXXX")
  if [ -f "$real" ]; then cp "$real" "$f.bak"; cp -p "$real" "$new"; fi  # -p: the new file keeps the old one's mode
  cat "$tmp" > "$new"; mv -f "$new" "$real"; rm -f "$tmp"
  printf 'updated %s (skill:%s)\n' "$f" "$name"
}

# Every check runs before the first change, so a refused run changes nothing.
for rt in $runtimes; do
  dest=$(skills_dir "$rt") gf=$(global_file "$rt")
  msg=$(check_markers "$gf") || die "$gf: $msg; fix it by hand (nothing was changed)"
  for n in $skills; do
    if [ "$uninstall" = 1 ] && { [ "$(phys "$dest")" = "$src_root" ] || is_source "$dest/$n" "$n"; }; then
      die "$dest/$n is the source folder itself; refusing to delete it (nothing was changed)"
    fi
    if [ "$uninstall" = 0 ] && [ -d "$dest" ] && [ ! -w "$dest" ] && { [ -L "$dest/$n" ] || { [ -e "$dest/$n" ] && [ ! -d "$dest/$n" ]; }; }; then
      die "$dest/$n is a link or a file in a folder you cannot write, so it cannot be replaced; remove it by hand (nothing was changed)"
    fi
  done
done

# copy <source folder> <dest folder>: make the destination an exact copy, in place. A link or a file there is
# removed first (only the link, never what it points to), so the copy never writes through it; if it is still
# there, the run stops before copying.
copy() {
  if [ -L "$2" ] || { [ -e "$2" ] && [ ! -d "$2" ]; }; then
    rm -f "$2" || true
    if [ -L "$2" ] || [ -e "$2" ]; then die "could not remove the link or file $2, so nothing was copied through it; remove it and run the install again"; fi
  fi
  if command -v rsync >/dev/null 2>&1; then rsync -a --delete --checksum "$1/" "$2/"
  else rm -rf "$2" && cp -R "$1" "$2"; fi
}

# Runtimes linked to one skills directory copy each skill into it once: one "<physical dir>/<skill>" per line.
copied='
'
for rt in $runtimes; do
  dest=$(skills_dir "$rt") gf=$(global_file "$rt")
  for n in $skills; do
    if [ "$uninstall" = 1 ]; then
      if [ -e "$dest/$n" ] || [ -L "$dest/$n" ]; then run rm -rf "$dest/$n"; [ "$dry" = 1 ] || printf 'removed %s\n' "$dest/$n"; fi
      set_block "$gf" "$n" ''
      continue
    fi
    v=$(frontmatter "$src/$n/SKILL.md" version)
    if is_source "$dest/$n" "$n"; then
      printf 'kept %s: it is the source folder\n' "$dest/$n"
    elif [ "$dry" = 1 ]; then
      printf 'would: install %s %s → %s\n' "$n" "${v:-?}" "$dest/$n"
    else
      mkdir -p "$dest"; key=$(phys "$dest")/$n
      case $copied in *"
$key
"*) ;; *) copy "$src/$n" "$dest/$n" || die "copying $n into $dest/$n failed; run the install again to finish it"
          copied="$copied$key
" ;; esac
      printf 'installed %s %s → %s\n' "$n" "${v:-?}" "$dest/$n"
    fi
    if [ -f "$src/$n/init.md" ]; then
      blk=$(mktemp)
      { printf '<!-- skill:%s %s -->\n' "$n" "${v:-?}"; cat "$src/$n/init.md"; [ -z "$(tail -c 1 "$src/$n/init.md")" ] || echo; printf '<!-- /skill:%s -->\n' "$n"; } > "$blk"
      set_block "$gf" "$n" "$blk"; rm -f "$blk"
    else
      set_block "$gf" "$n" ''
    fi
  done
done
