# Harnesses

## Detect

Read the environment with one shell call (`echo "$BB_THREAD_ID|$CLAUDECODE"`), then check top to bottom; the first match is your harness.

| Harness | Signal |
|---|---|
| bb | `BB_THREAD_ID` is set |
| Claude Code | `CLAUDECODE=1` |
| Codex | you are Codex (your system prompt or tool list says so) |
| none | no match |

bb runs Claude Code or Codex inside it; the bb column names both where they differ.

## Glossary

Each term means what your harness's column says, everywhere in this skill.

| Term | Meaning | bb | Claude Code | Codex | none |
|---|---|---|---|---|---|
| home | directory for evidence, outside any repo, shared by all conversations | `~/.agents/evidence` | `~/.agents/evidence` | `~/.agents/evidence` | `~/.agents/evidence` |
| screenshot | how to open a page, perform steps, and capture it | bb browser automation (follow the `browser-automation` skill if available): `bb browser-automation open --backend local --headless --machine <this host>`, steps via `bb browser-automation run <session> --script …`, then `bb browser-automation screenshot <session>` (JPEG) and copy the returned file to `<E>`; `close` the session after | Playwright: no steps → `npx playwright screenshot --viewport-size=1280,800 [--full-page] [--wait-for-selector <sel>] <url> <file>`; steps → a short Playwright script in `<E>/.scripts/` run with `node` | as Claude Code | as Claude Code; Playwright missing → ask before installing it (`npx playwright install chromium`) |
| invoke | the command that calls this skill | `/evidence` under Claude Code · `$evidence` under Codex | `/evidence` | `$evidence` (or pick it from `/skills`) | the skill's name |

## Setup

Keep this skill explicit-only (it must not load on its own):

| Harness | Setting |
|---|---|
| Claude Code | `disable-model-invocation: true` in the `SKILL.md` frontmatter |
| Codex | `policy.allow_implicit_invocation: false` in `agents/openai.yaml` |
