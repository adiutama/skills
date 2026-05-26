# Commit intent checklist

## Change type mapping

- `feat`: Adds user-visible behavior or capability.
- `fix`: Corrects broken behavior or bug.
- `refactor`: Internal code change without behavior change.
- `perf`: Improves runtime or memory characteristics.
- `docs`: Documentation-only updates.
- `test`: Adds or updates tests.
- `build`: Tooling, packaging, dependency, or build pipeline updates.
- `ci`: CI workflow and automation updates.
- `chore`: Maintenance work that does not fit categories above.

## Scope selection

- Prefer a short noun tied to the dominant change area.
- Derive scope from changed paths or symbols, not a hardcoded list.
- Use one scope only; prefer stable domain names already used in commit history.
- If multiple unrelated areas are touched, omit scope instead of inventing one.

## Subject quality checks

- Present tense, imperative mood (`add`, `fix`, `update`).
- 72 characters max.
- No trailing period.
- Specific enough to stand alone in `git log --oneline`.

## Body quality checks

- Explain why the change exists, not only what changed.
- Mention constraints, trade-offs, or follow-up where relevant.
- Wrap to about 72 chars per line when practical.
- Omit body when it adds no value.
