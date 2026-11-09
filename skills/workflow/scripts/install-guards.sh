#!/bin/sh
# install-guards.sh — installs the spawn guard for Claude Code, Codex and opencode on this machine.
# Idempotent: a second run changes nothing. Backs up each file before editing it (into $BACKUP_DIR).
# Skips an agent that is not installed. JSON is built in a temp file, validated, then moved into place.
# Called by `harness.sh install-guards`. Test overrides: CLAUDE_SETTINGS, CODEX_DIR, OPENCODE_DIR, BACKUP_DIR.
set -e
here=$(cd "$(dirname "$0")" && pwd)
backup=${BACKUP_DIR:-$HOME/.agents/workflow/backups}
claude_settings=${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}
codex_dir=${CODEX_DIR:-$HOME/.codex}
opencode_dir=${OPENCODE_DIR:-$HOME/.config/opencode}
# Quote the path only when it has characters the shell would split or expand, so plain paths keep their exact command.
guard_path=$here/spawn-guard.sh
case $guard_path in
  *[!A-Za-z0-9_./:@%+=,-]*) guard_path="'$(printf '%s' "$guard_path" | sed "s/'/'\\\\''/g")'" ;;
esac
guard="sh $guard_path"
stamp=$(date +%Y%m%d-%H%M%S)

say() { printf '%s\n' "$*"; }
bak() { [ -f "$1" ] || return 0; mkdir -p "$backup"; cp -p "$1" "$backup/$(basename "$1").bak.$stamp"; say "  backup: $backup/$(basename "$1").bak.$stamp"; }

# add_hook <json file> <default json>: put one PreToolUse Bash guard entry in the file. Prints changed|same.
add_hook() {
  f=$1; tmp=$(mktemp)
  [ -f "$f" ] || printf '%s\n' '{}' > "$tmp.in"
  src=$f; [ -f "$f" ] || src="$tmp.in"
  if ! jq --arg c "$guard" '
      .hooks.PreToolUse = ((.hooks.PreToolUse // [])
        | map(if .matcher == "Bash" then .hooks |= map(select((.command // "") | contains("spawn-guard.sh") | not)) else . end)
        | (if any(.[]; .matcher == "Bash") then . else . + [{matcher: "Bash", hooks: []}] end)
        | (map(.matcher == "Bash") | index(true)) as $i
        | .[$i].hooks += [{type: "command", command: $c} + (if $codex then {async: false} else {} end)])
    ' --argjson codex "${2:-false}" "$src" > "$tmp" 2>/dev/null || ! jq -e . "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp" "$tmp.in"; say "  error: could not update $f (left untouched)"; return 1
  fi
  if [ -f "$f" ] && [ "$(jq -S . "$f")" = "$(jq -S . "$tmp")" ]; then rm -f "$tmp" "$tmp.in"; say "  already installed: $f"; return 0; fi
  bak "$f"; mkdir -p "$(dirname "$f")"; mv "$tmp" "$f"; rm -f "$tmp.in"; say "  updated: $f"
}

say "Claude Code:"
if [ -d "$(dirname "$claude_settings")" ] || command -v claude >/dev/null 2>&1; then
  command -v jq >/dev/null 2>&1 && add_hook "$claude_settings" || say "  skipped: jq is required"
else say "  skipped: not installed"; fi

say "Codex:"
if command -v codex >/dev/null 2>&1 || [ -d "$codex_dir" ]; then
  if command -v jq >/dev/null 2>&1; then
    add_hook "$codex_dir/hooks.json" true
    # Codex runs a hook only after it is trusted; trust ours through Codex's own app-server API.
    [ -f "$codex_dir/config.toml" ] || : > "$codex_dir/config.toml"
    if command -v python3 >/dev/null 2>&1 && command -v codex >/dev/null 2>&1; then
      CODEX_HOME=$codex_dir python3 -I - "$codex_dir" "$backup/config.toml.bak.$stamp" <<'PY' || say "  note: could not trust the hook; open Codex and trust it in /hooks"
import json, os, shutil, subprocess, sys
d, bak = sys.argv[1], sys.argv[2]
p = subprocess.Popen(["codex", "app-server"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
def send(m): p.stdin.write(json.dumps(m) + "\n"); p.stdin.flush()
def call(i, method, params):
    send({"id": i, "method": method, "params": params})
    while True:
        l = json.loads(p.stdout.readline())
        if l.get("id") == i: return l
try:
    call(1, "initialize", {"clientInfo": {"name": "install-guards", "version": "1"}})
    send({"method": "initialized"})
    hs = call(2, "hooks/list", {"cwds": [os.getcwd()]})["result"]["data"][0]["hooks"]
    mine = [h for h in hs if "spawn-guard.sh" in h.get("command", "") and os.path.realpath(h["sourcePath"]) == os.path.realpath(d + "/hooks.json")]
    if not mine: raise SystemExit(1)
    todo = [h for h in mine if h["trustStatus"] != "trusted"]
    if todo:
        os.makedirs(os.path.dirname(bak), exist_ok=True)
        shutil.copy2(d + "/config.toml", bak)
        print("  backup: " + bak)
        edits = [{"keyPath": "hooks.state", "value": {h["key"]: {"trusted_hash": h["currentHash"]} for h in todo}, "mergeStrategy": "upsert"}]
        r = call(3, "config/batchWrite", {"edits": edits, "filePath": d + "/config.toml", "reloadUserConfig": True})
        if "error" in r: print("  codex error: " + json.dumps(r["error"])); raise SystemExit(1)
        print("  trusted the hook in " + d + "/config.toml")
    else:
        print("  hook already trusted")
finally:
    p.kill()
PY
    else say "  note: python3 or codex missing; trust the hook in Codex /hooks"; fi
    if [ -n "$CODEX_HOME" ] && [ "$CODEX_HOME" != "$codex_dir" ]; then say "  note: CODEX_HOME=$CODEX_HOME is set in this shell and is not covered (rerun with CODEX_DIR=\$CODEX_HOME)"; fi
  else say "  skipped: jq is required"; fi
else say "  skipped: not installed"; fi

say "opencode:"
if command -v opencode >/dev/null 2>&1 || [ -d "$opencode_dir" ]; then
  dst=$opencode_dir/plugins/workflow-spawn-guard.ts
  new=$(mktemp)
  sed "s|__SPAWN_CHECK__|$here/spawn-check.sh|" "$here/opencode-spawn-guard.ts" > "$new"
  if [ -f "$dst" ] && cmp -s "$new" "$dst"; then say "  already installed: $dst"
  else bak "$dst"; mkdir -p "$(dirname "$dst")"; mv "$new" "$dst"; say "  updated: $dst"; fi
  rm -f "$new"
else say "  skipped: not installed"; fi
