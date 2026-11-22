#!/bin/sh
# Checks install.sh against a fake HOME and a fixture skills folder.
set -u
here=$(cd "$(dirname "$0")" && pwd)
pass=0 fail=0
ok() { pass=$((pass+1)); }
no() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
check() { if eval "$2"; then ok; else no "$1"; fi; }

setup() {
  T=$(mktemp -d); export HOME=$T/home SKILLS_DIR=$T/src; unset CODEX_HOME
  mkdir -p "$HOME/.bb" "$SKILLS_DIR"
  mk alpha 1.0.0 'Does alpha.' 'Alpha rule.'
  mk beta 2.0.0 'Does beta.' ''
  mk old 1.0.0 'Deprecated: merged into alpha.' 'Old rule.'
  printf '# Mine\n\nMy rule.\n' > "$HOME/.bb/AGENTS.md"
}
mk() { # name version description init-text
  mkdir -p "$SKILLS_DIR/$1"
  printf -- '---\nname: %s\ndescription: "%s"\nmetadata:\n  version: "%s"\n---\n' "$1" "$3" "$2" > "$SKILLS_DIR/$1/SKILL.md"
  rm -f "$SKILLS_DIR/$1/init.md"; [ -z "$4" ] || printf '%s\n' "$4" > "$SKILLS_DIR/$1/init.md"
}
I() { sh "$here/install.sh" "$@" >/dev/null 2>&1; }
A=; agents() { A=$(cat "$HOME/.bb/AGENTS.md"); }

# 1 install all: non-deprecated folders copied, block inline with version, own text kept
setup; I; agents
check "1 folders" '[ -f "$HOME/.bb/skills/alpha/SKILL.md" ] && [ -f "$HOME/.bb/skills/beta/SKILL.md" ] && [ ! -e "$HOME/.bb/skills/old" ]'
check "1 block" '[ "$A" = "$(printf "# Mine\n\nMy rule.\n\n<!-- skill:alpha 1.0.0 -->\nAlpha rule.\n<!-- /skill:alpha -->")" ]'
check "1 no block for a skill without init.md" '! grep -q "skill:beta" "$HOME/.bb/AGENTS.md"'
check "1 backup" '[ "$(cat "$HOME/.bb/AGENTS.md.bak")" = "$(printf "# Mine\n\nMy rule.")" ]'

# 2 re-run changes nothing
cp "$HOME/.bb/AGENTS.md" "$T/before"; I
check "2 idempotent" 'cmp -s "$T/before" "$HOME/.bb/AGENTS.md"'

# 3 update replaces the block in place; text after it stays after it
printf '\nAfter.\n' >> "$HOME/.bb/AGENTS.md"
mk alpha 1.1.0 'Does alpha.' 'Alpha rule, new.'; I alpha; agents
check "3 replaced in place" '[ "$A" = "$(printf "# Mine\n\nMy rule.\n\n<!-- skill:alpha 1.1.0 -->\nAlpha rule, new.\n<!-- /skill:alpha -->\n\nAfter.")" ]'
check "3 one block" '[ "$(grep -c "skill:alpha" "$HOME/.bb/AGENTS.md")" = 2 ]'

# 4 a release drops init.md: the block goes, no gap left
mk alpha 1.2.0 'Does alpha.' ''; I alpha; agents
check "4 block removed" '[ "$A" = "$(printf "# Mine\n\nMy rule.\n\nAfter.")" ]'

# 5 a file a release removed goes from the installed copy
touch "$SKILLS_DIR/beta/stale.sh"; I beta; rm "$SKILLS_DIR/beta/stale.sh"; I beta
check "5 stale file removed" '[ ! -e "$HOME/.bb/skills/beta/stale.sh" ]'

# 6 uninstall removes folder and block, keeps own text exactly
setup; I; I --uninstall alpha; agents
check "6 folder gone" '[ ! -e "$HOME/.bb/skills/alpha" ] && [ -e "$HOME/.bb/skills/beta" ]'
check "6 text restored" '[ "$A" = "$(printf "# Mine\n\nMy rule.")" ]'
check "6 uninstall needs names" '! I --uninstall'

