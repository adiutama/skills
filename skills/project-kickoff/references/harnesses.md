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
| source link | how the brief cites the conversation it came from | `@thread:<BB_THREAD_ID>` | "a Claude Code session on <date>" | "a Codex session on <date>" | "a conversation on <date>" |
| register | make the new folder a place the user can open new conversations in | `bb project create --name "<Project name>" --root <folder>`, then give the user the project id | nothing to do | nothing to do | nothing to do |

## Setup

This skill loads on its own when the user asks for a new project:

| Harness | Setting |
|---|---|
| Claude Code | no `disable-model-invocation` in the `SKILL.md` frontmatter |
| Codex | `policy.allow_implicit_invocation: true` in `agents/openai.yaml` |
