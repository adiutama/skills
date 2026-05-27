# Skill conventions

This document reflects the current repository style (as implemented in existing skills), not an idealized strict spec.

## Core principles

- Optimize for execution clarity first, stylistic purity second.
- Keep commands explicit, deterministic, and easy to run.
- Prefer concise instructions that still preserve safety constraints.
- Treat existing successful patterns as valid templates.

## Naming convention

- Skill names use `verb-object[-qualifier]` in kebab-case.
- Skill directory name and `name:` in frontmatter must match.
- Command form should read naturally: `/review-pr`, `/post-pr-review`, `/refactor-safely`.

## Repository and package layout

```text
.
├── docs/                    # shared references/templates used by multiple skills
├── skills/
│   └── <skill-name>/
│       ├── SKILL.md
│       ├── references/      # guidance docs used at runtime
│       ├── assets/          # optional templates/examples
│       └── scripts/         # optional shell helpers
└── scripts/                 # repo-level helpers
```

- Skill packages must live under `skills/<skill-name>/`.
- `references/` is the default home for guidance docs.
- `assets/` is allowed for reusable templates/examples.
- Omit `scripts/` or `assets/` when unused.
- Use repo-level `docs/` for shared guidance/templates referenced by more than one skill.

## Global docs

Use `docs/` when content is cross-skill or long-lived project guidance:

- Shared review templates, output schemas, and reusable checklists.
- Shared terminology, conventions, and examples used by multiple skills.
- Onboarding/reference material that should not be duplicated per skill.

Keep per-skill specifics inside that skill package:

- `references/` for runtime guidance loaded by the skill.
- `assets/` for skill-scoped templates/examples.

## SKILL.md baseline

- `name` and `description` are required.
- Keep folder name, `name:`, and command naming aligned.
- Include `compatibility`, `metadata.argument-hint`, and `allowed-tools` when relevant.
- Legacy top-level `argument-hint` is acceptable for existing skills; prefer `metadata.argument-hint` for new or refactored skills.
- Keep instructions concise, executable, and deterministic.

## Body and reference baseline

- Command skills should start with `Invoked as ...`, then procedural `Step N` sections.
- Always-on behavior skills may use protocol-style sections (`Goal`, `Protocol`, `Rules`).
- Minimal numbered workflow format is also valid for simple skills (title + `1..N` steps), as used by `pickup-handoff`.
- Keep runtime guidance in `references/` and skill-scoped templates/examples in `assets/`.
- Use explicit file paths in instructions when ambiguity is possible.

## See also

- [SKILL template](docs/templates/SKILL.template.md)
- [Best practices](docs/references/best-practices.md)
- [Author checklist](docs/references/author-checklist.md)
