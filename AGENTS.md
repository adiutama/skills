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
- Any commit that changes files under `skills/<skill-name>/` bumps that skill's version in the same commit:
  - **major** — breaking: renamed or removed inputs, changed invocation, removed behavior.
  - **minor** — new capability, backward compatible.
  - **patch** — fixes and wording.
- After committing, create an annotated tag `<skill-name>@<version>` (for example `pr-review@1.2.0`) on that commit.
- Push commits and tags only when the user asks.

## Related skills

Each skill lists the skills it works with in `metadata.related` (comma-separated names), e.g. `related: "evidence, pr-review"`. List a skill when this one hands it a file, takes a file from it, shares a contract with it, or names it to the user. Hand-offs and contracts are listed on both sides and change together; naming a skill to the user is listed only on the side that names it.

## Shared contracts

Blocks marked `<!-- contract:<name> -->` are shared between skills: the report (`orchestration/templates.md` §6 ⊆ `specialist/SKILL.md` "Report") and the handoff note (identical in `orchestration/templates.md` §7 and `specialist/SKILL.md` "Context"). Change both sides in the same commit and bump both skills.

## Harness rule

Every skill works with any agent harness (bb, Claude Code, Codex, …).

- Each skill has `references/harnesses.md` with two parts:
  - **Detect** — signals to identify the harness, checked top to bottom.
  - **Glossary** — one row per term, one column per harness (plus `none`), saying what the term means there.
- A skill may hold Detect and the Glossary in `scripts/harness.sh` instead, one subcommand per term that performs the action where the harness has a CLI and prints the tool parameters where it does not; `harnesses.md` then documents the script and keeps the tier table. The `workflow` skill does this.
- `SKILL.md` opens by telling the agent to detect its harness and read its glossary column (or run the script), then uses only those terms. No harness names, commands, paths, model names, or examples outside `harnesses.md` and `harness.sh`.
- Harness metadata files (e.g. `agents/openai.yaml` for Codex) and harness adapter scripts (e.g. a hook for one harness) live in the skill folder; they may name their harness. Frontmatter keys one harness needs (e.g. `disable-model-invocation`, `argument-hint`) stay top-level in `SKILL.md`.

## Family conventions

Skills stay standalone, but shared ideas use the same words and shapes:

- **Storage.** Per-conversation: thread storage where the harness has it (bb), else `~/.agents/<skill>/<session or task>/`. Shared across conversations: `~/.agents/<skill>/`. Never inside a repo.
- **Bb-hosted line.** Every `harnesses.md` Detect section says: "bb runs Claude Code or Codex inside it; the bb column names both where they differ". No "hosted" cells.
- **Verdicts.** `Approve | Request changes`. Severities `C` critical 🛑 · `W` warning 🟠 · `N` nit ⚪. Map status ✅ checked · ⚠️ not verified · ❌ broken. 🟢🟡🔴 mean context zones only.
- **Reports.** The part the user acts on comes first, in a fixed shape; details below a rule; machine data last.
- **User-invoked skills** (`disable-model-invocation`) are never run by agents; an agent hands the user the exact command instead.
- **Hand-offs** between skills go through files (a `services.md` record, a report, `pack.md`) passed as optional arguments, so each skill still works alone.