# 7 a deprecated skill installs when named
setup; I old
check "7 named deprecated" '[ -f "$HOME/.bb/skills/old/SKILL.md" ] && grep -q "skill:old 1.0.0" "$HOME/.bb/AGENTS.md"'

# 8 errors: unknown skill or runtime, missing end marker (file untouched)
setup
check "8 unknown skill" '! I nope'
check "8 unknown runtime" '! I --runtime vim'
printf '<!-- skill:alpha 1.0.0 -->\nhalf\n' >> "$HOME/.bb/AGENTS.md"; cp "$HOME/.bb/AGENTS.md" "$T/before"
check "8 missing end marker" '! I alpha && cmp -s "$T/before" "$HOME/.bb/AGENTS.md"'

# 9 dry run touches nothing
setup; cp "$HOME/.bb/AGENTS.md" "$T/before"; I --dry-run
check "9 dry run" '[ ! -e "$HOME/.bb/skills" ] && cmp -s "$T/before" "$HOME/.bb/AGENTS.md"'

# 10 runtime choice: bb wins when ~/.bb exists; else Claude Code and Codex; --runtime picks
setup; mkdir -p "$HOME/.claude"; I
check "10 bb only" '[ ! -e "$HOME/.claude/skills" ]'
rm -rf "$HOME/.bb"; mkdir -p "$HOME/.codex"; I
check "10 claude and codex" 'grep -q "skill:alpha" "$HOME/.claude/CLAUDE.md" && grep -q "skill:alpha" "$HOME/.codex/AGENTS.md" && [ -f "$HOME/.claude/skills/alpha/SKILL.md" ]'
setup; export CODEX_HOME=$T/cx; I --runtime codex
check "10 CODEX_HOME" '[ -f "$T/cx/skills/alpha/SKILL.md" ] && grep -q "skill:alpha" "$T/cx/AGENTS.md" && [ ! -e "$HOME/.bb/skills" ]'

# 11 the real workflow skill ships an init.md that installs
setup; export SKILLS_DIR=$here/skills; I workflow
check "11 workflow block" 'grep -q "<!-- skill:workflow " "$HOME/.bb/AGENTS.md" && grep -q "load the \`workflow\` skill" "$HOME/.bb/AGENTS.md"'

# 12 C1: a skill name is a folder name, never a path; nothing outside the skills tree goes
setup; I; mkdir -p "$HOME/.bb/keep"; touch "$HOME/.bb/keep/sentinel"
check "12 uninstall ../ refused" '! I --uninstall ../keep && [ -f "$HOME/.bb/keep/sentinel" ]'
check "12 uninstall ../../ refused" '! I --uninstall ../../.bb/keep && [ -f "$HOME/.bb/keep/sentinel" ]'
check "12 dot names refused" '! I --uninstall . && ! I --uninstall .. && [ -f "$HOME/.bb/skills/alpha/SKILL.md" ]'
check "12 glob refused" '! I --uninstall "*" && [ -f "$HOME/.bb/skills/alpha/SKILL.md" ]'
check "12 install path refused" '! I ../src/alpha'

# 13 C2: broken or duplicate markers stop the run before any change, to the skill folder or the file
for bad in 'A\n<!-- skill:alpha 1.0.0 -->\nAlpha rule.\n<!-- /skill:alpha -->\nB\n<!-- skill:alpha 1.0.0 -->\nC\n' \
           'A\n<!-- skill:alpha 1.0.0 -->\n1\n<!-- /skill:alpha -->\n<!-- skill:alpha 1.0.0 -->\n2\n<!-- /skill:alpha -->\n' \
           'A\n<!-- skill:alpha 1.0.0 -->\n<!-- skill:alpha 1.0.0 -->\nx\n<!-- /skill:alpha -->\n' \
           'A\n<!-- /skill:alpha -->\nB\n' \
           'A\n<!-- /skill:alpha -->\n<!-- skill:alpha 1.0.0 -->\nB\n'; do
  setup; I; printf "$bad" > "$HOME/.bb/AGENTS.md"; cp "$HOME/.bb/AGENTS.md" "$T/before"; cp -R "$HOME/.bb/skills" "$T/skills-before"
  mk alpha 1.1.0 'Does alpha.' 'Alpha rule, new.'; touch "$SKILLS_DIR/alpha/new.sh"
  check "13 install refused: $bad" '! I alpha && cmp -s "$T/before" "$HOME/.bb/AGENTS.md" && diff -r "$T/skills-before" "$HOME/.bb/skills" >/dev/null'
  check "13 uninstall refused: $bad" '! I --uninstall alpha && cmp -s "$T/before" "$HOME/.bb/AGENTS.md" && [ -f "$HOME/.bb/skills/alpha/SKILL.md" ]'
