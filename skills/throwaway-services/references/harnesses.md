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

Each term means what your harness's column says, everywhere in this skill and its references.

| Term | Meaning | bb | Claude Code | Codex | none |
|---|---|---|---|---|---|
| home | directory holding every set, shared by all conversations so any of them can see and stop a set | `~/.agents/throwaway-services` | `~/.agents/throwaway-services` | `~/.agents/throwaway-services` | `~/.agents/throwaway-services` |
| invoke | the command that calls this skill | `/throwaway-services` under Claude Code · `$throwaway-services` under Codex | `/throwaway-services` | `$throwaway-services` (or pick it from `/skills`) | the skill's name |

## Setup

Keep this skill explicit-only (it must not load on its own):

| Harness | Setting |
|---|---|
| Claude Code | `disable-model-invocation: true` in the `SKILL.md` frontmatter |
| Codex | `policy.allow_implicit_invocation: false` in `agents/openai.yaml` |
