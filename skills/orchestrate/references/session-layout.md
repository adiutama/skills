# Session layout

```text
<session>/
├── meta.json
├── vision.md
├── state.md
├── log.md
└── handoffs/
    └── <id>.md
```

## `meta.json`

Machine-readable identity and lifecycle: session id, status, timestamps, repository, branch, and a one-line vision.

## `vision.md`

```markdown
# Vision

## Intent

## Desired outcomes

## Constraints

## Non-goals
```

Stable and user-owned. Preserve their language. Revise when direction genuinely changes.

## `state.md`

```markdown
# State

## Current direction

## Confirmed decisions

## Active work

## Important findings

## Open questions

## Risks and blockers

## Next useful action
```

Parent-owned resume payload. Rewrite rather than append; keep under 150 lines. A fresh agent should be able to continue from `vision.md` plus `state.md`.

## `log.md`

Append meaningful events with an ISO timestamp, result, and evidence pointer. Avoid raw command output. Current truth must also appear in `state.md`.

## `handoffs/`

One bounded assignment per file. The parent writes the contract; a worker may append its report but cannot change session-owned files.
