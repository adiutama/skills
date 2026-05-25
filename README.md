# AI Skills

A collection of reusable AI agent skills.

## Skills

| Skill | Description |
|---|---|
| [local-review](local-review/SKILL.md) | Review local git changes before pushing. Catches problems early so the PR process is smoother. |
| [pr-review](pr-review/SKILL.md) | Review a GitHub PR and save a persistent session file. Does not post anything — use `pr-post` to publish findings. |
| [pr-post](pr-post/SKILL.md) | Post findings from a saved review session as inline GitHub PR comments. Use after `pr-review`. |
| [pr-unresolved](pr-unresolved/SKILL.md) | Fetch all unresolved review threads and pending change requests from a GitHub PR. |

## Structure

```
skills/
├── README.md
└── <skill-name>/
    ├── SKILL.md       # skill definition and instructions
    ├── assets/        # templates and supporting files (if any)
    └── references/    # output contracts and reference docs (if any)
```

## Usage

Each skill lives in its own directory. Invoke a skill by referencing its `SKILL.md` in your agent configuration or by using it as a slash command in Claude Code.
