# AI Skills

A collection of reusable AI agent skills, following the [agentskills.io](https://agentskills.io/) open standard.

## Skills

| Skill | Description |
|---|---|
| [commit-changes](skills/commit-changes/SKILL.md) | Check staged changes first; otherwise use context-discovered file changes to stage and commit with a generated message. |
| [review-workspace](skills/review-workspace/SKILL.md) | Review local git changes before pushing. Catches problems early so the PR process is smoother. |
| [review-pr](skills/review-pr/SKILL.md) | Review a GitHub PR and save a persistent session file. Does not post anything — use `post-pr-review` to publish findings. |
| [post-pr-review](skills/post-pr-review/SKILL.md) | Post findings from a saved review session as inline GitHub PR comments. Use after `review-pr`. |
| [fetch-outstanding-pr-feedback](skills/fetch-outstanding-pr-feedback/SKILL.md) | Fetch all unresolved review threads and pending change requests from a GitHub PR. |
| [refactor-safely](skills/refactor-safely/SKILL.md) | Refactor code in any language with a beauty-first, safety-first style while preserving behavior. |
| [optimize-skill](skills/optimize-skill/SKILL.md) | Optimize prompts or skill docs for token efficiency while preserving intent, constraints, and capability. |
| [reconcile-context](skills/reconcile-context/SKILL.md) | Reconcile working context with live file state on every edit task. |
| [pickup-handoff](skills/pickup-handoff/SKILL.md) | Load a handoff file, send a short kickoff, and wait for confirmation before starting. |

## Repository structure

```
.
├── skills/
│   └── <skill-name>/
│       ├── SKILL.md
│       ├── references/
│       └── scripts/    # optional, skill-internal helpers
├── scripts/
│   ├── lib/            # shared script helpers
│   ├── cleanup.sh      # preview/remove unused agent config dirs
│   ├── link.sh         # link all repo skills globally via npx skills
│   ├── unlink.sh       # unlink all repo skills globally via npx skills
│   └── sync.sh         # reconcile local skills with global installation
├── CONVENTIONS.md
└── README.md
```

## Usage

Link all skills globally (auto-detected local harnesses):

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
- Default auto-targets are detected by intersecting:
  - agents supported by your local `skills` CLI (`Valid agents` list), and
  - binaries found on PATH (for example via `which <agent-cli>`)
  - when `skills` is not on PATH, the scripts fall back to common agents (`cursor`, `claude-code`, `codex`, `opencode`)
- `SKILLS_AGENTS="cursor claude-code codex" ./scripts/link.sh` to force an explicit agent list
- `SKILLS_BIN_CLAUDE_CODE=/custom/path/claude ./scripts/link.sh` to override a specific binary path
- Run `./scripts/link.sh --help`, `./scripts/unlink.sh --help`, or `./scripts/sync.sh --help` for full options.

## Cleanup unused agent config dirs

Preview unused config directories:

```bash
./scripts/cleanup.sh
```

Apply deletion:

```bash
./scripts/cleanup.sh --apply
```

Skip confirmation:

```bash
./scripts/cleanup.sh --apply --yes
```
