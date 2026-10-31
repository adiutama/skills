# Stacks and project types

## Another language

Keep `AGENTS.md`, `docs/`, and the commit style unchanged; they do not depend on the stack. Replace the tooling:

- Swap Biome, `tsc`, and Vitest for the stack's formatter/linter, type checker, and test runner. Keep one `check` command that runs them all, then the spec check.
- `scripts/check-specs.mjs` reads coverage from a Vitest JSON report in `readTestReport`. Change only that function so it reads the new runner's report (JUnit XML, pytest JSON, `go test -json`, …) into `{ title, status }` pairs, and point the runner at that report path. Keep the rest. It needs Node to run, which is fine in any repo. Port `tests/check-specs.test.ts` to keep its cases, or keep it under Vitest as a separate dev-only check.
- Test titles still start with the rule ID; in runners without free-text titles, put the ID first in the test name (`test_ACT_1_confirms_before_closing`) and map it back in `readTestReport`.
- Update the README's Commands and Tests sections to match.

## A web or React UI

- Add `react`, `react-dom`, `@types/react`, `@types/react-dom`, `jsdom`, `@testing-library/react`, and `@testing-library/jest-dom`.
- `tsconfig.json`: `"jsx": "react-jsx"` and `"DOM"` in `lib`.
- `vitest.config.ts`: `setupFiles: ["tests/setup/jest-dom.ts"]`, and component tests opt into jsdom.
- `docs/overview.md` gets an ASCII mockup of the main screen under Layout.

## A bb plugin

The setup came from `bb-plugin-terminal-hub` (github.com/adiutama/bb-plugin-terminal-hub; a local checkout sits beside the user's other repos). Take these from it:

- `package.json`: the `bb` block (`name`, `description`, `branding.icon`, `server`, `app`, `skills`), `engines.bb` and `engines.bbPluginSdk`, `@get-bb/plugin-sdk` pinned, and the scripts `build: bb plugin build` and `test:live`.
- `server.ts`, `app.tsx`, `styles.css`; `components.json` for shadcn with the `@bb` registry, and `components/ui/`.
- `tests/setup/jest-dom.ts`, and the React setup above.
- Name the repo `bb-plugin-<id>`. Findings record `bb --version` and the Plugin SDK version. `bb plugin types` repins the SDK to the installed bb.
