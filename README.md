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
| [thoughtful-refactor](skills/thoughtful-refactor/SKILL.md) | Refactor code in any language with a beauty-first, safety-first style while preserving behavior. |

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
│   ├── unlink.sh       # unlink all repo skills globally via npx skills
│   └── sync.sh         # reconcile local skills with global installation
├── CONVENTIONS.md
└── README.md
```

## Usage

Link all skills globally (all detected agents):

```bash
./scripts/link.sh
```

Preview link actions:

```bash
./scripts/link.sh --dry-run
```

Unlink all skills managed by this repo:

```bash
./scripts/unlink.sh
```

Preview unlink actions:

```bash
./scripts/unlink.sh --dry-run
```

Sync local + global state (removes stale globals, links current locals):

```bash
./scripts/sync.sh
```

Preview actions without changing anything:

```bash
./scripts/sync.sh --dry-run
```

Optional overrides:

- `SOURCE_DIR=/absolute/path/to/skills ./scripts/link.sh`
- Run `./scripts/link.sh --help`, `./scripts/unlink.sh --help`, or `./scripts/sync.sh --help` for full options.

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
