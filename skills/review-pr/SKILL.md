---
name: review-pr
description: Review a GitHub PR and save a persistent session file under ~/.agents/artifacts/<owner>/<repo>/<branch>/review-pr/. Use before merge; saves findings locally—does not post to GitHub.
disable-model-invocation: true
compatibility: Requires gh CLI authenticated to GitHub, and jq.
metadata:
  argument-hint: "<PR URL or PR Number>"
allowed-tools: Bash(gh:*) Read Write
---

Invoked as `/review-pr <PR URL or PR Number>`. If missing or invalid, ask once and stop.

## Step 1 — Initialize

Resolve `SKILL_DIR`, then run:

```bash
bash <SKILL_DIR>/scripts/start-session.sh <PR_URL_OR_NUMBER>
```

Outputs: `owner repo number title branch head_sha base body diff_file comments_file session_path pass`.

## Step 2 — Load context (parallel)

- Read `diff_file`, then `rm -f <diff_file>`.
- Read `<SKILL_DIR>/references/checklist.md`.
- Read `<SKILL_DIR>/references/format.md`.
- For pass `02+`, read previous session file (`<NN-1>.md` beside `session_path`).
- Read repo guidance: `AGENTS.md` or `CLAUDE.md`; fallback to `README.md`.
- Read docs under `docs/` relevant to touched areas.
- Read `comments_file`, then `rm -f <comments_file>`.

## Step 3 — Write the review

Follow `checklist.md` and `format.md`. Save output to `session_path`.

Deduplicate against `comments_file`: if same issue appears on same file within +/-5 lines, mark finding `Posted: ✅ dup`; keep it in file but exclude from counts and stance.

## Step 4 — Print summary

Print summary using `format.md`, then stop.
