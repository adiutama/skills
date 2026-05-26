# AI Skills

A collection of reusable AI agent skills, following the [agentskills.io](https://agentskills.io/) open standard.

## Skills

| Skill | Description |
|---|---|
| [commit](skills/commit/SKILL.md) | Generate consistent commit message candidates from staged changes and recommend the best one. |
| [local-review](skills/local-review/SKILL.md) | Review local git changes before pushing. Catches problems early so the PR process is smoother. |
| [pr-review](skills/pr-review/SKILL.md) | Review a GitHub PR and save a persistent session file. Does not post anything — use `pr-review-post` to publish findings. |
| [pr-review-post](skills/pr-review-post/SKILL.md) | Post findings from a saved review session as inline GitHub PR comments. Use after `pr-review`. |
| [pr-unresolved](skills/pr-unresolved/SKILL.md) | Fetch all unresolved review threads and pending change requests from a GitHub PR. |

## Repository structure

```
.
├── skills/
│   └── <skill-name>/
│       ├── SKILL.md
│       ├── references/
│       └── scripts/    # optional, skill-internal helpers
├── scripts/
│   ├── link.sh         # link all repo skills globally via npx skills
│   └── unlink.sh       # unlink all repo skills globally via npx skills
├── CONVENTIONS.md
└── README.md
```

## Usage

Link all skills globally (all detected agents):

```bash
./scripts/link.sh
```

Unlink all skills managed by this repo:

```bash
./scripts/unlink.sh
```

Optional overrides:

- `SOURCE_DIR=/absolute/path/to/skills ./scripts/link.sh`

## Commit helper script

Generate a commit message from staged changes, then commit after confirmation:

```bash
./scripts/commit.sh
```

Common options:

- `./scripts/commit.sh --all` stage everything first (`git add -A`)
- `./scripts/commit.sh --dry-run` preview message only
- `./scripts/commit.sh --yes` commit without prompt
- `./scripts/commit.sh --model <model>` choose model explicitly