done
setup; I; printf '<!-- skill:beta 1.0.0 -->\nhalf\n' >> "$HOME/.bb/AGENTS.md"; mk alpha 1.1.0 'Does alpha.' 'Alpha rule.'; I alpha beta
check "13 one broken block stops the whole run" 'grep -q "skill:alpha 1.0.0" "$HOME/.bb/AGENTS.md" && ! grep -q "version: \"1.1.0\"" "$HOME/.bb/skills/alpha/SKILL.md"'

# 14 C3: a skills directory that is the source (a symlink) never deletes the source
setup; ln -s "$SKILLS_DIR" "$HOME/.bb/skills"; touch "$SKILLS_DIR/alpha/sentinel"
check "14 install through an alias keeps the source" 'I alpha && [ -f "$SKILLS_DIR/alpha/sentinel" ] && [ -f "$SKILLS_DIR/alpha/SKILL.md" ] && grep -q "skill:alpha 1.0.0" "$HOME/.bb/AGENTS.md"'
check "14 uninstall through an alias refused" '! I --uninstall alpha && [ -f "$SKILLS_DIR/alpha/sentinel" ]'
check "14 uninstall through an alias refused for a skill the source lacks" '! I --uninstall ghost && [ -f "$SKILLS_DIR/alpha/sentinel" ]'
setup; mkdir -p "$HOME/.bb/skills"; ln -s "$SKILLS_DIR/alpha" "$HOME/.bb/skills/alpha"; touch "$SKILLS_DIR/alpha/sentinel"
check "14 a linked skill folder keeps the source" 'I alpha && [ -f "$SKILLS_DIR/alpha/sentinel" ] && [ -f "$HOME/.bb/skills/alpha/SKILL.md" ]'

# 15 W1: bytes outside the owned block are kept exactly
setup; printf '# Mine\n\nMy rule.\n\n\n' > "$HOME/.bb/AGENTS.md"; cp "$HOME/.bb/AGENTS.md" "$T/before"; I beta
check "15 removing an absent block changes nothing" 'cmp -s "$T/before" "$HOME/.bb/AGENTS.md" && [ ! -e "$HOME/.bb/AGENTS.md.bak" ]'
printf 'no final newline' > "$HOME/.bb/AGENTS.md"; cp "$HOME/.bb/AGENTS.md" "$T/before"; I --uninstall alpha
check "15 uninstall without a block changes nothing" 'cmp -s "$T/before" "$HOME/.bb/AGENTS.md"'
printf '\n\n# Mine\n\n<!-- skill:alpha 0.9.0 -->\nold\n<!-- /skill:alpha -->\n\n\nAfter.\n\n\n' > "$HOME/.bb/AGENTS.md"; I alpha
printf '\n\n# Mine\n\n<!-- skill:alpha 1.0.0 -->\nAlpha rule.\n<!-- /skill:alpha -->\n\n\nAfter.\n\n\n' > "$T/want"
check "15 replace keeps leading, inner and trailing blank lines" 'cmp -s "$T/want" "$HOME/.bb/AGENTS.md"'
printf 'Top\n<!-- skill:alpha 0.9.0 -->\nold\n<!-- /skill:alpha -->\nEnd' > "$HOME/.bb/AGENTS.md"; I alpha
check "15 replace keeps a missing final newline" '[ "$(tail -c 3 "$HOME/.bb/AGENTS.md")" = End ] && grep -q "skill:alpha 1.0.0" "$HOME/.bb/AGENTS.md"'
printf '# Mine\n\n\n' > "$HOME/.bb/AGENTS.md"; cp "$HOME/.bb/AGENTS.md" "$T/before"; I alpha; I --uninstall alpha
check "15 install then uninstall restores the bytes" 'cmp -s "$T/before" "$HOME/.bb/AGENTS.md"'

