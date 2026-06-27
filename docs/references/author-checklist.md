# Skill author checklist

Use this checklist before finalizing a skill.

- [ ] Name follows `verb-object[-qualifier]` and matches folder name.
- [ ] `description` states both what the skill does and when to use it.
- [ ] Frontmatter includes required fields (`name`, `description`).
- [ ] `compatibility` is included when runtime dependencies matter.
- [ ] `metadata.argument-hint` is present for argument-driven skills.
- [ ] `allowed-tools` is accurate and minimal.
- [ ] Invocation line is explicit (for command-driven skills).
- [ ] Workflow is ordered, testable, and fail-fast on invalid input.
- [ ] Output schema is deterministic and unambiguous.
- [ ] Reference paths are clear and consistent.
- [ ] Safety constraints and stop/confirm conditions are explicit.
- [ ] Wording is concise; no redundant instructions.
- [ ] **Voice:** opening, gates, and judgment in prose earn their tokens (not ornament).
- [ ] **Leading words:** 2–4 anchor terms front-loaded in `description` and used consistently in the body.
- [ ] **Distilled test:** shorter, and still clear on what to do, what never to do, and tone of trust.
- [ ] Repeatable mechanics live in `scripts/` or disclosed `references/`, not narrated every run.
- [ ] **Standalone:** full workflow in this package; no invoke/load/assume another skill.
- [ ] **Duplicate, don't reference:** concepts borrowed from other skills are copied into this package (trimmed), not linked at runtime.
- [ ] **Runtime paths** point at `<SKILL_DIR>/...` or this skill's tree only—not another skill's files.
- [ ] **Independence check:** this skill alone is enough to finish the job (see [Building new skills](best-practices.md#building-new-skills)).
