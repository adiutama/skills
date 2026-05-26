# Skill conventions

## Repository layout

```
.
├── skills/
│   └── skill-name/
│       ├── SKILL.md
│       ├── references/
│       └── scripts/
└── scripts/            repo-level helpers (link/unlink, maintenance)
```

Skill packages must live under `skills/<skill-name>/`.

## Directory layout

```
skill-name/
├── SKILL.md
├── references/     guidance docs the skill reads at runtime
│   └── *.md
└── scripts/        shell helpers (omit if none needed)
    └── *.sh
```

Use `references/` for all guidance docs. Never use `assets/` or any other name.

## SKILL.md frontmatter

Required fields, in this order:

```yaml
---
name: kebab-case-name
description: One sentence — what it does and when to use it.
compatibility: What the environment must have (e.g. "Requires gh CLI authenticated to GitHub, and jq.")
metadata:
  argument-hint: "<required-arg> [optional-arg]"
allowed-tools: Bash(gh:*) Read Write
---
```

`allowed-tools` must be present. List only what the skill actually uses.

## SKILL.md body structure

1. **Invocation line** — first line of body, no heading:
   ```
   Invoked as `/skill-name [args]`. <Error handling note if needed.>
   ```

2. **Steps** — `## Step N — Title` (em dash, not hyphen; "Step" prefix, no trailing period):
   ```markdown
   ## Step 1 — Gather data
   ## Step 2 — Write the review
   ```

3. **Notes** (optional) — a single `## Notes` section at the end for edge cases, prerequisites, and error handling.

## Reference paths inside SKILL.md

Always use `<SKILL_DIR>/references/filename.md` — never relative markdown links:

```markdown
Follow `<SKILL_DIR>/references/format.md` for output format.
```

## Reference file conventions

**File naming:** single lowercase word matching what the file governs (`checklist.md`, `format.md`, `body.md`, `output.md`). Use a subdirectory only when multiple files share a common scope.

**H1:** Sentence case, matching the file's purpose loosely:
```markdown
# Body guidance        ← not "# Review Body Guidance"
# Summary format       ← not "# Pre-Post Summary Format"
# Event inference      ← not "# Event Inference"
```

**Section headings:** Sentence case throughout (`## Finding format`, not `## Finding Format`).

**Finding separator:** Em dash `—` everywhere — in finding block headings and in index/output lines:
```
### C1 — short title       ← not "### C1 - short title"
C1 — title  path/file:L   ← not "C1 - title  path/file:L"
```
