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
