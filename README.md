# AI Skills

Reusable AI agent skills following the [agentskills.io](https://agentskills.io/) open standard.

## Skills

| Skill | Version | Description |
|---|---|---|
| [evidence](skills/evidence/SKILL.md) | 1.0.0 | Capture screenshots and HTTP requests with responses as proof of work — redacted, stamped with commit, stored outside the repo — and pack them into a paste-ready PR Evidence block. Manual only. |
| [orchestration](skills/orchestration/SKILL.md) | 1.3.1 | Classify work, route it to a model tier, decide whether to delegate, and keep context in check; Manager → Lead → Specialist delegation loads only when needed. |
| [pr-review](skills/pr-review/SKILL.md) | 1.0.0 | Review a GitHub PR in an isolated worktree as one visual report (change map, behavior diff, blast radius, pinned findings); submit only on request. |
| [specialist](skills/specialist/SKILL.md) | 1.1.0 | Do one role well — architect, designer, implementer, tester, reviewer, explorer, researcher, prototyper — with a fixed report contract. |
| [throwaway-services](skills/throwaway-services/SKILL.md) | 1.1.0 | A disposable environment for manual verification: start new local services, emulators, and the app for a worktree, seed them for the case you want to check, get the link to open first, and keep it all running until you stop it. Manual only. |

## Setup

1. **Install.** Copy each skill folder to your harness's skills directory: bb `~/.bb/skills/<skill>`, Claude Code `~/.claude/skills/<skill>`, Codex `~/.codex/skills/<skill>`. Copy again after each release; running sessions keep the version they loaded.
2. **Load orchestration and specialist on every task.** Their descriptions ask for it, but agents skip them on small tasks. Add this to your global instructions (bb `~/.bb/AGENTS.md`, Claude Code `~/.claude/CLAUDE.md`, Codex `~/.codex/AGENTS.md`):

   ```markdown
   ## Workflow

   At the start of every task, the user prefers you always start by loading these skills, even when the task looks small or is a follow-up:

   - `orchestration`
   - `specialist`

   A worker whose prompt starts with `Role:` loads only the skills its brief names.

   Reload them after any context compaction. Every reply that starts work begins with the classification line, so a missing line shows the rules weren't applied.
   ```

3. **Hooks (Claude Code, optional).** The context-zone hook and status line, and the reminder hook: see [orchestration harnesses § Context zone hook](skills/orchestration/references/harnesses.md#context-zone-hook). bb gives every thread a context reading with `bb thread context --self`, so under bb the context-zone hook is a convenience, not a requirement.

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
