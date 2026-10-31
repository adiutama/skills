# AI Skills

Reusable AI agent skills following the [agentskills.io](https://agentskills.io/) open standard.

## Skills

| Skill | Version | Description |
|---|---|---|
| [evidence](skills/evidence/SKILL.md) | 1.0.0 | Capture screenshots and HTTP requests with responses as proof of work — redacted, stamped with commit, stored outside the repo — and pack them into a paste-ready PR Evidence block. Manual only. |
| [orchestration](skills/orchestration/SKILL.md) | 2.0.0 | Deprecated: merged into `workflow`. |
| [pr-review](skills/pr-review/SKILL.md) | 1.0.0 | Review a GitHub PR in an isolated worktree as one visual report (change map, behavior diff, blast radius, pinned findings); submit only on request. |
| [pr-testing](skills/pr-testing/SKILL.md) | 1.0.0 | Test open PRs by hand, one at a time, in one disposable test checkout with fake integrations and synthetic data; a per-PR checklist dashboard whose buttons reach the agent, fresh implementers for agreed fixes, merge only on your say-so. Manual only. |
| [project-kickoff](skills/project-kickoff/SKILL.md) | 1.0.0 | Start a new project from your setup: docs-as-blueprint AGENTS.md, append-only ADRs, specs with numbered rules traced to tests by a check script, TypeScript + Biome + Vitest. Loads on its own when you ask for a new project. |
| [specialist](skills/specialist/SKILL.md) | 2.0.0 | Deprecated: merged into `workflow`. |
| [throwaway-services](skills/throwaway-services/SKILL.md) | 1.1.1 | A disposable environment for manual verification: start new local services, emulators, and the app for a worktree, seed them for the case you want to check, get the link to open first, and keep it all running until you stop it. Manual only. |
| [workflow](skills/workflow/SKILL.md) | 1.2.0 | Classify work, route it to a model tier, decide whether to delegate, and do or coordinate it: one coordinator, workers with role cards, a harness script for spawn, tell, read, and storage. |

## Setup

1. **Install.** Copy each skill folder to your harness's skills directory: bb `~/.bb/skills/<skill>`, Claude Code `~/.claude/skills/<skill>`, Codex `~/.codex/skills/<skill>`. Copy again after each release; running sessions keep the version they loaded.
2. **Load workflow on every task.** Its description asks for it, but agents skip it on small tasks. Add this to your global instructions (bb `~/.bb/AGENTS.md`, Claude Code `~/.claude/CLAUDE.md`, Codex `~/.codex/AGENTS.md`):

   ```markdown
   ## Workflow

   At the start of a top-level task, load the `workflow` skill if it is not already loaded in the current context.

   A worker whose prompt starts with `Role:` loads only the skills its brief names.

   Reuse loaded skills on follow-ups. Reload after context compaction, relevant instruction changes, or when required details are unavailable.

   Start a new substantive task or scope change with `Classification:` before any tool call other than loading skills. Briefed workers follow their brief instead. Routine replies and completion notifications do not require a fresh classification.
   ```

3. **Reminder hook (Claude Code, optional).** See [workflow harnesses § Reminder hook](skills/workflow/references/harnesses.md#reminder-hook).

## Structure

```
skills/
└── <skill-name>/
    ├── SKILL.md      # frontmatter includes metadata.version
    └── ...           # optional supporting files
```

## Versioning

Each skill is versioned independently with semver (`metadata.version` in `SKILL.md`) and released as a git tag `<skill-name>@<version>`. See [AGENTS.md](AGENTS.md) for the bump rules.

The pre-rewrite skills are archived on the `legacy` branch.
