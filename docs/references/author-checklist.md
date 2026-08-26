# Skill author checklist

Use this checklist before finalizing a skill.

- [ ] Name follows `verb-object[-qualifier]` and matches folder name — **or** qualifies as a [summon name](../../CONVENTIONS.md#summon-names-exception) (gates + compensating fields met).
- [ ] `description` states both what the skill does and when to use it.
- [ ] Frontmatter includes required fields (`name`, `description`).
- [ ] `compatibility` is included when runtime dependencies matter.
- [ ] `metadata.argument-hint` is present for argument-driven skills.
- [ ] `allowed-tools` is accurate and minimal.
- [ ] Invocation line is explicit (for command-driven skills).
- [ ] **Summon names only:** bare `/name` asks once and stops; examples use conversational questions; `Voice` section or equivalent separates chat tone from artifact structure.
- [ ] Workflow is ordered, testable, and fail-fast on invalid input.
- [ ] Output schema is deterministic and unambiguous.
- [ ] Reference paths are clear and consistent.
- [ ] Safety constraints and stop/confirm conditions are explicit.
- [ ] Wording is concise; no redundant instructions.
- [ ] **Visible structure:** the workflow is clear at a glance; each block has one job.
- [ ] **Voice:** poetic boundaries earn their tokens through intent, posture, or judgment—not ornament.
- [ ] **Literal execution:** actions, conditions, safety rules, and stop criteria use plain, explicit English.
- [ ] **Controlled terms:** one term carries one meaning; uncommon or metaphorical terms that control behavior are defined.
- [ ] **Leading words:** 2–4 accessible anchor terms are front-loaded in `description` and used consistently in the body.
- [ ] **Completion:** important steps end with an observable `Done when:` or equivalent criterion.
- [ ] **Quotation, if present:** short, relevant, understandable, verified, attributed, and not the only source of a requirement.
- [ ] **User-facing voice, when relevant:** lead with the result, use plain English, and define necessary technical terms.
- [ ] **Distilled test:** structure is visible, voice remains human, and execution stays literal.
- [ ] Repeatable mechanics live in `scripts/` or disclosed `references/`, not narrated every run.
- [ ] **Standalone:** full workflow in this package; no invoke/load/assume another skill.
- [ ] **Duplicate, don't reference:** concepts borrowed from other skills are copied into this package (trimmed), not linked at runtime.
- [ ] **Runtime paths** point at `<SKILL_DIR>/...` or this skill's tree only—not another skill's files.
- [ ] **Independence check:** this skill alone is enough to finish the job (see [Building new skills](best-practices.md#building-new-skills)).
