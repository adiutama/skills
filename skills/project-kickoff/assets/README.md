# <Project name>

<One paragraph: what it is, who it's for, and the problem it solves.>

## Install

<How to install or run it.>

## Use

<What a user does with it, from their point of view.>

## Contributing

Read [AGENTS.md](AGENTS.md) first: it is the working agreement for people and
agents alike.

### Commands

```sh
npm install
npm run check         # Biome + typecheck + tests + check:specs; run before every commit
npm run format        # Biome: format and organize imports
npm test              # Vitest
npm run check:specs   # decisions, specs, and tests are in sync
```

### Docs

| Path | Holds |
| --- | --- |
| [`docs/overview.md`](docs/overview.md) | Pitch, layout, names, glossary |
| `docs/architecture.md` | Modules and data flow (added with the first code) |
| [`docs/decisions/`](docs/decisions/) | ADRs, `YYYYMMDDHHMM-slug.md`, append-only |
| [`docs/specs/`](docs/specs/) | Behaviour per feature area, with numbered rules |
| [`docs/findings/`](docs/findings/) | Results of live tests against real systems, with versions |
| [`docs/BRIEF.md`](docs/BRIEF.md) | The original brief; frozen |

Each folder has a `_template.md`. Specs move `draft` → `agreed` →
`implemented`. Each declares a unique `Prefix` and lists rules as
`- **PREFIX-1** text (ADR 202601010000)`. Rule IDs are never renumbered or reused.

`npm run check:specs` enforces this:

- ADR names, statuses, and reciprocal `Supersedes` / `Superseded by` links.
- Accepted ADRs are unchanged since acceptance (except status lines), and none
  are deleted or renamed. This needs full git history.
- Spec headers and rule lines are well formed; cited ADRs are in `Decisions` and
  accepted.
- Every rule in an `implemented` spec has a passing test, and every test ID names
  a real rule. `agreed` specs are approved but not yet required to be covered.

### Tests

Tests live in `tests/`. A test covers a rule when its title starts with the
rule's ID: `it("ACT-1: confirms before closing", …)`. Several IDs are
comma-separated: `it("ACT-1, ACT-2: …")`.

`check:specs` reads coverage from the Vitest JSON report that `npm test` writes
to `.cache/test-results.json`, so only tests that actually ran and passed count.
Run the full suite before it; a filtered run reports rules as untested.
Fixtures go in `tests/fixtures/`, which Vitest does not run.

### Commits

Conventional style: `feat:`, `fix:`, `test:`, `chore:`, `docs:`, with
`docs(adr):` for decisions and `docs(spec):` for specs.

## License

MIT. See [LICENSE](LICENSE).
