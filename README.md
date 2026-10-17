# AI Skills

Reusable AI agent skills following the [agentskills.io](https://agentskills.io/) open standard.

## Skills

| Skill | Version | Description |
|---|---|---|
| [evidence](skills/evidence/SKILL.md) | 1.0.0 | Capture screenshots and HTTP requests with responses as proof of work — redacted, stamped with commit, stored outside the repo — and pack them into a paste-ready PR Evidence block. Manual only. |
| [orchestration](skills/orchestration/SKILL.md) | 1.0.0 | Classify work, route it to a model tier, decide whether to delegate, and keep context in check; Manager → Lead → Specialist delegation loads only when needed. |
| [pr-review](skills/pr-review/SKILL.md) | 1.0.0 | Review a GitHub PR in an isolated worktree as one visual report (change map, behavior diff, blast radius, pinned findings); submit only on request. |
| [specialist](skills/specialist/SKILL.md) | 1.0.0 | Do one role well — architect, designer, implementer, tester, reviewer, explorer, researcher, prototyper — with a fixed report contract. |
| [throwaway-services](skills/throwaway-services/SKILL.md) | 1.0.0 | A disposable environment for manual verification: start new local services, emulators, and the app for a worktree, seed them for the case you want to check, get the link to open first, and keep it all running until you stop it. Manual only. |

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