# 16 C2 (round 2): a block of another skill crossing the requested one stops the run, even when that skill is not named
for bad in 'A\n<!-- skill:alpha 1.0.0 -->\nAlpha rule.\n<!-- skill:evidence 1.0.0 -->\nE\n<!-- /skill:evidence -->\n<!-- /skill:alpha -->\nB\n' \
           'A\n<!-- skill:alpha 1.0.0 -->\nAlpha rule.\n<!-- skill:evidence 1.0.0 -->\nE\n<!-- /skill:alpha -->\n<!-- /skill:evidence -->\n' \
           'A\n<!-- skill:evidence 1.0.0 -->\nE\n<!-- skill:alpha 1.0.0 -->\nAlpha rule.\n<!-- /skill:alpha -->\n<!-- /skill:evidence -->\n' \
           'A\n<!-- skill:alpha 1.0.0 -->\nAlpha rule.\n<!-- /skill:evidence -->\n<!-- /skill:alpha -->\n'; do
  setup; I; mkdir -p "$HOME/.bb/skills/evidence"; touch "$HOME/.bb/skills/evidence/sentinel"
  printf "$bad" > "$HOME/.bb/AGENTS.md"; cp "$HOME/.bb/AGENTS.md" "$T/before"; cp -R "$HOME/.bb/skills" "$T/skills-before"
  mk alpha 1.1.0 'Does alpha.' 'Alpha rule, new.'
  check "16 install refused: $bad" '! I alpha && cmp -s "$T/before" "$HOME/.bb/AGENTS.md" && diff -r "$T/skills-before" "$HOME/.bb/skills" >/dev/null'
  check "16 uninstall refused: $bad" '! I --uninstall alpha && cmp -s "$T/before" "$HOME/.bb/AGENTS.md" && diff -r "$T/skills-before" "$HOME/.bb/skills" >/dev/null'
done
setup; printf '# Mine\n\n<!-- skill:evidence 1.0.0 -->\nE\n<!-- /skill:evidence -->\n' > "$HOME/.bb/AGENTS.md"; I alpha; I --uninstall alpha
check "16 a separate block of another skill is kept" '[ "$(cat "$HOME/.bb/AGENTS.md")" = "$(printf "# Mine\n\n<!-- skill:evidence 1.0.0 -->\nE\n<!-- /skill:evidence -->")" ]'

# 17 W1 (round 2): an install then uninstall gives back the exact bytes, and a removed block takes only the separator the installer owns
for orig in '# Mine' '# Mine\n' '# Mine\n\n' '' 'A\n\nB'; do
  setup; printf "$orig" > "$HOME/.bb/AGENTS.md"; cp "$HOME/.bb/AGENTS.md" "$T/before"; I alpha; I --uninstall alpha
  check "17 round trip keeps the bytes: '$orig'" 'cmp -s "$T/before" "$HOME/.bb/AGENTS.md"'
done
setup; printf 'A\n<!-- skill:alpha 0.9.0 -->\nold\n<!-- /skill:alpha -->\n\nB\n' > "$HOME/.bb/AGENTS.md"; I --uninstall alpha; printf 'A\n\nB\n' > "$T/want"
check "17 a blank line the user put after a block is kept" 'cmp -s "$T/want" "$HOME/.bb/AGENTS.md"'
setup; printf 'A\n\n<!-- skill:alpha 0.9.0 -->\nold\n<!-- /skill:alpha -->\nB\n' > "$HOME/.bb/AGENTS.md"; I --uninstall alpha; printf 'A\n\nB\n' > "$T/want"
check "17 a blank line the user put before a block is kept" 'cmp -s "$T/want" "$HOME/.bb/AGENTS.md"'
setup; printf 'A\n\n<!-- skill:alpha 0.9.0 -->\nold\n<!-- /skill:alpha -->\n\nB\n' > "$HOME/.bb/AGENTS.md"; I --uninstall alpha; printf 'A\n\nB\n' > "$T/want"
check "17 two blank lines around a removed block become one" 'cmp -s "$T/want" "$HOME/.bb/AGENTS.md"'

