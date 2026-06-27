# AI Skills

A collection of reusable AI agent skills, following the [agentskills.io](https://agentskills.io/) open standard.

## Skills

| Skill | Description |
|---|---|
| [review-diff](skills/review-diff/SKILL.md) | Skeptical pre-push review—shippable before the PR exists. |
| [scan-blast-radius](skills/scan-blast-radius/SKILL.md) | Scan blast radius of local changes before commit — fixes, features, glue, and rewiring. |
| [review-pr](skills/review-pr/SKILL.md) | Skeptical PR review—stance, findings, session on disk. Does not submit to GitHub. |
| [submit-pr-review](skills/submit-pr-review/SKILL.md) | Submit saved review session to GitHub—inline paste blocks, approve or request-changes via gh. |
| [address-pr-feedback](skills/address-pr-feedback/SKILL.md) | Address unresolved PR feedback — triage items to fix and loop until clear. Use `--fetch-only` to list only. |
| [refactor-safely](skills/refactor-safely/SKILL.md) | Refactor code in any language with a beauty-first, safety-first style while preserving behavior. |
| [refine-skill](skills/refine-skill/SKILL.md) | Refine skill docs and prompts for token efficiency while preserving intent, constraints, and capability. |

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
