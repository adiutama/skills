# Skill conventions

This document reflects the current repository style (as implemented in existing skills), not an idealized strict spec.

## Core principles

- Optimize for execution clarity first; **voice** and **leading words** are how skills stay compact without losing power.
- Keep commands explicit, deterministic, and easy to run.
- Prefer **distilled** instructions—lean and alive—not hollow cuts or spec voice.
- Treat existing successful patterns as valid templates.

## Voice and leading words

Skills in this repo aim for **beautiful, powerful, lean**: shared meaning in few tokens, not stripped wording. **Required for every skill**—not optional polish after structure or independence.

**Voice** is deliberate human prose that earns its place—opening lines, gates, boundaries, judgment the agent cannot infer. Cut **ornament** and **mere exposition**; keep lines that change behavior or trust.

**Leading words** are compact pretrained concepts the agent thinks with (e.g. _distill_, _oblivion_, _tight_, _red_). They collapse repeated meaning into one token:

- Front-load them in the **description** (invocation).
- Repeat them in the body as tokens, not re-explained sentences (execution).
- Prefer existing words that recruit model priors; coining costs definition tokens.

| Layer | Job | Cut when |
|-------|-----|----------|
| Voice | Trust, gates, intent, completion criteria | Pretty but behavior-neutral |
| Leading word | Anchor a whole region of behavior | Weak no-op (_be thorough_) |
| Script / reference | Repeatable mechanics | Judgment belongs in prose |

**Before shipping**, run the distilled test: still know what to do, what must never happen, and still sound like someone who trusts you? All yes and shorter → **distilled**. Any no → **hollow**.

See [best practices — Voice and compression](docs/references/best-practices.md#voice-and-compression) and `skills/refine-skill/` for examples.

## Skill independence

**Each skill is an individual.** In today's setup, preconfigured modularity (router skills, skill chains, one skill invoking another) is not an option. A skill must run complete on its own.

When building or refactoring a skill:

- **Self-contained package** — everything the run needs lives under `skills/<skill-name>/`: workflow in `SKILL.md`, detail in `references/`, mechanics in `scripts/`, templates in `assets/`.
- **No skill-to-skill dependency** — do not instruct the agent to invoke, load, or assume another skill (`/other-skill`, "use the review-pr skill", model-invoked reach clauses).
- **No borrowed runtime** — do not point at another skill's `references/` or `scripts/`. If this skill needs a concept, format, gate, or checklist that exists elsewhere, **duplicate it** into this package (`references/`, `assets/`, or inline in `SKILL.md`) and adapt only what this skill needs.
- **Duplicate until modularity** — shared concepts stay copied per skill for now. Do not wait for cross-skill imports, routers, or shared skill libraries; when the setup supports modularity, deduplication can happen then—not before.
- **One job, one skill** — if a workflow only works as a chain of skills, merge or split until each command stands alone; the human chooses the sequence, not the skill text.
- **Default user-invoked** — prefer `disable-model-invocation: true` for new skills unless agent auto-discovery is explicitly required.

Repo-level `docs/` and `CONVENTIONS.md` are **author guidance**, not runtime dependencies. If a skill needs a format, gate, or checklist to execute, copy or link **within its own package** (`<SKILL_DIR>/references/...`), not "see docs/" or another skill.

See [best practices — Building new skills](docs/references/best-practices.md#building-new-skills).

## Naming convention

- Skill names use `verb-object[-qualifier]` in kebab-case.
- Skill directory name and `name:` in frontmatter must match.
- Command form should read naturally: `/review-pr`, `/submit-pr-review`, `/refactor-safely`.

### Choosing the name

- **Object** — name the artifact, target, or outcome (`pr`, `handoff`, `changes`). Avoid generic objects (`task`, `thing`, `item`).
- **Qualifier** — carry the non-obvious constraint (`safely`, `outstanding`, `until-exit`).
- **Disambiguate** — if a built-in or sibling skill shares the base (`/loop`), the name must signal the difference in the command.
- **Invocation test** — `/name` should suggest *what* and *how it stops*; if not, rename or add a qualifier.

### Primitive extension names

When a skill extends a familiar primitive, name the delta:

| Pattern | Example | Reads as |
|---------|---------|----------|
| `<primitive>-<stop-word>` | `loop-until` | loop until [user-supplied condition] |
| `<primitive>-with-<feature>` | `loop-with-handoff` | loop, but with X |
| `<feature>-<primitive>` | `resumable-loop` | the kind of primitive that is X |

- Base must be widely understood (`loop`, `goal`, `review`).
- Delta names one non-obvious property (stop rule, persistence, safety).
- Avoid generic deltas (`task`, `process`, `thing`).

Bad: `iterate-task` (generic object, verb overlaps many workflows).  
Good: `loop-until` (extends `/loop` with conditional stop), `refactor-safely` (action + constraint).

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

Use `docs/` for **author-level** guidance—conventions, shared templates while drafting, onboarding—not as a runtime substitute for in-skill content.

- Shared review templates, output schemas, and reusable checklists while authoring.
- Shared terminology, conventions, and examples used by multiple skills.
- Onboarding/reference material.

At **runtime**, each skill still owns what it needs inside its package. Do not make execution depend on another skill or on `docs/` unless the user explicitly asks for a shared-doc pattern.

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
- Minimal numbered workflow format is also valid for simple skills (title + `1..N` steps) when steps are short and linear.
- Keep runtime guidance in `references/` and skill-scoped templates/examples in `assets/`.
- Use explicit file paths in instructions when ambiguity is possible.

## Artifact storage

Skills that produce persistent output files (review sessions, reports, etc.) must write to:

```text
~/.agents/artifacts/<owner>/<repo>/<branch-slug>/<skill-name>/
```

- `<owner>/<repo>` — derived from `git remote get-url origin`; use `_local/_local` when no remote exists.
- `<branch-slug>` — branch name with `/` and non-alphanumeric chars replaced by `-`; detached HEAD uses `detached-<short-sha>`.
- `<skill-name>` — matches the skill's `name:` frontmatter field.

**Rationale:** keeps the workspace clean, makes artifacts discoverable by other agents working on the same branch, and provides a single consistent location regardless of which project directory the skill was invoked from.

Skills must not write persistent artifacts into the workspace or the skill repository itself.

## See also

- [SKILL template](docs/templates/SKILL.template.md)
- [Best practices](docs/references/best-practices.md)
- [Author checklist](docs/references/author-checklist.md)
- [Refine skill](../skills/refine-skill/SKILL.md) — distillation workflow and voice examples
