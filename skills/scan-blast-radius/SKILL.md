---
name: scan-blast-radius
description: Blast-radius before commit—rings, glue, parallel, verdict. One edit; trace what else breaks. Session under .agents/artifacts/.../scan-blast-radius/ (project-local; global fallback).
disable-model-invocation: true
compatibility: Requires a git repository.
metadata:
  argument-hint: "[fix|feature|rewire] [--quick] [target-branch-or-commit-sha]"
allowed-tools: Bash(git:* bash:*) Read Write rg Glob
---

Invoked as `/scan-blast-radius [fix|feature|rewire] [--quick] [target-branch-or-commit-sha]`.

*You touched one file; the **blast** may live three hops out. Walk the **rings**; earn the **verdict**—this skill never stages.*

## Step 1 — Intent

| Input | Effect |
|-------|--------|
| `fix` / `feature` / `rewire` | Lock kind (else infer) |
| `--quick` | Direct + **glue** only ([mode-switch.md](references/mode-switch.md)) |
| `[target]` | Git target; default `HEAD` |

## Step 2 — Scope

```bash
bash <SKILL_DIR>/scripts/resolve-scope.sh "[target]"
```

→ `COMMITTED_RANGE`, `INCLUDE_UNCOMMITTED`, `CHANGED_FILES`, `SESSION_PATH`, `PASS`, `PR_BASE`, `BRANCH`.

Empty changes → print nothing-to-check; stop. Parallel: `git diff <COMMITTED_RANGE>`, `git status --short`, optional `git diff HEAD`.

## Step 3 — Mode

[mode-switch.md](references/mode-switch.md) — record kind + intent line.

## Step 4 — Rings

[rings.md](references/rings.md) in order (`--quick` respected). Expand beyond diff; **glue** for feature/rewire; **parallel** for fix. Repo guidance: `AGENTS.md`, `CLAUDE.md`, `README.md`, touched `docs/`.

## Step 5 — Report

[format.md](references/format.md) + [assets/template.md](assets/template.md) → `SESSION_PATH`; IDs `I1, I2…`.

## Step 6 — Verdict

| Findings | **Verdict** |
|----------|-------------|
| No critical/warning | **safe to commit** |
| Warning+ | **address first** |
| User accepts risk | **known risk** (explicit confirm) |

Summary per `format.md`; stop—user decides commit.
