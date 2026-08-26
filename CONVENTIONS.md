# Skill conventions

This document reflects the current repository style (as implemented in existing skills), not an idealized strict spec.

## Core principles

- **Poetic boundaries. Literal actions. Visible structure.**
- Optimize for execution clarity first; **voice**, **structure**, and **leading words** keep skills compact without losing power.
- Keep commands explicit, deterministic, and easy to run.
- Prefer **distilled** instructions—lean and alive—not hollow cuts or spec voice.
- Treat existing successful patterns as valid templates.

## Voice and leading words

Skills in this repo aim for **beautiful, powerful, lean**: shared meaning in few tokens, not stripped wording. **Required for every skill**—not optional polish after structure or independence.

> At a glance, structure. On reading, voice. In execution, precision.

| Element | Job | Boundary |
|---------|-----|----------|
| Quotation | Inherit a relevant perspective | Optional; never substitutes for evidence or instruction |
| Poetic boundary | Set intent, posture, or judgment | Never the only source of an action or safety rule |
| Structure | Reveal the workflow before close reading | One block, one job |
| Literal instruction | Control action, branching, failure, and completion | Prefer plain, explicit English |

### Voice and poetic boundaries

**Voice** is deliberate human prose that earns its place—opening lines, gates, boundaries, and judgment the agent cannot infer. A poetic line may compress the reason for a whole block; the instructions beneath it state the mechanism literally.

- Use poetry where judgment matters, not mechanically in every section.
- Keep actions, conditions, tool calls, safety rules, and stop conditions literal.
- If removing a line changes neither behavior nor trust, it is **ornament**; cut it.
- If a metaphor must be interpreted before the agent can act, rewrite the action.

### Quotations

**Borrow a compass, not authority.** A quotation may steer the skill toward a field's enduring idea; it does not make the idea true.

- Use a quote only when it sharpens the skill's central judgment.
- Keep it short, understandable, and relevant to the field.
- Verify the exact wording, author, and source. If verification is weak, write an original boundary line instead.
- Do not place a requirement only inside a quotation.

### Leading words

**Leading words** are compact pretrained concepts the agent thinks with (e.g. _distill_, _oblivion_, _tight_, _red_). They collapse repeated meaning into one token:

- Front-load them in the **description** (invocation).
- Repeat them in the body as tokens, not re-explained sentences (execution).
- Prefer common English and stable field terms that recruit model priors.
- Use one term for one meaning. Define uncommon, coined, or metaphorical terms when they control behavior.
- Do not depend on cultural familiarity or advanced English for correct execution.

For a controlled local term, define its operational meaning once:

```markdown
**Oblivion** — Discard the current draft and restore the last valid version.
```

### Literal execution

Borrow the useful discipline of controlled technical English without adopting cold spec voice:

- Put the condition before the action.
- Give one main action per sentence.
- Prefer common, concrete verbs: `read`, `write`, `run`, `check`, `ask`, `stop`.
- Name the subject and object when omission could confuse.
- Keep one term for one concept; avoid casual synonyms.
- Separate explanation from instruction.
- State observable completion and stop conditions.

### Visible structure

Structure is compression the reader can see:

- Give each block one job.
- Use headings that name an outcome, decision, or phase.
- Keep related definitions, rules, and caveats together.
- Use tables for real mappings, branches, and comparisons—not decoration.
- Use whitespace to separate ideas.
- End important steps with `Done when:` or an equally observable criterion.

| Layer | Job | Cut when |
|-------|-----|----------|
| Quote / voice | Perspective, trust, boundaries, judgment | Decorative or unverifiable |
| Leading word | Anchor a whole region of behavior | Weak no-op (_be thorough_) |
| Structure | Orientation and grouping | Blocks divide nothing meaningful |
| Literal step | Exact action and completion | Another step already owns the meaning |
| Script / reference | Repeatable mechanics or disclosed detail | Judgment belongs in prose |

**Before shipping**, run the distilled test: at a glance, can the reader see the workflow? On reading, does it still sound human? In execution, are actions and stop conditions literal? All yes and shorter → **distilled**. Any no → **hollow**.

