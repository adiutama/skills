---
name: review-pr
description: Skeptical PR review—stance, findings, session on disk. Reads before merge; never posts to GitHub.
disable-model-invocation: true
compatibility: Requires gh CLI authenticated to GitHub, and jq.
metadata:
  argument-hint: "<PR URL or PR Number>"
allowed-tools: Bash(gh:*) Read Write
---

Invoked as `/review-pr <PR URL or PR Number>`. Missing or invalid → ask once; stop.

*Own the merge in your head before you sign it on the page.*

## Step 1 — Initialize

```bash
bash <SKILL_DIR>/scripts/start-session.sh <PR_URL_OR_NUMBER>
```

→ `owner repo number title branch head_sha base body diff_file comments_file session_path pass`.

## Step 2 — Load context (parallel)

Diff + comments (read, then `rm` temps). `<SKILL_DIR>/references/checklist.md`, `format.md`. Pass `02+`: prior **session** `<NN-1>.md`. Repo `AGENTS.md` / `CLAUDE.md` / `README.md`; touched `docs/`.

## Step 3 — Write

`checklist.md` + `format.md` → `session_path`. **Stance** earned—Approve / Approve with notes / Request Changes—counts exclude dupes.

Same issue, same file, ±5 lines vs `comments_file` → `Posted: ✅ dup`; keep in file; exclude from counts and **stance**.

## Step 4 — Summary

Print per `format.md`; stop.
