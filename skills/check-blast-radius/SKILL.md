---
name: check-blast-radius
description: Pre-commit blast-radius scan — fixes, features, glue, rewiring. Widens from the focused edit to coupling, missed wiring, and parallel breakages. Saves a session under ~/.agents/artifacts/<owner>/<repo>/<branch-slug>/check-blast-radius/.
disable-model-invocation: true
compatibility: Requires a git repository.
metadata:
  argument-hint: "[fix|feature|rewire] [--quick] [target-branch-or-commit-sha]"
allowed-tools: Bash(git:* bash:*) Read Write rg Glob
---

Invoked as `/check-blast-radius [fix|feature|rewire] [--quick] [target-branch-or-commit-sha]`.

Pre-commit **impact scan** — not a code-quality review. Run after focused work; commit only when verdict allows.

## Step 1 — Parse intent

| Flag / arg | Effect |
|------------|--------|
| `fix` / `feature` / `rewire` | Lock change kind (else infer) |
| `--quick` | Direct + Glue rings only ([mode-switch.md](references/mode-switch.md)) |
| `[target]` | Git target; default `HEAD` |

## Step 2 — Resolve scope

```bash
bash <SKILL_DIR>/scripts/resolve-scope.sh "[target]"
```

Parse: `COMMITTED_RANGE`, `INCLUDE_UNCOMMITTED`, `CHANGED_FILES`, `SESSION_PATH`, `PASS`, `PR_BASE`, `BRANCH`.

If `CHANGED_FILES` empty and no uncommitted diff:

```text
Nothing to check — no relevant changes in <COMMITTED_RANGE> and no uncommitted modifications.
```

Stop.

Run in parallel:

- `git diff <COMMITTED_RANGE>`
- `git status --short`
- If `INCLUDE_UNCOMMITTED=1`: `git diff HEAD`

## Step 3 — Mode switch

Apply [mode-switch.md](references/mode-switch.md). Record change kind + one-line intent in report meta.

## Step 4 — Walk rings

Follow [rings.md](references/rings.md) in order (respect `--quick`).

For each changed file/symbol:

- Expand beyond diff using search and call-site reads.
- Prioritize **glue** for feature/rewire kinds.
- Prioritize **parallel** for fix kind.

Load repo guidance when relevant: `AGENTS.md`, `CLAUDE.md`, `README.md`, `docs/`.

## Step 5 — Write report

Follow [format.md](references/format.md) and [assets/template.md](assets/template.md).

Save to `SESSION_PATH`. Assign impact IDs `I1, I2…`.

## Step 6 — Verdict and stop

| Findings | Verdict |
|----------|---------|
| No critical/warning | **safe to commit** |
| Warning+ | **address first** — list checks; do not commit |
| User accepts risk | **known risk** — only after explicit confirmation |

Print chat summary per `format.md`. Do not stage or commit — user decides next steps.

## Posture

| | This skill (blast radius) | Typical pre-push code review |
|--|---------------------------|------------------------------|
| When | Before commit | Before push |
| Question | What else breaks / wasn't wired? | Is the diff shippable? |
| Focus | Integration / impact | Skeptical review |