# 18 W1 (round 3): with two or three blocks, uninstalling in any order gives back the exact bytes
for orig in '# Mine' '# Mine\n' '# Mine\n\n' '' 'A\n\nB'; do
  for order in 'alpha gamma' 'gamma alpha'; do
    setup; mk gamma 1.0.0 'Does gamma.' 'Gamma rule.'; printf "$orig" > "$HOME/.bb/AGENTS.md"; cp "$HOME/.bb/AGENTS.md" "$T/before"
    I alpha; I gamma; for n in $order; do I --uninstall "$n"; done
    check "18 two blocks, uninstalled $order, keep the bytes: '$orig'" 'cmp -s "$T/before" "$HOME/.bb/AGENTS.md"'
  done
  setup; mk gamma 1.0.0 'Does gamma.' 'Gamma rule.'; mk delta 1.0.0 'Does delta.' 'Delta rule.'; printf "$orig" > "$HOME/.bb/AGENTS.md"; cp "$HOME/.bb/AGENTS.md" "$T/before"
  I alpha; I gamma; I delta; I --uninstall gamma; I --uninstall alpha; I --uninstall delta
  check "18 three blocks, the middle one first, keep the bytes: '$orig'" 'cmp -s "$T/before" "$HOME/.bb/AGENTS.md"'
done
setup; mk gamma 1.0.0 'Does gamma.' 'Gamma rule.'; printf '# Mine' > "$HOME/.bb/AGENTS.md"; I alpha; I gamma; I --uninstall alpha
printf '# Mine\n<!-- skill:gamma 1.0.0 -->\nGamma rule.\n<!-- /skill:gamma -->\n' > "$T/want"
check "18 the next block moves up into the removed block's place" 'cmp -s "$T/want" "$HOME/.bb/AGENTS.md"'

# 19 a skill is updated in place: a failed copy fails the run, and a re-run after a partial copy restores the exact tree
setup; I alpha; mk alpha 1.1.0 'Does alpha.' 'Alpha rule, new.'; printf x > "$SKILLS_DIR/alpha/unreadable"; chmod 000 "$SKILLS_DIR/alpha/unreadable"
check "19 a failed copy fails the run" '! I alpha'
chmod 644 "$SKILLS_DIR/alpha/unreadable"; I alpha
check "19 the re-run after a failed copy gives the exact tree" 'diff -r "$SKILLS_DIR/alpha" "$HOME/.bb/skills/alpha" >/dev/null'
D=$HOME/.bb/skills/alpha; mkdir -p "$SKILLS_DIR/alpha/sub"; printf 'kept\n' > "$SKILLS_DIR/alpha/sub/f"; I alpha
rm "$D/sub/f"; printf 'half' > "$D/SKILL.md"; mkdir "$D/stray"; touch "$D/stray/x" "$D/extra"; I alpha
check "19 a re-run after a partial copy restores the exact tree" 'diff -r "$SKILLS_DIR/alpha" "$D" >/dev/null'
mkdir -p "$T/norsync"; for c in awk basename cat cmp cp dirname mkdir mktemp mv readlink rm tail; do ln -s "$(command -v $c)" "$T/norsync/$c"; done
rm -rf "$D/sub"; touch "$D/extra"; PATH=$T/norsync /bin/sh "$here/install.sh" alpha >/dev/null 2>&1; rc=$?
check "19 without rsync the copy falls back to rm and cp" '[ "$rc" = 0 ] && diff -r "$SKILLS_DIR/alpha" "$D" >/dev/null'

