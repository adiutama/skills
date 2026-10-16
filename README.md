# AI Skills

Reusable AI agent skills following the [agentskills.io](https://agentskills.io/) open standard.

## Skills

| Skill | Version | Description |
|---|---|---|

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
