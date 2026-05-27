# Skill best practices

## Design principles

- Optimize for execution clarity first, stylistic purity second.
- Keep commands explicit, deterministic, and easy to run.
- Prefer concise instructions that preserve safety constraints.
- Treat proven patterns in existing skills as valid defaults.

## Naming

- Use `verb-object[-qualifier]` in kebab-case.
- Keep directory name and `name:` in frontmatter identical.
- Prefer command-like names (for example: `/review-pr`, `/post-pr-review`).

## SKILL.md authoring

- Start with a clear invocation contract.
- Define required arguments and fail-fast behavior ("ask once and stop").
- Prefer `## Step N — Title` for procedural workflows.
- Use protocol sections (`Goal`, `Protocol`, `Rules`) for always-on behavior skills.

## Workflow quality

- Separate execution workflow from output formatting rules.
- Model multi-pass behavior explicitly when relevant (for example pass 01 vs pass 02+).
- Make output deterministic: IDs, fields, counts, and summary format.
- Define dedup/status semantics explicitly when needed (for example `❌ / ✅ / ✅ dup`).
- Call out parallelizable context loading where useful.

## Safety and scope

- Keep non-negotiable constraints explicit.
- State when to confirm, when to stop, and what must never be done.
- Keep tool/dependency assumptions explicit in frontmatter when relevant.

## Token efficiency

- Remove repeated prose and redundant restatements.
- Prefer precise verbs and stable domain terms.
- Keep reference files focused by purpose (`checklist.md`, `format.md`, `output.md`).