# 20 W16: runtimes sharing one skills directory get one copy and each still gets its global instructions
setup; mkdir -p "$T/shared" "$HOME/.claude"; ln -s "$T/shared" "$HOME/.bb/skills"; ln -s "$T/shared" "$HOME/.claude/skills"
check "20 two runtimes linked to one directory install" 'I --runtime bb --runtime claude alpha && [ -f "$T/shared/alpha/SKILL.md" ] && grep -q "skill:alpha" "$HOME/.bb/AGENTS.md" && grep -q "skill:alpha" "$HOME/.claude/CLAUDE.md"'
check "20 a runtime named twice installs" 'I --runtime bb --runtime bb alpha'
check "20 the shared directory holds the exact tree" 'diff -r "$SKILLS_DIR/alpha" "$T/shared/alpha" >/dev/null'

# 21 C7: a link where a skill folder belongs that cannot be removed stops the run before copying; nothing is written through it
setup; I alpha; cp "$HOME/.bb/AGENTS.md" "$T/before"; mk alpha 1.1.0 'Does alpha.' 'Alpha rule, new.'
mkdir -p "$T/outside"; printf 'keep\n' > "$T/outside/sentinel"; rm -rf "$HOME/.bb/skills/alpha"; ln -s "$T/outside" "$HOME/.bb/skills/alpha"
chmod 555 "$HOME/.bb/skills"; I alpha; rc=$?; chmod 755 "$HOME/.bb/skills"
check "21 a link in a folder you cannot write stops the run" '[ "$rc" = 1 ] && [ -L "$HOME/.bb/skills/alpha" ]'
check "21 nothing is copied through the link and nothing else changes" '[ "$(cat "$T/outside/sentinel")" = keep ] && [ ! -e "$T/outside/SKILL.md" ] && cmp -s "$T/before" "$HOME/.bb/AGENTS.md"'
if command -v chflags >/dev/null 2>&1 && chflags -h uchg "$HOME/.bb/skills/alpha" 2>/dev/null; then
  I alpha; rc=$?; chflags -h nouchg "$HOME/.bb/skills/alpha"
  check "21 a link that rm cannot remove in a writable folder stops before copying" '[ "$rc" = 1 ] && [ "$(cat "$T/outside/sentinel")" = keep ] && [ ! -e "$T/outside/SKILL.md" ]'
fi
I alpha
check "21 once the link can go, the install replaces it with the folder" '[ ! -L "$HOME/.bb/skills/alpha" ] && diff -r "$SKILLS_DIR/alpha" "$HOME/.bb/skills/alpha" >/dev/null && [ -f "$T/outside/sentinel" ]'

# 22 W21: a run killed while it writes the global instructions leaves the old file whole, and the re-run keeps a whole backup.
# The stand-in cat writes 10 bytes of the new text and kills the installer, wherever the installer writes that text.
setup; I alpha; cp "$HOME/.bb/AGENTS.md" "$T/before"; mk alpha 1.1.0 'Does alpha.' 'Alpha rule, new.'
mkdir -p "$T/killcat"; printf '#!/bin/sh\ncase $1 in */init.md) exec /bin/cat "$@" ;; esac\nhead -c 10 "$1"; kill -9 $PPID\n' > "$T/killcat/cat"; chmod +x "$T/killcat/cat"
( PATH=$T/killcat:$PATH sh "$here/install.sh" alpha >/dev/null 2>&1; true ) 2>/dev/null
check "22 an interrupted write leaves the old file whole" 'cmp -s "$T/before" "$HOME/.bb/AGENTS.md"'
I alpha
check "22 the re-run writes the new block and backs up the whole old file" 'grep -q "skill:alpha 1.1.0" "$HOME/.bb/AGENTS.md" && cmp -s "$T/before" "$HOME/.bb/AGENTS.md.bak"'
setup; mkdir -p "$T/dot"; mv "$HOME/.bb/AGENTS.md" "$T/dot/AGENTS.md"; chmod 640 "$T/dot/AGENTS.md"; ln -s ../../dot/AGENTS.md "$HOME/.bb/AGENTS.md"; I alpha
check "22 a linked global file keeps its link and its mode; the text lands in its target" '[ -L "$HOME/.bb/AGENTS.md" ] && grep -q "skill:alpha" "$T/dot/AGENTS.md" && [ "$(ls -l "$T/dot/AGENTS.md" | cut -c1-10)" = "-rw-r-----" ]'

printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
