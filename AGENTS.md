# Agent Instructions

## Layout

- Each skill lives in `skills/<skill-name>/SKILL.md`, following the [agentskills.io](https://agentskills.io/) standard. Supporting files go in the same folder.
- `name` in the frontmatter must match the folder name.

## Versioning

Every skill carries a semver version in its frontmatter:

```yaml
---
name: example-skill
description: ...
metadata:
  version: "1.0.0"
---
```

- A new skill starts at `1.0.0`.
- Any commit that changes files under `skills/<skill-name>/` bumps that skill's version in the same commit:
  - **major** — breaking: renamed or removed inputs, changed invocation, removed behavior.
  - **minor** — new capability, backward compatible.
  - **patch** — fixes and wording.
- After committing, create an annotated tag `<skill-name>@<version>` (for example `review-pr@1.2.0`) on that commit.
- Push commits and tags only when the user asks.
