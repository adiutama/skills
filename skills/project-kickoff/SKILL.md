---
name: project-kickoff
description: Start a new project or repo from the user's opinionated setup — docs-as-blueprint AGENTS.md, append-only ADRs, specs with numbered rules traced to tests by a check script, TypeScript + Biome + Vitest. Use when the user wants to create, start, or set up a new project, app, plugin, library, or repo ("let's create a new project about …"), or to add that setup to an empty repo.
metadata:
  version: "1.0.0"
  related: ""
---

## Harness

At the start, detect your harness with [harnesses.md § Detect](references/harnesses.md#detect), then read its glossary column. These terms mean exactly what that column says, everywhere in this skill and its references: **source link** · **register**.

## What the setup encodes

Everything in [assets/](assets/) is copied into the new repo. Its opinions, which you keep unless the user overrides one:

- **Docs are the blueprint.** Work flows decision → spec → tests → code, never the other way. `AGENTS.md` is the working agreement; its House rules section belongs to the user and agents never edit it.
- **ADRs are migrations.** `docs/decisions/YYYYMMDDHHMM-slug.md` (UTC), append-only, frozen once accepted, changed only by a superseding ADR.
- **Specs carry numbered rules** (`PREFIX-n`). Every rule in an `implemented` spec has a passing test whose title starts with its ID.
- **The machine enforces it.** `scripts/check-specs.mjs` checks ADR lifecycle and immutability from git history, spec format, and rule ↔ test traceability; `npm run check` runs it after lint, typecheck, and tests.
- **Findings record reality.** Experiments against real systems go in `docs/findings/` with exact versions and a repeatable procedure.
- **The brief is frozen.** `docs/BRIEF.md` is the starting input; `docs/overview.md` is the living summary.
- **Approval is the user's.** Agents never set a spec to `agreed` or an ADR to `accepted`.
- **Tooling:** TypeScript strict with `checkJs`, Biome (2 spaces, 100 columns, double quotes), Vitest, npm, Node ESM, `@/` alias to `src/`.
- **Commits:** conventional, with `docs(adr):` and `docs(spec):` scopes.
- **License:** MIT, copyright the user.

## Steps

1. **Understand the idea.** From the user's message, settle: what it is and for whom, a kebab-case name, the stack (default: the TypeScript setup above), and the project type. If the idea is thin, brainstorm first: ask at most three questions at a time, each with your proposed answer, until you could write the brief. Propose the name rather than asking for one.
2. **Pick the folder.** Default: a sibling of the user's other repos (the parent of the current checkout), named after the project. If the folder exists and is not empty, stop and ask.
3. **Copy.** Copy `assets/` into the folder, rename `gitignore` to `.gitignore`, and run `git init -b main`.
4. **Fill placeholders.** `grep -rn '<project-name>\|<Project name>\|<one-line pitch>\|<year>\|<copyright holder>' .` and replace each: package name, display name, pitch, the current year, and the copyright holder (the user's name from git config).
5. **Adapt the stack** if it is not TypeScript, or the project type has extra setup in [stacks.md](references/stacks.md): follow that file.
6. **Write the brief.** `docs/BRIEF.md` from the conversation, citing it by its **source link** and today's date; then `docs/overview.md` (pitch, layout or main flow, names, glossary). Keep the user's words for the pitch.
7. **Seed decisions and specs.** Each decision already made in the conversation becomes a `proposed` ADR; each behaviour discussed becomes a `draft` spec with rules. Leave anything undecided in the spec's Open questions. Skip this step if nothing was decided yet.
8. **Check.** `npm install && npm run check` (or the adapted stack's check) must pass. Fix what fails; never weaken the check.
9. **Commit.** One commit: `chore: start <project-name> from project-kickoff`.
10. **Register** the folder with the harness, if the term names an action.
11. **Report** the folder, what the brief and seeded ADRs and specs contain, the open questions, and which ADRs and specs wait for the user's approval. Create a remote repo or push only when the user asks.

## Changing the setup

The user's opinions live here, so a change to them is a change to this skill: edit `assets/` and this file together, and keep the list above in step with the files. Projects already created are not updated.
