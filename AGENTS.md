# Agent Instructions

## Layout

- Each skill lives in `skills/<skill-name>/SKILL.md`, following the [agentskills.io](https://agentskills.io/) standard. Supporting files go in the same folder.
- `name` in the frontmatter must match the folder name.
- No taglines, mottos, or poetic lines; every sentence must change what the agent does.
- Name skills as nouns (`pr-review`, `throwaway-services`). A skill the user invokes takes its action as the first argument (`/pr-review submit W1`, `/throwaway-services stop`), with the main action as the default.

## Versioning

Every skill carries a semver version in its frontmatter:

```yaml
---
name: example-skill
description: ...
metadata:
  version: "1.0.0"
---
```

- A new skill starts at `1.0.0`.
- Bump the version only at a release: when the change is about to be pushed or merged, not on every commit or round of feedback. Work in progress commits without a bump; at the release, one commit bumps each changed skill once for everything since its last release:
  - **major**: breaking, such as renamed or removed inputs, changed invocation, or removed behavior.
  - **minor**: a new capability, backward compatible.
  - **patch**: fixes and wording.
- Tag the release commit with an annotated tag `<skill-name>@<version>` (for example `pr-review@1.2.0`).
- Push commits and tags only when the user asks.

## Related skills

Each skill lists the skills it works with in `metadata.related` (comma-separated names), e.g. `related: "evidence, pr-review"`. List a skill when this one hands it a file, takes a file from it, shares a contract with it, or names it to the user. Hand-offs and contracts are listed on both sides and change together; naming a skill to the user is listed only on the side that names it.

## Shared contracts

Blocks marked `<!-- contract:<name> -->` are shared between skills: the report (`orchestration/templates.md` §6 ⊆ `specialist/SKILL.md` "Report") and the handoff note (identical in `orchestration/templates.md` §7 and `specialist/SKILL.md` "Context"). Change both sides in the same commit and bump both skills.

## Runtime rule

Every skill works in any runtime: the environment the agent runs in and can call (bb, a CLI agent such as Claude Code, Codex or opencode, or none).

- Each skill has `references/runtimes.md` with two parts:
  - **Detect** — signals to identify the runtime, checked top to bottom.
  - **Glossary** — one row per term, one column per runtime (plus `none`), saying what the term means there.
- A skill may hold the Glossary in `scripts/runtime.sh` instead, one subcommand per term that performs the action where the runtime has a CLI and prints the tool parameters where it does not. The script then documents itself (`runtime.sh help [command]`), and `runtimes.md` keeps only what the script is and the Detect section. The `workflow` skill does this.
- `SKILL.md` detects its runtime before the first step that needs it and reads its glossary column (or runs the script), then uses only those terms. No runtime names, commands, paths, model names, or examples outside `runtimes.md` and `runtime.sh`.
- Runtime metadata files (e.g. `agents/openai.yaml` for Codex) and runtime adapter scripts (e.g. a hook for one runtime) live in the skill folder; they may name their runtime. Frontmatter keys one runtime needs (e.g. `disable-model-invocation`, `argument-hint`) stay top-level in `SKILL.md`.

## Family conventions

Skills stay standalone, but shared ideas use the same words and shapes:

- **Storage.** Per-conversation: thread storage where the runtime has it (bb), else `~/.agents/<skill>/<session or task>/`. Shared across conversations: `~/.agents/<skill>/`. Never inside a repo.
- **Runtime inside bb.** Every `runtimes.md` Detect section says: "bb runs Claude Code or Codex inside it; the bb column names both where they differ". No separate cells for the CLI agent bb runs.
- **Verdicts.** `Approve | Request changes`. Severities `C` critical 🛑 · `W` warning 🟠 · `N` nit ⚪. Map status ✅ checked · ⚠️ not verified · ❌ broken. 🟢🟡🔴 mean context zones only.
- **Reports.** The part the user acts on comes first, in a fixed shape; details below a rule; machine data last.
- **User-invoked skills** (`disable-model-invocation`) are never run by agents; an agent hands the user the exact command instead.
- **Hand-offs** between skills go through files (a `services.md` record, a report, `pack.md`) passed as optional arguments, so each skill still works alone.
- **Init.** A rule that must hold before the skill is loaded (on every task, after compaction) goes in `init.md` in the skill folder: a heading and a few lines, always-on rules only, no runtime names. `install.sh` writes it inline into the user's global instructions between `<!-- skill:<name> <version> -->` and `<!-- /skill:<name> -->`. Everything situational stays in `SKILL.md`. Run `./test-install.sh` after changing `install.sh`.
