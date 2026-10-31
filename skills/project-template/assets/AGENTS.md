# Working agreement

This is the contract between contributors and the agents working in this repo.
Commands, the docs layout, and conventions are in [README.md](README.md#contributing).

## House rules

Contributors write this section; agents follow it and never edit it. If a rule
here seems to conflict with a task, stop and ask. To suggest a rule, say so in
chat; a contributor adds it in their own words.

<!-- Contributors: add rules below. -->

## Docs are the blueprint

Code is what the docs compile into. Work always flows in this order:

1. **Decision**: a new or changed decision gets an ADR in `docs/decisions/`,
   before or in the same commit as the spec change it drives. Never after.
2. **Spec**: the behaviour goes into `docs/specs/`.
3. **Tests**: each rule gets a passing test whose title starts with its ID.
4. **Code**: written to make those tests pass.

- Code never lands ahead of its spec. A spec or ADR may land ahead of code.
- A spec change that alters observable behaviour or any rule's meaning needs a
  contributor's approval. A **clarification** (wording, examples, typos that
  change neither) does not.
- Approval is explicit: a contributor says so in the thread or the PR. Agents
  never set a spec to `agreed` or an ADR to `accepted` on their own.
- If code and an `agreed` or `implemented` spec disagree, the spec wins: fix
  the code and say so. If the spec itself looks wrong, ask; never edit a spec to
  match the code.

## Decisions are migrations

ADRs work like database migrations: an ordered log that is only ever appended to,
and that the code must apply.

- Named `YYYYMMDDHHMM-slug.md` in UTC. Refer to them by the timestamp.
- Lifecycle: `proposed` → `accepted` → `superseded`. Accepted means decided, not
  built; specs track what is built (`agreed` = approved to build,
  `implemented` = built and tested).
- Once accepted, an ADR is frozen. Only its `Status` and `Superseded by` lines
  may change. It is never edited, renamed, or deleted.
- To change a decision, write a new ADR that lists the old one in `Supersedes`.
  When the new one is accepted, mark the old one `superseded` in the same commit.
- An accepted ADR is applied when every spec and file in its "Applies to" line
  matches it. Until then it is pending work.
- Read the accepted ADRs before any design work. Never contradict one silently;
  propose a superseding ADR instead.

## Definition of done

- The spec describes what the code does. A spec is marked `implemented` once
  every rule has a passing test, and from then on the check enforces it.
- `npm run check` passes.
- README is updated if a user would notice the change.