See [best practices — Voice and compression](docs/references/best-practices.md#voice-and-compression) and `skills/refine-skill/` for examples.

## Skill independence

**Each skill is an individual.** In today's setup, preconfigured modularity (router skills, skill chains, one skill invoking another) is not an option. A skill must run complete on its own.

When building or refactoring a skill:

- **Self-contained package** — everything the run needs lives under `skills/<skill-name>/`: workflow in `SKILL.md`, detail in `references/`, mechanics in `scripts/`, templates in `assets/`.
- **No skill-to-skill dependency** — do not instruct the agent to invoke, load, or assume another skill (`/other-skill`, "use the review-change skill", model-invoked reach clauses).
- **No borrowed runtime** — do not point at another skill's `references/` or `scripts/`. If this skill needs a concept, format, gate, or checklist that exists elsewhere, **duplicate it** into this package (`references/`, `assets/`, or inline in `SKILL.md`) and adapt only what this skill needs.
- **Duplicate until modularity** — shared concepts stay copied per skill for now. Do not wait for cross-skill imports, routers, or shared skill libraries; when the setup supports modularity, deduplication can happen then—not before.
- **One job, one skill** — if a workflow only works as a chain of skills, merge or split until each command stands alone; the human chooses the sequence, not the skill text.
- **Default user-invoked** — prefer `disable-model-invocation: true` for new skills unless agent auto-discovery is explicitly required.

Repo-level `docs/` and `CONVENTIONS.md` are **author guidance**, not runtime dependencies. If a skill needs a format, gate, or checklist to execute, copy or link **within its own package** (`<SKILL_DIR>/references/...`), not "see docs/" or another skill.

See [best practices — Building new skills](docs/references/best-practices.md#building-new-skills).

## Naming convention

**Default:** skill names use `verb-object[-qualifier]` in kebab-case.

- Skill directory name and `name:` in frontmatter must match.
- Command form should read naturally: `/review-change`, `/address-pr-feedback`, `/refactor-safely`.

### Choosing the name

- **Object** — name the artifact, target, or outcome (`pr`, `handoff`, `changes`). Avoid generic objects (`task`, `thing`, `item`).
- **Qualifier** — carry the non-obvious constraint (`safely`, `outstanding`, `until-exit`).
- **Disambiguate** — if a built-in or sibling skill shares the base (`/loop`), the name must signal the difference in the command.
- **Invocation test** — `/name` should suggest *what* and *how it stops*; if not, rename or add a qualifier.

### Summon names (exception)

A **summon name** is what you'd actually say when pausing to think—not a capability label. Example: `/ponder should we use OAuth or magic link?`

**Default stays `verb-object`.** Use a summon name only when all of the following hold:

| Gate | Rule |
|------|------|
| **Fuzzy job** | No single crisp artifact or tool action (explore, compare, decide—not "post review", "run lint"). |
| **User-invoked** | `disable-model-invocation: true` — you type the command; description is not the primary discovery path. |
| **Natural tail** | Invocation is `/name <your question>` in conversational language; bare `/name` → ask once, then stop. |
| **Done is defined** | Skill body states when the session ends (e.g. recommendation written, status `done`). |
| **Durable or bounded** | Session on disk with resume, or an explicit single-shot stop—never an unbounded chat loop. |

**Name rules (still apply):**

- Lowercase kebab-case in `name:` and folder (`ponder`, not `Ponder` or `ponder 😂`).
- No emoji or punctuation in `name:` — voice lives in prose and examples.
- One real word or a short fixed phrase you already use; not a synonym for an existing pipeline skill.
- **One summon name per cognitive mode** — don't spawn `/ugh`, `/hmm`, `/think` for the same job.

**Required compensating fields** (summon names carry less meaning in the command—put it here):

- **`description`** — third person; full **what** + **when**; include trigger terms (`question`, `think through`).
- **`metadata.argument-hint`** — conversational tail, e.g. `'<your question>'` or `'resume'`.
- **`Invoked as`** — 2–3 example questions, not spec-style problem statements.
- **`Voice` or equivalent** — chat stays human; artifacts on disk stay structured.

**When not to use a summon name:**

- Deterministic pipelines (`review-change`, `address-pr-feedback`, `scan-blast-radius`).
- Skills another person must scan in a catalog without reading the body.
- Anything where `/name` alone should auto-start work without a question.

### Primitive extension names

When a skill extends a familiar primitive, name the delta:

| Pattern | Example | Reads as |
|---------|---------|----------|
| `<primitive>-<stop-word>` | `retry-until` | retry until [user-supplied condition] |
| `<primitive>-with-<feature>` | `loop-with-handoff` | loop, but with X |
| `<feature>-<primitive>` | `resumable-loop` | the kind of primitive that is X |

- Base must be widely understood (`loop`, `goal`, `review`).
- Delta names one non-obvious property (stop rule, persistence, safety).
- Avoid generic deltas (`task`, `process`, `thing`).

Bad: `iterate-task` (generic object, verb overlaps many workflows).  
Good: `retry-until` (retry until [condition]; not timed `/loop`), `refactor-safely` (action + constraint).

## Repository and package layout

```text
.
├── docs/                    # shared references/templates used by multiple skills
├── skills/
│   └── <skill-name>/
│       ├── SKILL.md
│       ├── bin/             # optional PATH-ready public executables
│       ├── references/      # guidance docs used at runtime
│       ├── assets/          # optional templates/examples
│       └── scripts/         # optional shell helpers
└── scripts/                 # repo-level helpers
```

- Skill packages must live under `skills/<skill-name>/`.
- Put a stable executable in `bin/<skill-name>` when the skill may be invoked from `PATH`; keep its implementation under `scripts/`.
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
- **Summon-name skills** — `Invoked as` must show `/name <question>` examples; bare `/name` asks once and stops (see [Summon names](#summon-names-exception)).
- Always-on behavior skills may use protocol-style sections (`Goal`, `Protocol`, `Rules`).
- Minimal numbered workflow format is also valid for simple skills (title + `1..N` steps) when steps are short and linear.
- Keep runtime guidance in `references/` and skill-scoped templates/examples in `assets/`.
- Use explicit file paths in instructions when ambiguity is possible.

## Script templates

Shared shell helpers live in `docs/assets/` as **templates only** — copy into skill packages; never run from `docs/`.

### Naming pattern

| Pattern | Role | Examples |
|---------|------|----------|
| `<name>.sh` (source-only) | Sourced by other scripts — not invoked from `SKILL.md` | `pr-identity.sh` |
| `resolve-<target>.sh` | One-shot resolve → KEY=VALUE or JSON | `resolve-range.sh`, `resolve-scope.sh`, `resolve-session.sh` |
| `<verb>-session.sh` | Session lifecycle | `start-session.sh`, `init-session.sh`, `list-sessions.sh` |
| `<verb>-<object>.sh` | Other skill actions | `submit-review.sh`, `mark-posted.sh` |
| `artifacts.sh` | Artifact paths (source + CLI) | `artifacts.sh check`, `artifacts.sh allocate` |

### Templates

| Template | Copy to | Skills |
|----------|---------|--------|
| `artifacts.sh` | `scripts/artifacts.sh` | Any skill with persistent artifact output |
| `pr-identity.sh` | `scripts/pr-identity.sh` | Skills that parse a GitHub PR URL or number (source-only) |
| `resolve-range.sh` | `scripts/resolve-range.sh` | Pre-push review skills; source base for `scan-blast-radius/scripts/resolve-scope.sh` |
| `resolve-session.sh` | `scripts/resolve-session.sh` | Skills that resolve a persisted session for a GitHub PR |
| `submit-review.sh` | `scripts/submit-review.sh` | Skills that submit GitHub PR reviews via `gh api` |
| `mark-posted.sh` | `scripts/mark-posted.sh` | Skills that update finding `posting` state in review JSON |

When updating a template, copy into each skill package that uses it.

## Artifact storage

Skills that produce persistent output files copy `docs/assets/artifacts.sh` into their package:

```text
docs/assets/artifacts.sh   # template only — do not run or source from docs/
        ↓ copy
skills/<skill-name>/scripts/artifacts.sh
```

**Write root** (gitignore-gated):

| Condition | Write root |
|-----------|------------|
| `AGENTS_ARTIFACTS_ROOT` is set | Its absolute path |
| `.agents/artifacts` or `.agents/` is **gitignored** | `<git-root>/.agents/artifacts/` |
| Not gitignored (or not in a git repo) | `~/.agents/artifacts/` |

Path suffix: `<write-root>/<owner>/<repo>/<branch-slug>/<skill-name>/`

**From skill shell scripts** — source the local copy:

```bash
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=artifacts.sh
source "${SCRIPT_DIR}/artifacts.sh"
```

**From SKILL.md / agents** — call the skill-local CLI:

```bash
bash <SKILL_DIR>/scripts/artifacts.sh allocate <skill-name> [branch]
```

**Check:** `bash <SKILL_DIR>/scripts/artifacts.sh check [--json]`

**Override:** Set `AGENTS_ARTIFACTS_ROOT=/absolute/path` to choose a different write root.

Skills must not write persistent artifacts into the skill package itself. Recommend `.agents/` in project `.gitignore`.

## See also

- [SKILL template](docs/templates/SKILL.template.md)
- [Best practices](docs/references/best-practices.md)
- [Author checklist](docs/references/author-checklist.md)
- [Refine skill](skills/refine-skill/SKILL.md) — distillation workflow and voice examples
